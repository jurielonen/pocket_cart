import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_items_dao.dart';
import '../../../core/database/daos/sync_outbox_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_item.dart';
import '../domain/repositories/shopping_items_repository.dart';

part 'drift_shopping_items_repository.g.dart';

class DriftShoppingItemsRepository implements ShoppingItemsRepository {
  DriftShoppingItemsRepository(this._dao, this._outboxDao);

  final ShoppingItemsDao _dao;
  final SyncOutboxDao _outboxDao;

  @override
  Future<List<ShoppingItem>> getItemsForList(String listId) async {
    final rows = await _dao.getItemsForList(listId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingItem>> watchItemsForList(String listId) {
    return _dao
        .watchItemsForList(listId)
        .map((rows) => rows.map(_toModel).toList(growable: false));
  }

  @override
  Future<ShoppingItem?> getById(String id) async {
    final row = await _dao.getItemById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingItem item) {
    final now = _now();
    final writeModel = item.copyWith(
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
    );
    return _writeAndQueueUpsert(writeModel);
  }

  @override
  Future<void> update(ShoppingItem item) {
    final now = _now();
    final writeModel = item.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
    );
    return _writeAndQueueUpsert(writeModel);
  }

  @override
  Future<void> deleteById(String id) async {
    final existing = await _dao.getItemById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _dao.softDeleteItemById(id: id, deletedAt: now);
    await _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'item',
        operation: 'delete',
        ownerId: '',
        listId: drift.Value(existing.listId),
        entityId: id,
        payload: jsonEncode(
          {
            'id': id,
            'listId': existing.listId,
            'isDeleted': true,
            'deletedAt': now.millisecondsSinceEpoch,
            'updatedAt': now.millisecondsSinceEpoch,
          },
        ),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> reorder({
    required String listId,
    required List<String> orderedIds,
  }) async {
    await _dao.reorderItems(listId: listId, orderedIds: orderedIds);
    final reorderedRows = await _dao.getItemsForList(listId);
    for (final row in reorderedRows) {
      await _outboxDao.enqueue(
        SyncOutboxTableCompanion.insert(
          entityType: 'item',
          operation: 'upsert',
          ownerId: '',
          listId: drift.Value(row.listId),
          entityId: row.id,
          payload: jsonEncode(_payloadFromItemRow(row)),
          createdAt: _now(),
        ),
      );
    }
  }

  ShoppingItem _toModel(ShoppingItemsTableData row) {
    return ShoppingItem(
      id: row.id,
      listId: row.listId,
      name: row.name,
      quantity: row.quantity,
      isChecked: row.isChecked,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingItemsTableCompanion _toCompanion(ShoppingItem item) {
    return ShoppingItemsTableCompanion.insert(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: drift.Value(item.quantity),
      isChecked: drift.Value(item.isChecked),
      isDeleted: drift.Value(item.isDeleted),
      deletedAt: drift.Value(item.deletedAt),
      sortOrder: drift.Value(item.sortOrder),
      createdAt: item.createdAt,
      updatedAt: drift.Value(item.updatedAt),
    );
  }

  Future<void> _writeAndQueueUpsert(ShoppingItem item) async {
    await _dao.updateItem(_toCompanion(item));
    await _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'item',
        operation: 'upsert',
        ownerId: '',
        listId: drift.Value(item.listId),
        entityId: item.id,
        payload: jsonEncode(_payloadFromModel(item)),
        createdAt: _now(),
      ),
    );
  }

  Map<String, dynamic> _payloadFromModel(ShoppingItem item) {
    return {
      'id': item.id,
      'listId': item.listId,
      'name': item.name,
      'quantity': item.quantity,
      'isChecked': item.isChecked,
      'isDeleted': item.isDeleted,
      'sortOrder': item.sortOrder,
      'createdAt': item.createdAt.millisecondsSinceEpoch,
      'updatedAt':
          (item.updatedAt ?? item.createdAt).millisecondsSinceEpoch,
      'deletedAt': item.deletedAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _payloadFromItemRow(ShoppingItemsTableData row) {
    return {
      'id': row.id,
      'listId': row.listId,
      'name': row.name,
      'quantity': row.quantity,
      'isChecked': row.isChecked,
      'isDeleted': row.isDeleted,
      'sortOrder': row.sortOrder,
      'createdAt': row.createdAt.millisecondsSinceEpoch,
      'updatedAt':
          (row.updatedAt ?? row.createdAt).millisecondsSinceEpoch,
      'deletedAt': row.deletedAt?.millisecondsSinceEpoch,
    };
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingItemsRepository shoppingItemsRepository(Ref ref) {
  final dao = ref.watch(shoppingItemsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  return DriftShoppingItemsRepository(dao, outboxDao);
}
