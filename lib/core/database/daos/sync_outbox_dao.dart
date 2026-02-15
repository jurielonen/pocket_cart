import 'package:drift/drift.dart';

import '../../../features/lists/data/sync/outbox_operation.dart';
import '../app_database.dart';
import 'sync_outbox_store.dart';
import '../tables/sync_outbox_table.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutboxTable])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin
    implements SyncOutboxStore {
  SyncOutboxDao(super.db);

  Future<void> enqueue({
    required String id,
    required OutboxEntityType entityType,
    required String entityId,
    String? listId,
    required OutboxOpType opType,
    required String payloadJson,
    required int updatedAtMillis,
    required int createdAtMillis,
  }) {
    return into(attachedDatabase.syncOutboxTable).insertOnConflictUpdate(
      SyncOutboxTableCompanion.insert(
        id: id,
        entityType: entityType.name,
        entityId: entityId,
        listId: Value(listId),
        opType: opType.name,
        payloadJson: payloadJson,
        updatedAtMillis: updatedAtMillis,
        createdAtMillis: createdAtMillis,
      ),
    );
  }

  @override
  Stream<List<SyncOutboxEntry>> watchPending({int limit = 200}) {
    final query = select(attachedDatabase.syncOutboxTable)
      ..orderBy([
        (table) => OrderingTerm.asc(table.updatedAtMillis),
        (table) => OrderingTerm.asc(table.createdAtMillis),
      ])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_toEntry).toList(growable: false));
  }

  @override
  Future<List<SyncOutboxEntry>> getPending({int limit = 200}) async {
    final query = select(attachedDatabase.syncOutboxTable)
      ..orderBy([
        (table) => OrderingTerm.asc(table.updatedAtMillis),
        (table) => OrderingTerm.asc(table.createdAtMillis),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toEntry).toList(growable: false);
  }

  @override
  Future<void> markDone(String id) async {
    await (delete(attachedDatabase.syncOutboxTable)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  @override
  Future<void> markFailed(String id, String error) async {
    final row = await (select(attachedDatabase.syncOutboxTable)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      return;
    }

    await (update(attachedDatabase.syncOutboxTable)
          ..where((table) => table.id.equals(id)))
        .write(
      SyncOutboxTableCompanion(
        attemptCount: Value(row.attemptCount + 1),
        lastError: Value(error),
        updatedAtMillis: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> clearAll() async {
    await delete(attachedDatabase.syncOutboxTable).go();
  }

  SyncOutboxEntry _toEntry(SyncOutboxTableData row) {
    return SyncOutboxEntry(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      listId: row.listId,
      opType: row.opType,
      payloadJson: row.payloadJson,
      updatedAtMillis: row.updatedAtMillis,
      attemptCount: row.attemptCount,
      lastError: row.lastError,
      createdAtMillis: row.createdAtMillis,
    );
  }
}
