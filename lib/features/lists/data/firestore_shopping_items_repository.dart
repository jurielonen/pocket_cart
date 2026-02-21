import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/shopping_item.dart';
import '../domain/repositories/shopping_items_repository.dart';
import '../domain/write_origin.dart';
import 'firebase_firestore_provider.dart';
import 'firestore_keys.dart';

part 'firestore_shopping_items_repository.g.dart';

class FirestoreShoppingItemsRepository implements ShoppingItemsRepository {
  FirestoreShoppingItemsRepository(this._firestore, this._currentUserId);

  final FirebaseFirestore _firestore;
  final String Function() _currentUserId;

  CollectionReference<Map<String, dynamic>> _itemsCollection(
    String ownerId,
    String listId,
  ) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.lists)
        .doc(listId)
        .collection(FirestoreCollections.items);
  }

  @override
  Future<List<ShoppingItem>> getItemsForList(String listId) async {
    final ownerId = _currentUserId();
    final snapshot = await _itemsCollection(
      ownerId,
      listId,
    ).where(FirestoreFields.isDeleted, isEqualTo: false).get();
    return _sortItems(
      snapshot.docs
          .map((doc) => _fromDocument(doc, listId))
          .toList(growable: false),
    );
  }

  @override
  Stream<List<ShoppingItem>> watchItemsForList(String listId) {
    final ownerId = _currentUserId();
    return _itemsCollection(ownerId, listId)
        .where(FirestoreFields.isDeleted, isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => _sortItems(
            snapshot.docs
                .map((doc) => _fromDocument(doc, listId))
                .toList(growable: false),
          ),
        );
  }

  @override
  Stream<int> watchActiveItemCount(String listId) {
    final ownerId = _currentUserId();
    return _itemsCollection(ownerId, listId)
        .where(FirestoreFields.isDeleted, isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<ShoppingItem?> getById({
    required String listId,
    required String id,
  }) async {
    final ownerId = _currentUserId();
    final doc = await _itemsCollection(ownerId, listId).doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return _fromDocument(doc, listId);
  }

  @override
  Future<void> create(
    ShoppingItem item, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final ownerId = item.ownerId.isNotEmpty ? item.ownerId : _currentUserId();
    final now = _now();
    final nextSortOrder = await _getNextSortOrder(ownerId, item.listId);
    final writeModel = item.copyWith(
      ownerId: ownerId,
      sortOrder: nextSortOrder,
      isDeleted: false,
      deletedAt: null,
      checkedAt: item.isChecked ? (item.checkedAt ?? now) : null,
      updatedAt: now,
      revision: item.revision + 1,
    );

    await _itemsCollection(
      ownerId,
      item.listId,
    ).doc(item.id).set(_toFirestoreMap(writeModel), SetOptions(merge: true));
  }

  @override
  Future<void> update(
    ShoppingItem item, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final ownerId = item.ownerId.isNotEmpty ? item.ownerId : _currentUserId();
    final now = _now();
    final writeModel = item.copyWith(
      ownerId: ownerId,
      updatedAt: now,
      checkedAt: item.isChecked ? (item.checkedAt ?? now) : null,
      revision: item.revision + 1,
    );

    await _itemsCollection(ownerId, writeModel.listId)
        .doc(writeModel.id)
        .set(_toFirestoreMap(writeModel), SetOptions(merge: true));
  }

  @override
  Future<void> setChecked({
    required String listId,
    required String id,
    required bool isChecked,
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final existing = await getById(listId: listId, id: id);
    if (existing == null) {
      return;
    }

    final now = _now();
    await _itemsCollection(existing.ownerId, listId).doc(id).set({
      FirestoreFields.isChecked: isChecked,
      FirestoreFields.checkedAt: isChecked ? Timestamp.fromDate(now) : null,
      FirestoreFields.updatedAt: Timestamp.fromDate(now),
      FirestoreFields.revision: existing.revision + 1,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> tombstoneById(
    String id, {
    required String listId,
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final existing = await getById(listId: listId, id: id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _itemsCollection(existing.ownerId, existing.listId).doc(id).set({
      FirestoreFields.isDeleted: true,
      FirestoreFields.deletedAt: Timestamp.fromDate(now),
      FirestoreFields.updatedAt: Timestamp.fromDate(now),
      FirestoreFields.revision: existing.revision + 1,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> restoreById(
    String id, {
    required String listId,
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final existing = await getById(listId: listId, id: id);
    if (existing == null || !existing.isDeleted) {
      return;
    }

    final now = _now();
    await _itemsCollection(existing.ownerId, existing.listId).doc(id).set({
      FirestoreFields.isDeleted: false,
      FirestoreFields.deletedAt: null,
      FirestoreFields.updatedAt: Timestamp.fromDate(now),
      FirestoreFields.revision: existing.revision + 1,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> reorder({
    required String listId,
    required List<String> orderedUncheckedIds,
  }) async {
    final ownerId = _currentUserId();
    final now = _now();
    final batch = _firestore.batch();

    for (var index = 0; index < orderedUncheckedIds.length; index++) {
      final id = orderedUncheckedIds[index];
      final ref = _itemsCollection(ownerId, listId).doc(id);
      batch.set(ref, {
        FirestoreFields.sortOrder: (index + 1) * 1000,
        FirestoreFields.updatedAt: Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<int> _getNextSortOrder(String ownerId, String listId) async {
    final snapshot = await _itemsCollection(
      ownerId,
      listId,
    ).where(FirestoreFields.isDeleted, isEqualTo: false).get();
    var maxSortOrder = 0;
    for (final doc in snapshot.docs) {
      final value = doc.data()[FirestoreFields.sortOrder];
      if (value is int && value > maxSortOrder) {
        maxSortOrder = value;
      }
    }
    return maxSortOrder + 1000;
  }

  List<ShoppingItem> _sortItems(List<ShoppingItem> items) {
    items.sort((a, b) {
      final byChecked = (a.isChecked ? 1 : 0).compareTo(b.isChecked ? 1 : 0);
      if (byChecked != 0) {
        return byChecked;
      }

      final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
      if (bySortOrder != 0) {
        return bySortOrder;
      }

      final aCheckedAt = (a.checkedAt ?? _epoch()).millisecondsSinceEpoch;
      final bCheckedAt = (b.checkedAt ?? _epoch()).millisecondsSinceEpoch;
      final byCheckedAt = bCheckedAt.compareTo(aCheckedAt);
      if (byCheckedAt != 0) {
        return byCheckedAt;
      }

      final aUpdated = (a.updatedAt ?? a.createdAt).millisecondsSinceEpoch;
      final bUpdated = (b.updatedAt ?? b.createdAt).millisecondsSinceEpoch;
      return bUpdated.compareTo(aUpdated);
    });

    return items;
  }

  ShoppingItem _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String listId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final segments = doc.reference.path.split('/');
    final usersIndex = segments.indexOf(FirestoreCollections.users);
    final ownerId = usersIndex >= 0 && usersIndex + 1 < segments.length
        ? segments[usersIndex + 1]
        : '';

    return ShoppingItem.fromJson({
      ...data,
      FirestoreFields.id: doc.id,
      FirestoreFields.listId: data[FirestoreFields.listId] ?? listId,
      FirestoreFields.ownerId: data[FirestoreFields.ownerId] ?? ownerId,
    });
  }

  Map<String, dynamic> _toFirestoreMap(ShoppingItem item) {
    return item.copyWith(updatedAt: item.updatedAt ?? item.createdAt).toJson();
  }

  DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingItemsRepository shoppingItemsRepository(Ref ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FirestoreShoppingItemsRepository(
    firestore,
    () => FirebaseAuth.instance.currentUser?.uid ?? 'local-dev-user',
  );
}
