import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/shopping_items_dao.dart';
import '../../../../core/database/daos/shopping_lists_dao.dart';
import '../../../../core/database/daos/sync_outbox_dao.dart';
import '../../../../core/database/database_provider.dart';

part 'firestore_sync_engine.g.dart';

class FirestoreSyncEngine {
  FirestoreSyncEngine({
    required FirebaseFirestore firestore,
    required String uid,
    required ShoppingListsDao listsDao,
    required ShoppingItemsDao itemsDao,
    required SyncOutboxDao outboxDao,
  })  : _firestore = firestore,
        _uid = uid,
        _listsDao = listsDao,
        _itemsDao = itemsDao,
        _outboxDao = outboxDao;

  final FirebaseFirestore _firestore;
  final String _uid;
  final ShoppingListsDao _listsDao;
  final ShoppingItemsDao _itemsDao;
  final SyncOutboxDao _outboxDao;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _itemSubscriptions = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

  bool _started = false;
  bool _pushInProgress = false;

  CollectionReference<Map<String, dynamic>> get _listsCollection =>
      _firestore.collection('users').doc(_uid).collection('lists');

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    _listsSubscription = _listsCollection.snapshots().listen(
      (snapshot) => unawaited(_handleListsSnapshot(snapshot)),
    );

    await pushPendingChanges();
  }

  Future<void> stop() async {
    _started = false;
    await _listsSubscription?.cancel();
    _listsSubscription = null;

    for (final subscription in _itemSubscriptions.values) {
      await subscription.cancel();
    }
    _itemSubscriptions.clear();
  }

  Future<void> dispose() => stop();

  Future<void> pushPendingChanges() async {
    if (_pushInProgress) {
      return;
    }

    _pushInProgress = true;
    try {
      while (true) {
        final pending = await _outboxDao.getPendingChanges(limit: 200);
        if (pending.isEmpty) {
          break;
        }

        for (final change in pending) {
          try {
            await _pushSingleChange(change);
            await _outboxDao.deleteById(change.id);
          } catch (_) {
            return;
          }
        }
      }
    } finally {
      _pushInProgress = false;
    }
  }

  Future<void> _pushSingleChange(SyncOutboxTableData change) async {
    final payload = jsonDecode(change.payload) as Map<String, dynamic>;

    if (change.entityType == 'list') {
      final docRef = _listsCollection.doc(change.entityId);
      await docRef.set(_toFirestoreMap(payload), SetOptions(merge: true));
      return;
    }

    if (change.entityType == 'item') {
      final listId = (payload['listId'] as String?) ?? change.listId;
      if (listId == null || listId.isEmpty) {
        return;
      }

      final docRef = _listsCollection
          .doc(listId)
          .collection('items')
          .doc(change.entityId);
      await docRef.set(_toFirestoreMap(payload), SetOptions(merge: true));
    }
  }

  Future<void> _handleListsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) {
        continue;
      }

      final listId = change.doc.id;
      await _mergeRemoteList(listId: listId, data: data);

      final isDeleted = (data['isDeleted'] as bool?) ?? false;
      if (isDeleted) {
        await _cancelItemSubscription(listId);
      } else {
        _ensureItemSubscription(listId);
      }
    }

    await pushPendingChanges();
  }

  void _ensureItemSubscription(String listId) {
    if (_itemSubscriptions.containsKey(listId)) {
      return;
    }

    final subscription = _listsCollection
        .doc(listId)
        .collection('items')
        .snapshots()
        .listen(
          (snapshot) => unawaited(_handleItemsSnapshot(listId, snapshot)),
        );

    _itemSubscriptions[listId] = subscription;
  }

  Future<void> _cancelItemSubscription(String listId) async {
    final subscription = _itemSubscriptions.remove(listId);
    await subscription?.cancel();
  }

  Future<void> _handleItemsSnapshot(
    String listId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) {
        continue;
      }

      await _mergeRemoteItem(listId: listId, itemId: change.doc.id, data: data);
    }

    await pushPendingChanges();
  }

  Future<void> _mergeRemoteList({
    required String listId,
    required Map<String, dynamic> data,
  }) async {
    final remoteUpdatedAt = _readDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final local = await _listsDao.getListById(listId);
    final localUpdatedAt = _effectiveLocalUpdatedAt(local?.updatedAt, local?.createdAt);

    if (localUpdatedAt != null && remoteUpdatedAt.isBefore(localUpdatedAt)) {
      return;
    }

    await _listsDao.upsertList(
      ShoppingListsTableCompanion.insert(
        id: listId,
        ownerId: (data['ownerId'] as String?) ?? _uid,
        name: (data['name'] as String?) ?? '',
        isArchived: Value((data['isArchived'] as bool?) ?? false),
        isDeleted: Value((data['isDeleted'] as bool?) ?? false),
        deletedAt: Value(_readDate(data['deletedAt'])),
        sortOrder: Value((data['sortOrder'] as int?) ?? 0),
        createdAt: _readDate(data['createdAt']) ?? remoteUpdatedAt,
        updatedAt: Value(remoteUpdatedAt),
      ),
    );
  }

  Future<void> _mergeRemoteItem({
    required String listId,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    final remoteUpdatedAt = _readDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final local = await _itemsDao.getItemById(itemId);
    final localUpdatedAt = _effectiveLocalUpdatedAt(local?.updatedAt, local?.createdAt);

    if (localUpdatedAt != null && remoteUpdatedAt.isBefore(localUpdatedAt)) {
      return;
    }

    await _itemsDao.upsertItem(
      ShoppingItemsTableCompanion.insert(
        id: itemId,
        listId: (data['listId'] as String?) ?? listId,
        name: (data['name'] as String?) ?? '',
        quantity: Value((data['quantity'] as int?) ?? 1),
        isChecked: Value((data['isChecked'] as bool?) ?? false),
        isDeleted: Value((data['isDeleted'] as bool?) ?? false),
        deletedAt: Value(_readDate(data['deletedAt'])),
        sortOrder: Value((data['sortOrder'] as int?) ?? 0),
        createdAt: _readDate(data['createdAt']) ?? remoteUpdatedAt,
        updatedAt: Value(remoteUpdatedAt),
      ),
    );
  }

  DateTime? _effectiveLocalUpdatedAt(DateTime? updatedAt, DateTime? createdAt) {
    return updatedAt ?? createdAt;
  }

  Map<String, dynamic> _toFirestoreMap(Map<String, dynamic> payload) {
    final map = <String, dynamic>{
      ...payload,
    };

    for (final key in <String>['createdAt', 'updatedAt', 'deletedAt']) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      if (value is int) {
        map[key] = Timestamp.fromMillisecondsSinceEpoch(value);
      } else if (value is DateTime) {
        map[key] = Timestamp.fromDate(value.toUtc());
      }
    }

    return map;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
FirebaseFirestore firebaseFirestore(Ref ref) {
  return FirebaseFirestore.instance;
}

@riverpod
FirestoreSyncEngine firestoreSyncEngine(Ref ref, String uid) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final listsDao = ref.watch(shoppingListsDaoProvider);
  final itemsDao = ref.watch(shoppingItemsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);

  final engine = FirestoreSyncEngine(
    firestore: firestore,
    uid: uid,
    listsDao: listsDao,
    itemsDao: itemsDao,
    outboxDao: outboxDao,
  );

  ref.onDispose(engine.dispose);
  return engine;
}
