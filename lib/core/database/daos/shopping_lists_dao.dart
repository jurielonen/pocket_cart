import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/shopping_lists_table.dart';

part 'shopping_lists_dao.g.dart';

@DriftAccessor(tables: [ShoppingListsTable])
class ShoppingListsDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingListsDaoMixin {
  ShoppingListsDao(super.db);

  Stream<List<ShoppingListsTableData>> watchListsForOwner(String ownerId) {
    final query = select(attachedDatabase.shoppingListsTable)
      ..where((table) => table.ownerId.equals(ownerId));
    return query.watch();
  }

  Future<void> upsertList(ShoppingListsTableCompanion list) async {
    await into(attachedDatabase.shoppingListsTable).insertOnConflictUpdate(list);
  }

  Future<int> deleteListById(String id) {
    return (delete(attachedDatabase.shoppingListsTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }
}
