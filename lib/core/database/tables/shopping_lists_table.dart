import 'package:drift/drift.dart';

class ShoppingListsTable extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
