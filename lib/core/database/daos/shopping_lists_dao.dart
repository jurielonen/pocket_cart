import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_lists_table.dart';

part 'shopping_lists_dao.g.dart';

@DriftAccessor(tables: [ShoppingListsTable])
class ShoppingListsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingListsDaoMixin {
  ShoppingListsDao(super.db);

  Future<List<ShoppingListsTableData>> getListsForOwner(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where(
        (table) => table.ownerId.equals(ownerId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);
    return query.get();
  }

  Stream<List<ShoppingListsTableData>> watchListsForOwner(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where(
        (table) => table.ownerId.equals(ownerId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.createdAt),
      ]);
    return query.watch();
  }

  Future<ShoppingListsTableData?> getListById(String id) {
    return (select(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<ShoppingListsTableData>> getAllListsForOwner(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where((table) => table.ownerId.equals(ownerId));
    return query.get();
  }

  Future<void> insertList(ShoppingListsTableCompanion list) async {
    await into(attachedDatabase.shoppingListsTable).insert(list);
  }

  Future<void> updateList(ShoppingListsTableCompanion list) async {
    await into(attachedDatabase.shoppingListsTable).insertOnConflictUpdate(list);
  }

  Future<int> deleteListById(String id) {
    return (delete(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  Future<void> softDeleteListById({
    required String id,
    required DateTime deletedAt,
  }) async {
    await (update(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingListsTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> reorderLists({
    required String ownerId,
    required List<String> orderedIds,
  }) async {
    await transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        final id = orderedIds[index];
        await (update(attachedDatabase.shoppingListsTable)
              ..where(
                (table) =>
                    table.id.equals(id) & table.ownerId.equals(ownerId),
              ))
            .write(
          ShoppingListsTableCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}
