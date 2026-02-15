import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_items_table.dart';

part 'shopping_items_dao.g.dart';

@DriftAccessor(tables: [ShoppingItemsTable])
class ShoppingItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingItemsDaoMixin {
  ShoppingItemsDao(super.db);

  Stream<List<ShoppingItemsTableData>> watchItemsForList(String listId) {
    final query = select(attachedDatabase.shoppingItemsTable)
      ..where((table) => table.listId.equals(listId));
    return query.watch();
  }

  Future<void> upsertItem(ShoppingItemsTableCompanion item) async {
    await into(attachedDatabase.shoppingItemsTable).insertOnConflictUpdate(item);
  }

  Future<int> deleteItemById(String id) {
    return (delete(attachedDatabase.shoppingItemsTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }
}
