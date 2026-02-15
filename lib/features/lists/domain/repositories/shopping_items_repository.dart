import '../models/shopping_item.dart';
import '../write_origin.dart';

abstract class ShoppingItemsRepository {
  Future<List<ShoppingItem>> getItemsForList(String listId);

  Stream<List<ShoppingItem>> watchItemsForList(String listId);

  Stream<int> watchActiveItemCount(String listId);

  Future<ShoppingItem?> getById(String id);

  Future<void> create(
    ShoppingItem item, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> update(
    ShoppingItem item, {
    WriteOrigin origin = WriteOrigin.localUser,
  });

  Future<void> setChecked({
    required String id,
    required bool isChecked,
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
    required String listId,
    required List<String> orderedUncheckedIds,
  });
}
