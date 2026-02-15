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
  final baseTime = DateTime(2026, 1, 1, 12);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    listsRepository = DriftShoppingListsRepository(
      database.shoppingListsDao,
      database.syncOutboxDao,
    );
    itemsRepository = DriftShoppingItemsRepository(
      database.shoppingItemsDao,
      database.syncOutboxDao,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('shopping lists CRUD and reorder', () async {
    final list1 = ShoppingList(
      id: 'l1',
      ownerId: ownerId,
      name: 'Weekly',
      sortOrder: 0,
      createdAt: baseTime,
    );
    final list2 = ShoppingList(
      id: 'l2',
      ownerId: ownerId,
      name: 'Party',
      sortOrder: 1,
      createdAt: baseTime.add(const Duration(minutes: 1)),
    );
    final list3 = ShoppingList(
      id: 'l3',
      ownerId: ownerId,
      name: 'Camping',
      sortOrder: 2,
      createdAt: baseTime.add(const Duration(minutes: 2)),
    );

    await listsRepository.create(list1);
    await listsRepository.create(list2);
    await listsRepository.create(list3);

    final created = await listsRepository.getListsForOwner(ownerId);
    expect(created.map((list) => list.id).toList(), ['l1', 'l2', 'l3']);

    await listsRepository.update(
      list1.copyWith(name: 'Weekly Updated', isArchived: true),
    );
    final updated = await listsRepository.getById('l1');
    expect(updated?.name, 'Weekly Updated');
    expect(updated?.isArchived, isTrue);

    await listsRepository.reorder(ownerId: ownerId, orderedIds: ['l3', 'l1', 'l2']);
    final reordered = await listsRepository.getListsForOwner(ownerId);
    expect(reordered.map((list) => list.id).toList(), ['l3', 'l1', 'l2']);
    expect(reordered.map((list) => list.sortOrder).toList(), [0, 1, 2]);

    await listsRepository.deleteById('l2');
    final afterDelete = await listsRepository.getListsForOwner(ownerId);
    expect(afterDelete.map((list) => list.id).toList(), ['l3', 'l1']);
  });

  test('shopping items CRUD and reorder', () async {
    await listsRepository.create(
      ShoppingList(
        id: listId,
        ownerId: ownerId,
        name: 'Main List',
        createdAt: baseTime,
      ),
    );

    final item1 = ShoppingItem(
      id: 'i1',
      listId: listId,
      name: 'Milk',
      quantity: 1,
      sortOrder: 0,
      createdAt: baseTime,
    );
    final item2 = ShoppingItem(
      id: 'i2',
      listId: listId,
      name: 'Bread',
      quantity: 2,
      sortOrder: 1,
      createdAt: baseTime.add(const Duration(minutes: 1)),
    );
    final item3 = ShoppingItem(
      id: 'i3',
      listId: listId,
      name: 'Cheese',
      quantity: 1,
      sortOrder: 2,
      createdAt: baseTime.add(const Duration(minutes: 2)),
    );

    await itemsRepository.create(item1);
    await itemsRepository.create(item2);
    await itemsRepository.create(item3);

    final created = await itemsRepository.getItemsForList(listId);
    expect(created.map((item) => item.id).toList(), ['i1', 'i2', 'i3']);

    await itemsRepository.update(
      item1.copyWith(quantity: 3, isChecked: true, name: 'Milk 2%'),
    );
    final updated = await itemsRepository.getById('i1');
    expect(updated?.quantity, 3);
    expect(updated?.isChecked, isTrue);
    expect(updated?.name, 'Milk 2%');

    await itemsRepository.reorder(listId: listId, orderedIds: ['i2', 'i3', 'i1']);
    final reordered = await itemsRepository.getItemsForList(listId);
    expect(reordered.map((item) => item.id).toList(), ['i2', 'i3', 'i1']);
    expect(reordered.map((item) => item.sortOrder).toList(), [0, 1, 2]);

    await itemsRepository.deleteById('i2');
    final afterDelete = await itemsRepository.getItemsForList(listId);
    expect(afterDelete.map((item) => item.id).toList(), ['i3', 'i1']);
  });
}
