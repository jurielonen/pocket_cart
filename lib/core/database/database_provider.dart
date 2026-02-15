import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'daos/shopping_items_dao.dart';
import 'daos/shopping_lists_dao.dart';
import 'daos/sync_outbox_dao.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}

@Riverpod(keepAlive: true)
ShoppingListsDao shoppingListsDao(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return database.shoppingListsDao;
}

@Riverpod(keepAlive: true)
ShoppingItemsDao shoppingItemsDao(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return database.shoppingItemsDao;
}

@Riverpod(keepAlive: true)
SyncOutboxDao syncOutboxDao(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return database.syncOutboxDao;
}
