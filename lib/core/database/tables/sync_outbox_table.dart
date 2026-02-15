import 'package:drift/drift.dart';

class SyncOutboxTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get entityType => text()();

  TextColumn get operation => text()();

  TextColumn get ownerId => text()();

  TextColumn get listId => text().nullable()();

  TextColumn get entityId => text()();

  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();
}
