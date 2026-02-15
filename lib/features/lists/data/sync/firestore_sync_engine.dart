import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/daos/sync_outbox_store.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/models/shopping_list.dart';
import '../../domain/repositories/shopping_items_repository.dart';
import '../../domain/repositories/shopping_lists_repository.dart';
import '../../domain/write_origin.dart';
import 'outbox_operation.dart';

class FirestoreSyncEngine {
  FirestoreSyncEngine({
    required FirebaseFirestore firestore,
    required SharedPreferences preferences,
    required ShoppingListsRepository shoppingListsRepository,
    required ShoppingItemsRepository shoppingItemsRepository,
    required SyncOutboxStore outbox,
    required String deviceId,
  })  : _firestore = firestore,
        _preferences = preferences,
        _shoppingListsRepository = shoppingListsRepository,
        _shoppingItemsRepository = shoppingItemsRepository,
        _outbox = outbox,
        _deviceId = deviceId;

  final FirebaseFirestore _firestore;
  final SharedPreferences _preferences;
  final ShoppingListsRepository _shoppingListsRepository;
  final ShoppingItemsRepository _shoppingItemsRepository;
  final SyncOutboxStore _outbox;
  final String _deviceId;

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listsSubscription;
  StreamSubscription<List<SyncOutboxEntry>>? _outboxSubscription;
  Timer? _pushTimer;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _itemSubscriptions = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

  bool _started = false;
  bool _isDrainingOutbox = false;
  Completer<void>? _initialRemoteLoad;

