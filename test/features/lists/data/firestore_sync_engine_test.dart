import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cart/core/database/app_database.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_items_repository.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_lists_repository.dart';
import 'package:pocket_cart/features/lists/data/sync/firestore_sync_engine.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_item.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_list.dart';
import 'package:pocket_cart/features/lists/domain/write_origin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase database;
  late DriftShoppingListsRepository listsRepository;
  late DriftShoppingItemsRepository itemsRepository;
  late FakeFirebaseFirestore firestore;
  late SharedPreferences preferences;
  late FirestoreSyncEngine syncEngine;

  const uid = 'user-1';
  const deviceId = 'device-test';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();

    database = AppDatabase.forTesting(NativeDatabase.memory());
    listsRepository = DriftShoppingListsRepository(
      database.shoppingListsDao,
      database.syncOutboxDao,
      deviceId,
    );
    itemsRepository = DriftShoppingItemsRepository(
      database.shoppingItemsDao,
      database.syncOutboxDao,
      deviceId,
    );

    firestore = FakeFirebaseFirestore();
    syncEngine = FirestoreSyncEngine(
      firestore: firestore,
      preferences: preferences,
      shoppingListsRepository: listsRepository,
      shoppingItemsRepository: itemsRepository,
      outbox: database.syncOutboxDao,
      deviceId: deviceId,
    );
  });

  tearDown(() async {
    await syncEngine.dispose();
    await database.close();
  });

  test('Test 1: local create list enqueues outbox and push writes Firestore', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: 'list-local-1',
        ownerId: uid,
        name: 'Local List',
        createdAt: now,
      ),
    );

    final pendingBeforeStart = await database.syncOutboxDao.getPending();
    expect(pendingBeforeStart, isNotEmpty);

    await syncEngine.start(uid);

    await _eventually(() async {
      final pending = await database.syncOutboxDao.getPending();
      return pending.isEmpty;
    });

    final remoteDoc = await firestore
        .collection('users')
        .doc(uid)
        .collection('lists')
        .doc('list-local-1')
        .get();

    expect(remoteDoc.exists, isTrue);
    expect(remoteDoc.data()?['name'], 'Local List');
    expect(remoteDoc.data()?['isDeleted'], false);
  });

  test('Test 2: remote list update applies locally without outbox echo', () async {
    await syncEngine.start(uid);

    final initialOutbox = await database.syncOutboxDao.getPending();
    expect(initialOutbox, isEmpty);

    final base = DateTime.now().toUtc();
    await firestore.collection('users').doc(uid).collection('lists').doc('list-remote-1').set(
      {
        'id': 'list-remote-1',
        'ownerId': uid,
        'name': 'Remote Original',
        'color': null,
        'icon': null,
        'sortMode': 'manual',
        'isArchived': false,
        'isDeleted': false,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base),
        'deletedAt': null,
        'revision': 1,
        'deviceId': 'other-device',
      },
    );

    await _eventually(() async {
      final local = await listsRepository.getById('list-remote-1');
      return local?.name == 'Remote Original';
    });

    await firestore.collection('users').doc(uid).collection('lists').doc('list-remote-1').set(
      {
        'name': 'Remote Updated',
        'updatedAt': Timestamp.fromDate(base.add(const Duration(minutes: 2))),
        'revision': 2,
        'deviceId': 'other-device',
      },
      SetOptions(merge: true),
    );

    await _eventually(() async {
      final local = await listsRepository.getById('list-remote-1');
      return local?.name == 'Remote Updated';
    });

    final pending = await database.syncOutboxDao.getPending();
    expect(pending, isEmpty);
  });

  test('Test 3: local add item pushes subcollection and remains in local', () async {
    final now = DateTime.now().toUtc();
    await listsRepository.create(
      ShoppingList(
        id: 'list-items',
        ownerId: uid,
        name: 'Items list',
        createdAt: now,
      ),
    );

    await syncEngine.start(uid);

    await itemsRepository.create(
      ShoppingItem(
        id: 'item-local-1',
        listId: 'list-items',
        ownerId: uid,
        name: 'Milk',
        createdAt: now,
      ),
    );

    await _eventually(() async {
      final remoteItem = await firestore
          .collection('users')
          .doc(uid)
          .collection('lists')
          .doc('list-items')
          .collection('items')
          .doc('item-local-1')
          .get();
      return remoteItem.exists;
    });

    final localItem = await itemsRepository.getById('item-local-1');
    expect(localItem, isNotNull);
    expect(localItem?.name, 'Milk');
  });

  test('Test 4: LWW conflict resolution local older/remote newer and local newer/remote older', () async {
    final base = DateTime.now().toUtc();

    await syncEngine.start(uid);

    await listsRepository.create(
      ShoppingList(
        id: 'list-lww-1',
        ownerId: uid,
        name: 'Local Older',
        createdAt: base,
      ),
      origin: WriteOrigin.remoteSync,
    );

    await firestore.collection('users').doc(uid).collection('lists').doc('list-lww-1').set(
      {
        'id': 'list-lww-1',
        'ownerId': uid,
        'name': 'Remote Newer',
        'color': null,
        'icon': null,
        'sortMode': 'manual',
        'isArchived': false,
        'isDeleted': false,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base.add(const Duration(minutes: 5))),
        'deletedAt': null,
        'revision': 2,
        'deviceId': 'remote-device',
      },
    );

    await _eventually(() async {
      final local = await listsRepository.getById('list-lww-1');
      return local?.name == 'Remote Newer';
    });

    final newerLocalTime = base.add(const Duration(minutes: 30));
    await listsRepository.update(
      ShoppingList(
        id: 'list-lww-2',
        ownerId: uid,
        name: 'Local Newer',
        createdAt: base,
        updatedAt: newerLocalTime,
      ),
      origin: WriteOrigin.remoteSync,
    );
    await listsRepository.update(
      (await listsRepository.getById('list-lww-2'))!.copyWith(name: 'Local Newer'),
    );

    await firestore.collection('users').doc(uid).collection('lists').doc('list-lww-2').set(
      {
        'id': 'list-lww-2',
        'ownerId': uid,
        'name': 'Remote Older',
        'color': null,
        'icon': null,
        'sortMode': 'manual',
        'isArchived': false,
        'isDeleted': false,
        'createdAt': Timestamp.fromDate(base),
        'updatedAt': Timestamp.fromDate(base.subtract(const Duration(days: 1))),
        'deletedAt': null,
        'revision': 1,
        'deviceId': 'remote-device',
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final stillLocal = await listsRepository.getById('list-lww-2');
    expect(stillLocal?.name, 'Local Newer');

    await _eventually(() async {
      final remote = await firestore
          .collection('users')
          .doc(uid)
          .collection('lists')
          .doc('list-lww-2')
          .get();
      return remote.data()?['name'] == 'Local Newer';
    });
  });

  test('Test 5: tombstone pushes and remote tombstone applies locally', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: 'list-delete',
        ownerId: uid,
        name: 'Delete me',
        createdAt: now,
      ),
    );

    await syncEngine.start(uid);

    await listsRepository.tombstoneById('list-delete');

    await _eventually(() async {
      final remote = await firestore
          .collection('users')
          .doc(uid)
          .collection('lists')
          .doc('list-delete')
          .get();
      return remote.data()?['isDeleted'] == true;
    });

    final remoteTime = now.add(const Duration(minutes: 20));
    await firestore.collection('users').doc(uid).collection('lists').doc('list-remote-tomb').set(
      {
        'id': 'list-remote-tomb',
        'ownerId': uid,
        'name': 'Remote Tomb',
        'color': null,
        'icon': null,
        'sortMode': 'manual',
        'isArchived': false,
        'isDeleted': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(remoteTime),
        'deletedAt': Timestamp.fromDate(remoteTime),
        'revision': 2,
        'deviceId': 'remote-device',
      },
    );

    await _eventually(() async {
      final local = await listsRepository.getById('list-remote-tomb');
      return local?.isDeleted == true;
    });
  });
}

Future<void> _eventually(Future<bool> Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 6));
  while (DateTime.now().isBefore(timeoutAt)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Condition not met before timeout.');
}
