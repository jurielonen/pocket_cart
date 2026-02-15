import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_outbox_table.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutboxTable])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase> with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  Future<void> enqueue(SyncOutboxTableCompanion entry) async {
    await into(attachedDatabase.syncOutboxTable).insert(entry);
  }

  Future<List<SyncOutboxTableData>> getPendingChanges({int limit = 200}) {
    final query = select(attachedDatabase.syncOutboxTable)
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
      ..limit(limit);
    return query.get();
  }

  Future<int> deleteById(int id) {
    return (delete(attachedDatabase.syncOutboxTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }
}
