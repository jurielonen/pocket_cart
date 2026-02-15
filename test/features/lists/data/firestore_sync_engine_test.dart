import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cart/core/database/app_database.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_items_repository.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_lists_repository.dart';
import 'package:pocket_cart/features/lists/data/sync/firestore_sync_engine.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_item.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_list.dart';

void main() {
  late AppDatabase database;
  late DriftShoppingListsRepository listsRepository;
  late DriftShoppingItemsRepository itemsRepository;
  late FakeFirebaseFirestore firestore;
  late FirestoreSyncEngine syncEngine;

  const uid = 'user-1';

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    listsRepository =
        DriftShoppingListsRepository(database.shoppingListsDao, database.syncOutboxDao);
    itemsRepository =
        DriftShoppingItemsRepository(database.shoppingItemsDao, database.syncOutboxDao);
    firestore = FakeFirebaseFirestore();

    syncEngine = FirestoreSyncEngine(
      firestore: firestore,
      uid: uid,
      listsDao: database.shoppingListsDao,
      itemsDao: database.shoppingItemsDao,
      outboxDao: database.syncOutboxDao,
    );
  });

  tearDown(() async {
    await syncEngine.dispose();
    await database.close();
  });

  test('pushes local outbox records to Firestore with tombstones', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: 'list-a',
        ownerId: uid,
        name: 'Primary',
        createdAt: now,
      ),
    );

    await itemsRepository.create(
      ShoppingItem(
        id: 'item-a',
        listId: 'list-a',
        name: 'Milk',
        createdAt: now,
      ),
    );

    await syncEngine.pushPendingChanges();

    final listDoc =
        await firestore.collection('users').doc(uid).collection('lists').doc('list-a').get();
    final itemDoc = await firestore
        .collection('users')
        .doc(uid)
        .collection('lists')
        .doc('list-a')
        .collection('items')
        .doc('item-a')
        .get();

    expect(listDoc.exists, isTrue);
    expect(itemDoc.exists, isTrue);
    expect(listDoc.data()?['isDeleted'], false);
    expect(itemDoc.data()?['isDeleted'], false);

    await itemsRepository.deleteById('item-a');
    await syncEngine.pushPendingChanges();

    final deletedItemDoc = await firestore
        .collection('users')
        .doc(uid)
        .collection('lists')
        .doc('list-a')
        .collection('items')
        .doc('item-a')
        .get();

    expect(deletedItemDoc.data()?['isDeleted'], true);
    expect(deletedItemDoc.data()?['deletedAt'], isA<Timestamp>());
  });

  test('pulls snapshots and applies last-write-wins with updatedAt', () async {
    final base = DateTime.now().toUtc();

    await database.shoppingListsDao.updateList(
      ShoppingListsTableCompanion.insert(
        id: 'list-lww',
        ownerId: uid,
        name: 'Local Newer',
        createdAt: base,
        updatedAt: Value(base.add(const Duration(minutes: 10))),
      ),
    );

    await syncEngine.start();

    await firestore.collection('users').doc(uid).collection('lists').doc('list-lww').set(
      {
        'id': 'list-lww',
        'ownerId': uid,
        'name': 'Remote Older',
        'isArchived': false,
        'isDeleted': false,
        'sortOrder': 0,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base.add(const Duration(minutes: 1))),
      },
    );
    await _flushAsyncEvents();

    final afterOlderRemote = await database.shoppingListsDao.getListById('list-lww');
    expect(afterOlderRemote?.name, 'Local Newer');

    await firestore.collection('users').doc(uid).collection('lists').doc('list-lww').set(
      {
        'id': 'list-lww',
        'ownerId': uid,
        'name': 'Remote Newer',
        'isArchived': false,
        'isDeleted': false,
        'sortOrder': 0,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base.add(const Duration(minutes: 30))),
      },
    );
    await _flushAsyncEvents();

    final afterNewerRemote = await database.shoppingListsDao.getListById('list-lww');
    expect(afterNewerRemote?.name, 'Remote Newer');

    await firestore.collection('users').doc(uid).collection('lists').doc('list-lww').set(
      {
        'id': 'list-lww',
        'ownerId': uid,
        'name': 'Remote Newer',
        'isArchived': false,
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(base.add(const Duration(minutes: 31))),
        'sortOrder': 0,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base.add(const Duration(minutes: 31))),
      },
      SetOptions(merge: true),
    );
    await _flushAsyncEvents();

    final visibleLists = await listsRepository.getListsForOwner(uid);
    expect(visibleLists.where((list) => list.id == 'list-lww'), isEmpty);
  });
}

Future<void> _flushAsyncEvents() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
