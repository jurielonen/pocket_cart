import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_items_table.dart';

part 'shopping_items_dao.g.dart';

@DriftAccessor(tables: [ShoppingItemsTable])
class ShoppingItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingItemsDaoMixin {
  ShoppingItemsDao(super.db);

  Stream<List<ShoppingItemsTableData>> watchItems(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where(
        (table) => table.listId.equals(listId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.isChecked),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.desc(table.checkedAt),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch();
  }

  Future<List<ShoppingItemsTableData>> getItems(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where(
        (table) => table.listId.equals(listId) & table.isDeleted.equals(false),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.isChecked),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.desc(table.checkedAt),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.get();
  }

  Stream<int> watchActiveItemCount(String listId) {
    final countExp = attachedDatabase.shoppingItemsTable.id.count();
    final query = selectOnly(attachedDatabase.shoppingItemsTable)
      ..addColumns([countExp])
      ..where(
        attachedDatabase.shoppingItemsTable.listId.equals(listId) &
            attachedDatabase.shoppingItemsTable.isDeleted.equals(false),
      );

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  Future<ShoppingItemsTableData?> getItemById(String id) {
    return (select(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> getNextSortOrder(String listId) async {
    final maxExp = attachedDatabase.shoppingItemsTable.sortOrder.max();
    final query = selectOnly(attachedDatabase.shoppingItemsTable)
      ..addColumns([maxExp])
      ..where(
        attachedDatabase.shoppingItemsTable.listId.equals(listId) &
            attachedDatabase.shoppingItemsTable.isDeleted.equals(false),
      );

    final row = await query.getSingleOrNull();
    final maxValue = row?.read(maxExp);
    if (maxValue == null) {
      return 1000;
    }
    return maxValue + 1000;
  }

  Future<void> upsertItem(ShoppingItemsTableCompanion item) {
    return into(attachedDatabase.shoppingItemsTable).insertOnConflictUpdate(item);
  }

  Future<void> setItemChecked({
    required String id,
    required bool isChecked,
  }) {
    final now = DateTime.now().toUtc();
    return (update(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingItemsTableCompanion(
        isChecked: Value(isChecked),
        checkedAt: Value(isChecked ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> tombstoneItem({
    required String id,
    required DateTime deletedAt,
  }) {
    return (update(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingItemsTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> restoreItem({required String id}) {
    final now = DateTime.now().toUtc();
    return (update(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .write(
      ShoppingItemsTableCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> reorderUncheckedItems({
    required String listId,
    required List<String> orderedUncheckedIds,
  }) async {
    await transaction(() async {
      for (var index = 0; index < orderedUncheckedIds.length; index++) {
        final id = orderedUncheckedIds[index];
        await (update(attachedDatabase.shoppingItemsTable)
              ..where(
                (table) =>
                    table.id.equals(id) &
                    table.listId.equals(listId) &
                    table.isDeleted.equals(false) &
                    table.isChecked.equals(false),
              ))
            .write(
          ShoppingItemsTableCompanion(
            sortOrder: Value((index + 1) * 1000),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
    });
  }
}
