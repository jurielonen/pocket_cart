import '../models/shopping_list.dart';
import '../write_origin.dart';

abstract class ShoppingListsRepository {
  Future<List<ShoppingList>> getListsForOwner(String ownerId);

  Stream<List<ShoppingList>> watchListsForOwner(String ownerId);

  Future<ShoppingList?> getById(String id);

  Future<void> create(
    ShoppingList list, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> update(
    ShoppingList list, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> tombstoneById(
    String id, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> restoreById(
    String id, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> reorder({
    required String ownerId,
    required List<String> orderedIds,
  });
}
