import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_items_table.dart';

part 'shopping_items_dao.g.dart';

@DriftAccessor(tables: [ShoppingItemsTable])
class ShoppingItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingItemsDaoMixin {
  ShoppingItemsDao(super.db);

  Future<List<ShoppingItemsTableData>> getItemsForList(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where(
        (table) => table.listId.equals(listId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);
    return query.get();
  }

  Stream<List<ShoppingItemsTableData>> watchItemsForList(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where(
        (table) => table.listId.equals(listId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);
    return query.watch();
  }

  Future<ShoppingItemsTableData?> getItemById(String id) {
    return (select(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<ShoppingItemsTableData>> getAllItemsForList(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where((table) => table.listId.equals(listId));
    return query.get();
  }

  Future<void> insertItem(ShoppingItemsTableCompanion item) async {
    await into(attachedDatabase.shoppingItemsTable).insert(item);
  }

  Future<void> updateItem(ShoppingItemsTableCompanion item) async {
    await into(attachedDatabase.shoppingItemsTable).insertOnConflictUpdate(item);
  }

  Future<int> deleteItemById(String id) {
    return (delete(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  Future<void> softDeleteItemById({
    required String id,
    required DateTime deletedAt,
  }) async {
    await (update(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingItemsTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> reorderItems({
    required String listId,
    required List<String> orderedIds,
  }) async {
    await transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        final id = orderedIds[index];
        await (update(attachedDatabase.shoppingItemsTable)
              ..where((table) => table.id.equals(id) & table.listId.equals(listId)))
            .write(
          ShoppingItemsTableCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
