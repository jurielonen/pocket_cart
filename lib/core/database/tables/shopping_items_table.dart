import 'package:drift/drift.dart';

class ShoppingItemsTable extends Table {
  TextColumn get id => text()();

  TextColumn get listId => text()();

  TextColumn get name => text()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
