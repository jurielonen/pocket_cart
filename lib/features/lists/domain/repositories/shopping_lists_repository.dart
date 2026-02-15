import '../models/shopping_list.dart';

abstract class ShoppingListsRepository {
  Future<List<ShoppingList>> getListsForOwner(String ownerId);

  Stream<List<ShoppingList>> watchListsForOwner(String ownerId);

  Future<ShoppingList?> getById(String id);

  Future<void> create(ShoppingList list);

  Future<void> update(ShoppingList list);

  Future<void> tombstoneById(String id);

  Future<void> restoreById(String id);

  Future<void> reorder({
    required String ownerId,
    required List<String> orderedIds,
  });
}