  CollectionReference<Map<String, dynamic>> get _listsCollection {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Sync engine is not started.');
    }
    return _firestore.collection('users').doc(uid).collection('lists');
  }

  Future<void> start(String uid) async {
    if (_started && _uid == uid) {
      return;
    }

    await stop();
    _started = true;
    _uid = uid;
    _initialRemoteLoad = Completer<void>();

    // Bootstrap strategy: pull remote first, then push local outbox.
    // This avoids creating duplicate entities when another device already has newer data.
    _listsSubscription = _listsCollection.snapshots().listen(
      (snapshot) => unawaited(_onListsSnapshot(snapshot)),
      onError: (Object error, StackTrace stackTrace) {
        if (!(_initialRemoteLoad?.isCompleted ?? true)) {
          _initialRemoteLoad?.complete();
        }
      },
    );

    await _initialRemoteLoad?.future;

    _outboxSubscription = _outbox.watchPending(limit: 200).listen(
      (_) => unawaited(_drainOutbox()),
    );

    _pushTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_drainOutbox()),
    );

    await _drainOutbox();
  }

  Future<void> stop() async {
    _started = false;
    _uid = null;
    await _listsSubscription?.cancel();
    _listsSubscription = null;

    for (final subscription in _itemSubscriptions.values) {
      await subscription.cancel();
    }
    _itemSubscriptions.clear();

    await _outboxSubscription?.cancel();
    _outboxSubscription = null;

    _pushTimer?.cancel();
    _pushTimer = null;
    _initialRemoteLoad = null;
  }

  Future<void> dispose() => stop();

  Future<void> _onListsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) {
        continue;
      }

      final list = _listFromRemote(change.doc.id, data);
      await _applyRemoteList(list);
      await _saveRemoteCheckpoint(_updatedMillis(list.updatedAt, list.createdAt));

      if (list.isDeleted || list.isArchived) {
        await _cancelItemSubscription(list.id);
      } else {
        _ensureItemSubscription(list.id);
      }
    }

    if (!(_initialRemoteLoad?.isCompleted ?? true)) {
      _initialRemoteLoad?.complete();
    }
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
          (snapshot) => unawaited(_onItemsSnapshot(listId, snapshot)),
        );

    _itemSubscriptions[listId] = subscription;
  }

  Future<void> _cancelItemSubscription(String listId) async {
    final subscription = _itemSubscriptions.remove(listId);
    await subscription?.cancel();
  }

  Future<void> _onItemsSnapshot(
    String listId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) {
        continue;
      }

      final item = _itemFromRemote(change.doc.id, listId, data);
      await _applyRemoteItem(item);
      await _saveRemoteCheckpoint(_updatedMillis(item.updatedAt, item.createdAt));
    }
  }

  Future<void> _applyRemoteList(ShoppingList remote) async {
    final local = await _shoppingListsRepository.getById(remote.id);
    final localMillis = _updatedMillis(local?.updatedAt, local?.createdAt);
    final remoteMillis = _updatedMillis(remote.updatedAt, remote.createdAt);

    if (remoteMillis < localMillis) {
      return;
    }

    if (local == null) {
      await _shoppingListsRepository.create(remote, origin: WriteOrigin.remoteSync);
    } else {
      await _shoppingListsRepository.update(remote, origin: WriteOrigin.remoteSync);
    }
  }

  Future<void> _applyRemoteItem(ShoppingItem remote) async {
    final local = await _shoppingItemsRepository.getById(remote.id);
    final localMillis = _updatedMillis(local?.updatedAt, local?.createdAt);
    final remoteMillis = _updatedMillis(remote.updatedAt, remote.createdAt);

    if (remoteMillis < localMillis) {
      return;
    }

    if (local == null) {
      await _shoppingItemsRepository.create(remote, origin: WriteOrigin.remoteSync);
    } else {
      await _shoppingItemsRepository.update(remote, origin: WriteOrigin.remoteSync);
    }
  }

  Future<void> _drainOutbox() async {
    if (!_started || _isDrainingOutbox) {
      return;
    }

    _isDrainingOutbox = true;
    try {
      while (true) {
        final pending = await _outbox.getPending(limit: 200);
        if (pending.isEmpty) {
          return;
        }

        var processedAny = false;
        final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

        for (final row in pending) {
          if (!_isRetryReady(row, nowMillis)) {
            continue;
          }
          processedAny = true;

          try {
            await _pushEntry(row);
            await _outbox.markDone(row.id);
          } catch (error) {
            await _outbox.markFailed(row.id, error.toString());
          }
        }

        if (!processedAny) {
          return;
        }
      }
    } finally {
      _isDrainingOutbox = false;
    }
  }

  bool _isRetryReady(SyncOutboxEntry row, int nowMillis) {
    final attempts = row.attemptCount;
    if (attempts <= 0) {
      return true;
    }

    final waitMillis = _backoffMillis(attempts);
    return nowMillis - row.updatedAtMillis >= waitMillis;
  }

  int _backoffMillis(int attempts) {
    final cappedAttempts = attempts.clamp(0, 6);
    return 1000 * (1 << cappedAttempts);
  }

  Future<void> _pushEntry(SyncOutboxEntry row) async {
    final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final entityType = row.entityType;

    if (entityType == OutboxEntityType.list.name) {
      await _listsCollection.doc(row.entityId).set(
            _toFirestorePayload(payload),
            SetOptions(merge: true),
          );
      return;
    }

    if (entityType == OutboxEntityType.item.name) {
      final listId = row.listId ?? (payload['listId'] as String?);
      if (listId == null || listId.isEmpty) {
        throw StateError('Outbox item operation missing listId.');
      }

      await _listsCollection
          .doc(listId)
          .collection('items')
          .doc(row.entityId)
          .set(
            _toFirestorePayload(payload),
            SetOptions(merge: true),
          );
    }
  }

  Map<String, dynamic> _toFirestorePayload(Map<String, dynamic> payload) {
    final map = <String, dynamic>{...payload};
    map.putIfAbsent('deviceId', () => _deviceId);
    for (final key in <String>[
      'createdAt',
      'updatedAt',
      'deletedAt',
      'checkedAt',
    ]) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      if (value is int) {
        map[key] = Timestamp.fromMillisecondsSinceEpoch(value);
      }
    }
    return map;
  }

  ShoppingList _listFromRemote(String listId, Map<String, dynamic> data) {
    final uid = _uid ?? '';
    return ShoppingList(
      id: listId,
      ownerId: (data['ownerId'] as String?) ?? uid,
      name: (data['name'] as String?) ?? '',
      color: data['color'] as int?,
      icon: data['icon'] as String?,
      sortMode: (data['sortMode'] as String?) ?? 'manual',
      isArchived: (data['isArchived'] as bool?) ?? false,
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      createdAt: _readTimestamp(data['createdAt']) ?? _epoch(),
      updatedAt: _readTimestamp(data['updatedAt']) ?? _epoch(),
      deletedAt: _readTimestamp(data['deletedAt']),
      sortOrder: (data['sortOrder'] as int?) ?? 0,
      revision: (data['revision'] as int?) ?? 0,
      deviceId: data['deviceId'] as String?,
    );
  }

  ShoppingItem _itemFromRemote(
    String itemId,
    String listId,
    Map<String, dynamic> data,
  ) {
    final uid = _uid ?? '';
    return ShoppingItem(
      id: itemId,
      listId: (data['listId'] as String?) ?? listId,
      ownerId: (data['ownerId'] as String?) ?? uid,
      name: (data['name'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
      category: data['category'] as String?,
      note: data['note'] as String?,
      isChecked: (data['isChecked'] as bool?) ?? false,
      checkedAt: _readTimestamp(data['checkedAt']),
      sortOrder: (data['sortOrder'] as int?) ?? 0,
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      createdAt: _readTimestamp(data['createdAt']) ?? _epoch(),
      updatedAt: _readTimestamp(data['updatedAt']) ?? _epoch(),
      deletedAt: _readTimestamp(data['deletedAt']),
      revision: (data['revision'] as int?) ?? 0,
      deviceId: data['deviceId'] as String?,
    );
  }

  DateTime? _readTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    return null;
  }

  DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  int _updatedMillis(DateTime? updatedAt, DateTime? createdAt) {
    return (updatedAt ?? createdAt ?? _epoch()).millisecondsSinceEpoch;
  }

  Future<void> _saveRemoteCheckpoint(int updatedAtMillis) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }

    final key = 'sync.last_remote_updated_at.$uid';
    final current = _preferences.getInt(key) ?? 0;
    if (updatedAtMillis > current) {
      await _preferences.setInt(key, updatedAtMillis);
    }
  }
}
