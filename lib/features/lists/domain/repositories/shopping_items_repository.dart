import '../models/shopping_item.dart';

abstract class ShoppingItemsRepository {
  Future<List<ShoppingItem>> getItemsForList(String listId);

  Stream<List<ShoppingItem>> watchItemsForList(String listId);

  Future<ShoppingItem?> getById(String id);

  Future<void> create(ShoppingItem item);

  Future<void> update(ShoppingItem item);

  Future<void> deleteById(String id);

  Future<void> reorder({
    required String listId,
    required List<String> orderedIds,
  });
}
