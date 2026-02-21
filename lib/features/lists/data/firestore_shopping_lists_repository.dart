import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/models/shopping_list.dart';
import '../domain/repositories/shopping_lists_repository.dart';
import '../domain/write_origin.dart';
import 'firebase_firestore_provider.dart';
import 'firestore_keys.dart';

part 'firestore_shopping_lists_repository.g.dart';

class FirestoreShoppingListsRepository implements ShoppingListsRepository {
  FirestoreShoppingListsRepository(this._firestore, this._currentUserId);

  final FirebaseFirestore _firestore;
  final String Function() _currentUserId;

  CollectionReference<Map<String, dynamic>> _listsCollection(String ownerId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.lists);
  }

  @override
  Future<List<ShoppingList>> getListsForOwner(String ownerId) async {
    final snapshot = await _listsCollection(
      ownerId,
    ).where(FirestoreFields.isDeleted, isEqualTo: false).get();
    return _sortLists(snapshot.docs.map(_fromDocument).toList(growable: false));
  }

  @override
  Stream<List<ShoppingList>> watchListsForOwner(String ownerId) {
    return _listsCollection(ownerId)
        .where(FirestoreFields.isDeleted, isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => _sortLists(
            snapshot.docs.map(_fromDocument).toList(growable: false),
          ),
        );
  }

  @override
  Future<ShoppingList?> getById(String id) async {
    final ownerId = _currentUserId();
    final doc = await _listsCollection(ownerId).doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return _fromDocument(doc);
  }

  @override
  Future<void> create(
    ShoppingList list, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final now = _now();
    final writeModel = list.copyWith(
      ownerId: list.ownerId,
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
      revision: list.revision + 1,
    );

    await _listsCollection(writeModel.ownerId)
        .doc(writeModel.id)
        .set(_toFirestoreMap(writeModel), SetOptions(merge: true));
  }

  @override
  Future<void> update(
    ShoppingList list, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      revision: list.revision + 1,
    );

    await _listsCollection(writeModel.ownerId)
        .doc(writeModel.id)
        .set(_toFirestoreMap(writeModel), SetOptions(merge: true));
  }

  @override
  Future<void> tombstoneById(
    String id, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final existing = await getById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _listsCollection(existing.ownerId).doc(id).set({
      FirestoreFields.isDeleted: true,
      FirestoreFields.deletedAt: Timestamp.fromDate(now),
      FirestoreFields.updatedAt: Timestamp.fromDate(now),
      FirestoreFields.revision: existing.revision + 1,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> restoreById(
    String id, {
    WriteOrigin origin = WriteOrigin.localUser,
  }) async {
    final existing = await getById(id);
    if (existing == null || !existing.isDeleted) {
      return;
    }

    final now = _now();
    await _listsCollection(existing.ownerId).doc(id).set({
      FirestoreFields.isDeleted: false,
      FirestoreFields.deletedAt: null,
      FirestoreFields.updatedAt: Timestamp.fromDate(now),
      FirestoreFields.revision: existing.revision + 1,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> reorder({
    required String ownerId,
    required List<String> orderedIds,
  }) async {
    final now = _now();
    final batch = _firestore.batch();

    for (var index = 0; index < orderedIds.length; index++) {
      final id = orderedIds[index];
      final ref = _listsCollection(ownerId).doc(id);
      batch.set(ref, {
        FirestoreFields.sortOrder: (index + 1) * 1000,
        FirestoreFields.updatedAt: Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  List<ShoppingList> _sortLists(List<ShoppingList> lists) {
    lists.sort((a, b) {
      final aUpdated = (a.updatedAt ?? a.createdAt).millisecondsSinceEpoch;
      final bUpdated = (b.updatedAt ?? b.createdAt).millisecondsSinceEpoch;
      final byUpdated = bUpdated.compareTo(aUpdated);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return b.createdAt.millisecondsSinceEpoch.compareTo(
        a.createdAt.millisecondsSinceEpoch,
      );
    });
    return lists;
  }

  ShoppingList _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ownerId = doc.reference.parent.parent?.id ?? '';
    return ShoppingList.fromJson({
      ...data,
      FirestoreFields.id: doc.id,
      FirestoreFields.ownerId: data[FirestoreFields.ownerId] ?? ownerId,
    });
  }

  Map<String, dynamic> _toFirestoreMap(ShoppingList list) {
    return list.copyWith(updatedAt: list.updatedAt ?? list.createdAt).toJson();
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingListsRepository shoppingListsRepository(Ref ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FirestoreShoppingListsRepository(
    firestore,
    () => FirebaseAuth.instance.currentUser?.uid ?? 'local-dev-user',
  );
}
