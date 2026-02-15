import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_lists_table.dart';

part 'shopping_lists_dao.g.dart';

@DriftAccessor(tables: [ShoppingListsTable])
class ShoppingListsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingListsDaoMixin {
  ShoppingListsDao(super.db);

  Stream<List<ShoppingListsTableData>> watchLists(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where(
        (table) => table.ownerId.equals(ownerId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.desc(table.createdAt),
      ]);
    return query.watch();
  }

  Future<List<ShoppingListsTableData>> getLists(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where(
        (table) => table.ownerId.equals(ownerId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.desc(table.createdAt),
      ]);
    return query.get();
  }

  Stream<ShoppingListsTableData?> watchListById(String id) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where((table) => table.id.equals(id));
    return query.watchSingleOrNull();
  }

  Future<ShoppingListsTableData?> getListById(String id) {
    return (select(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertList(ShoppingListsTableCompanion list) {
    return into(attachedDatabase.shoppingListsTable).insertOnConflictUpdate(list);
  }

  Future<void> tombstoneList({
    required String id,
    required DateTime deletedAt,
  }) {
    return (update(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingListsTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> restoreList({required String id}) {
    final now = DateTime.now().toUtc();
    return (update(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingListsTableCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }
}
