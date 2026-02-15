import 'package:drift/drift.dart';

class ShoppingItemsTable extends Table {
  TextColumn get id => text()();

  TextColumn get listId => text()();

  TextColumn get ownerId => text().withDefault(const Constant(''))();

  TextColumn get name => text()();

  RealColumn get quantity => real().nullable()();

  TextColumn get unit => text().nullable()();

  TextColumn get category => text().nullable()();

  TextColumn get note => text().nullable()();

  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get checkedAt => dateTime().nullable()();

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
