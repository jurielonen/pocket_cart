import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_lists_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_list.dart';
import '../domain/repositories/shopping_lists_repository.dart';

part 'drift_shopping_lists_repository.g.dart';

class DriftShoppingListsRepository implements ShoppingListsRepository {
  DriftShoppingListsRepository(this._dao);

  final ShoppingListsDao _dao;

  @override
  Future<List<ShoppingList>> getListsForOwner(String ownerId) async {
    final rows = await _dao.getListsForOwner(ownerId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingList>> watchListsForOwner(String ownerId) {
    return _dao
        .watchListsForOwner(ownerId)
        .map((rows) => rows.map(_toModel).toList(growable: false));
  }

  @override
  Future<ShoppingList?> getById(String id) async {
    final row = await _dao.getListById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingList list) {
    return _dao.insertList(_toCompanion(list));
  }

  @override
  Future<void> update(ShoppingList list) {
    return _dao.updateList(_toCompanion(list));
  }

  @override
  Future<void> deleteById(String id) {
    return _dao.deleteListById(id);
  }

  @override
  Future<void> reorder({
    required String ownerId,
    required List<String> orderedIds,
  }) {
    return _dao.reorderLists(ownerId: ownerId, orderedIds: orderedIds);
  }

  ShoppingList _toModel(ShoppingListsTableData row) {
    return ShoppingList(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      isArchived: row.isArchived,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingListsTableCompanion _toCompanion(ShoppingList list) {
    return ShoppingListsTableCompanion.insert(
      id: list.id,
      ownerId: list.ownerId,
      name: list.name,
      isArchived: drift.Value(list.isArchived),
      sortOrder: drift.Value(list.sortOrder),
      createdAt: list.createdAt,
      updatedAt: drift.Value(list.updatedAt),
    );
  }
}

@Riverpod(keepAlive: true)
ShoppingListsRepository shoppingListsRepository(Ref ref) {
  final dao = ref.watch(shoppingListsDaoProvider);
  return DriftShoppingListsRepository(dao);
}
