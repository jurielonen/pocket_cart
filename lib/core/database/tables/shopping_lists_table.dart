import 'package:drift/drift.dart';

class ShoppingListsTable extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  IntColumn get color => integer().nullable()();

  TextColumn get icon => text().nullable()();

  TextColumn get sortMode => text().withDefault(const Constant('manual'))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get revision => integer().withDefault(const Constant(0))();

  TextColumn get deviceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
