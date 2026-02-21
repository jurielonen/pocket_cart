import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_cart/features/lists/data/firestore_shopping_items_repository.dart';
import 'package:pocket_cart/features/lists/data/firestore_shopping_lists_repository.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_item.dart';
import 'package:pocket_cart/features/lists/domain/models/shopping_list.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreShoppingListsRepository listsRepository;
  late FirestoreShoppingItemsRepository itemsRepository;

  const ownerId = 'owner-1';
  const listId = 'list-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    listsRepository = FirestoreShoppingListsRepository(
      firestore,
      () => ownerId,
    );
    itemsRepository = FirestoreShoppingItemsRepository(
      firestore,
      () => ownerId,
    );
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
      ShoppingList(id: listId, ownerId: ownerId, name: 'Main', createdAt: now),
    );

    await itemsRepository.create(
      ShoppingItem(
        id: 'i1',
        listId: listId,
        ownerId: ownerId,
        name: 'Milk',
        createdAt: now,
      ),
    );
    await itemsRepository.create(
      ShoppingItem(
        id: 'i2',
        listId: listId,
        ownerId: ownerId,
        name: 'Eggs',
        createdAt: now,
      ),
    );
    await itemsRepository.create(
      ShoppingItem(
        id: 'i3',
        listId: listId,
        ownerId: ownerId,
        name: 'Bread',
        createdAt: now,
      ),
    );

    final items = await itemsRepository.getItemsForList(listId);
    expect(items.map((item) => item.sortOrder).toList(), [1000, 2000, 3000]);
  });

  test('checked item is ordered after unchecked items', () async {
    final now = DateTime.now().toUtc();

    await listsRepository.create(
      ShoppingList(id: listId, ownerId: ownerId, name: 'Main', createdAt: now),
    );

    await itemsRepository.create(
      ShoppingItem(
        id: 'i1',
        listId: listId,
        ownerId: ownerId,
        name: 'Milk',
        createdAt: now,
      ),
    );
    await itemsRepository.create(
      ShoppingItem(
        id: 'i2',
        listId: listId,
        ownerId: ownerId,
        name: 'Eggs',
        createdAt: now,
      ),
    );
    await itemsRepository.create(
      ShoppingItem(
        id: 'i3',
        listId: listId,
        ownerId: ownerId,
        name: 'Bread',
        createdAt: now,
      ),
    );

    await itemsRepository.setChecked(
      listId: listId,
      id: 'i2',
      isChecked: true,
    );

    final items = await itemsRepository.getItemsForList(listId);
    expect(items.map((item) => item.id).toList(), ['i1', 'i3', 'i2']);
    expect(items.last.isChecked, isTrue);
  });
}
