import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cart/core/database/app_database.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_items_repository.dart';
import 'package:pocket_cart/features/lists/data/drift_shopping_lists_repository.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_item.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_list.dart';

void main() {
  late AppDatabase database;
  late DriftShoppingListsRepository listsRepository;
  late DriftShoppingItemsRepository itemsRepository;

  const ownerId = 'owner-1';
  const listId = 'list-1';

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    listsRepository = DriftShoppingListsRepository(
      database.shoppingListsDao,
      database.syncOutboxDao,
      'test-device',
    );
    itemsRepository = DriftShoppingItemsRepository(
      database.shoppingItemsDao,
      database.syncOutboxDao,
      'test-device',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('create list appears in query', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: listId,
        ownerId: ownerId,
        name: 'Weekly',
        createdAt: now,
      ),
    );

    final lists = await listsRepository.getListsForOwner(ownerId);
    expect(lists, hasLength(1));
    expect(lists.first.id, listId);
    expect(lists.first.name, 'Weekly');
  });

  test('rename updates updatedAt', () async {
    final fixedPast = DateTime.utc(2024, 1, 1, 10, 0, 0);
    await database.shoppingListsDao.upsertList(
      ShoppingListsTableCompanion.insert(
        id: listId,
        ownerId: ownerId,
        name: 'Original',
        createdAt: fixedPast,
        updatedAt: Value(fixedPast),
      ),
    );

    final before = await listsRepository.getById(listId);
    expect(before, isNotNull);

    await listsRepository.update(before!.copyWith(name: 'Renamed'));

    final after = await listsRepository.getById(listId);
    expect(after?.name, 'Renamed');
    expect(after!.updatedAt, isNot(before.updatedAt));
    expect(after.updatedAt!.isAfter(fixedPast), isTrue);
  });

  test('tombstone and restore list', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: listId,
        ownerId: ownerId,
        name: 'To Delete',
        createdAt: now,
      ),
    );

    await listsRepository.tombstoneById(listId);
    final afterDelete = await listsRepository.getListsForOwner(ownerId);
    expect(afterDelete.where((list) => list.id == listId), isEmpty);

    await listsRepository.restoreById(listId);
    final afterRestore = await listsRepository.getListsForOwner(ownerId);
    expect(afterRestore.where((list) => list.id == listId), isNotEmpty);
  });

  test('new items get increasing sortOrder by 1000', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: listId,
        ownerId: ownerId,
        name: 'Main',
        createdAt: now,
      ),
    );

    await itemsRepository.create(
      ShoppingItem(id: 'i1', listId: listId, name: 'Milk', createdAt: now),
    );
    await itemsRepository.create(
      ShoppingItem(id: 'i2', listId: listId, name: 'Eggs', createdAt: now),
    );
    await itemsRepository.create(
      ShoppingItem(id: 'i3', listId: listId, name: 'Bread', createdAt: now),
    );

    final items = await itemsRepository.getItemsForList(listId);
    expect(items.map((item) => item.sortOrder).toList(), [1000, 2000, 3000]);
  });

  test('checked item is ordered after unchecked items', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(
        id: listId,
        ownerId: ownerId,
        name: 'Main',
        createdAt: now,
      ),
    );

    await itemsRepository.create(
      ShoppingItem(id: 'i1', listId: listId, name: 'Milk', createdAt: now),
    );
    await itemsRepository.create(
      ShoppingItem(id: 'i2', listId: listId, name: 'Eggs', createdAt: now),
    );
    await itemsRepository.create(
      ShoppingItem(id: 'i3', listId: listId, name: 'Bread', createdAt: now),
    );

    await itemsRepository.setChecked(id: 'i2', isChecked: true);

    final items = await itemsRepository.getItemsForList(listId);
    expect(items.map((item) => item.id).toList(), ['i1', 'i3', 'i2']);
    expect(items.last.isChecked, isTrue);
  });
}
