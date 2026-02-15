import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_items_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_item.dart';
import '../domain/repositories/shopping_items_repository.dart';

part 'drift_shopping_items_repository.g.dart';

class DriftShoppingItemsRepository implements ShoppingItemsRepository {
  DriftShoppingItemsRepository(this._dao);

  final ShoppingItemsDao _dao;

  @override
  Future<List<ShoppingItem>> getItemsForList(String listId) async {
    final rows = await _dao.getItemsForList(listId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingItem>> watchItemsForList(String listId) {
    return _dao
        .watchItemsForList(listId)
        .map((rows) => rows.map(_toModel).toList(growable: false));
  }

  @override
  Future<ShoppingItem?> getById(String id) async {
    final row = await _dao.getItemById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingItem item) {
    return _dao.insertItem(_toCompanion(item));
  }

  @override
  Future<void> update(ShoppingItem item) {
    return _dao.updateItem(_toCompanion(item));
  }

  @override
  Future<void> deleteById(String id) {
    return _dao.deleteItemById(id);
  }

  @override
  Future<void> reorder({
    required String listId,
    required List<String> orderedIds,
  }) {
    return _dao.reorderItems(listId: listId, orderedIds: orderedIds);
  }

  ShoppingItem _toModel(ShoppingItemsTableData row) {
    return ShoppingItem(
      id: row.id,
      listId: row.listId,
      name: row.name,
      quantity: row.quantity,
      isChecked: row.isChecked,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingItemsTableCompanion _toCompanion(ShoppingItem item) {
    return ShoppingItemsTableCompanion.insert(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: drift.Value(item.quantity),
      isChecked: drift.Value(item.isChecked),
      sortOrder: drift.Value(item.sortOrder),
      createdAt: item.createdAt,
      updatedAt: drift.Value(item.updatedAt),
    );
  }
}

@Riverpod(keepAlive: true)
ShoppingItemsRepository shoppingItemsRepository(Ref ref) {
  final dao = ref.watch(shoppingItemsDaoProvider);
  return DriftShoppingItemsRepository(dao);
}
