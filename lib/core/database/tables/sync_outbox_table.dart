import 'package:drift/drift.dart';

class SyncOutboxTable extends Table {
  TextColumn get id => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get listId => text().nullable()();

  TextColumn get opType => text()();

  TextColumn get payloadJson => text()();

  IntColumn get updatedAtMillis => integer()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  IntColumn get createdAtMillis => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
