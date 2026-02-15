import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/shopping_items_dao.dart';
import 'daos/shopping_lists_dao.dart';
import 'daos/sync_outbox_dao.dart';
import 'tables/shopping_items_table.dart';
import 'tables/shopping_lists_table.dart';
import 'tables/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [ShoppingListsTable, ShoppingItemsTable, SyncOutboxTable],
  daos: [ShoppingListsDao, ShoppingItemsDao, SyncOutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'pocket_cart.sqlite',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.dart.js'),
            ),
          ),
        );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 3) {
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.isDeleted);
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.deletedAt);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.isDeleted);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.deletedAt);
            await migrator.createTable(syncOutboxTable);
          }
          if (from < 4) {
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.checkedAt);
          }
          if (from < 5) {
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.color);
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.icon);
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.sortMode);
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.revision);
            await migrator.addColumn(shoppingListsTable, shoppingListsTable.deviceId);

            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.ownerId);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.quantity);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.unit);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.category);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.note);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.revision);
            await migrator.addColumn(shoppingItemsTable, shoppingItemsTable.deviceId);

            await customStatement('DROP TABLE IF EXISTS sync_outbox_table;');
            await migrator.createTable(syncOutboxTable);
          }
        },
      );
}
