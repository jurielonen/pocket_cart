import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_lists_dao.dart';
import '../../../core/database/daos/sync_outbox_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_list.dart';
import '../domain/repositories/shopping_lists_repository.dart';

part 'drift_shopping_lists_repository.g.dart';

class DriftShoppingListsRepository implements ShoppingListsRepository {
  DriftShoppingListsRepository(this._dao, this._outboxDao);

  final ShoppingListsDao _dao;
  final SyncOutboxDao _outboxDao;

  @override
  Future<List<ShoppingList>> getListsForOwner(String ownerId) async {
    final rows = await _dao.getListsForOwner(ownerId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingList>> watchListsForOwner(String ownerId) {
    return _dao
        .watchListsForOwner(ownerId)
        .map((rows) => rows.map(_toModel).toList(growable: false));
  }

  @override
  Future<ShoppingList?> getById(String id) async {
    final row = await _dao.getListById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingList list) {
    final now = _now();
    final writeModel = list.copyWith(
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
    );
    return _writeAndQueueUpsert(writeModel);
  }

  @override
  Future<void> update(ShoppingList list) {
    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
    );
    return _writeAndQueueUpsert(writeModel);
  }

  @override
  Future<void> deleteById(String id) async {
    final existing = await _dao.getListById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _dao.softDeleteListById(id: id, deletedAt: now);
    await _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'list',
        operation: 'delete',
        ownerId: existing.ownerId,
        entityId: id,
        payload: jsonEncode(
          {
            'id': id,
            'ownerId': existing.ownerId,
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
    required String ownerId,
    required List<String> orderedIds,
  }) async {
    await _dao.reorderLists(ownerId: ownerId, orderedIds: orderedIds);
    final reorderedRows = await _dao.getListsForOwner(ownerId);
    for (final row in reorderedRows) {
      await _outboxDao.enqueue(
        SyncOutboxTableCompanion.insert(
          entityType: 'list',
          operation: 'upsert',
          ownerId: row.ownerId,
          entityId: row.id,
          payload: jsonEncode(_payloadFromListRow(row)),
          createdAt: _now(),
        ),
      );
    }
  }

  ShoppingList _toModel(ShoppingListsTableData row) {
    return ShoppingList(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      isArchived: row.isArchived,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingListsTableCompanion _toCompanion(ShoppingList list) {
    return ShoppingListsTableCompanion.insert(
      id: list.id,
      ownerId: list.ownerId,
      name: list.name,
      isArchived: drift.Value(list.isArchived),
      isDeleted: drift.Value(list.isDeleted),
      deletedAt: drift.Value(list.deletedAt),
      sortOrder: drift.Value(list.sortOrder),
      createdAt: list.createdAt,
      updatedAt: drift.Value(list.updatedAt),
    );
  }

  Future<void> _writeAndQueueUpsert(ShoppingList list) async {
    await _dao.updateList(_toCompanion(list));
    await _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'list',
        operation: 'upsert',
        ownerId: list.ownerId,
        entityId: list.id,
        payload: jsonEncode(_payloadFromModel(list)),
        createdAt: _now(),
      ),
    );
  }

  Map<String, dynamic> _payloadFromModel(ShoppingList list) {
    return {
      'id': list.id,
      'ownerId': list.ownerId,
      'name': list.name,
      'isArchived': list.isArchived,
      'isDeleted': list.isDeleted,
      'sortOrder': list.sortOrder,
      'createdAt': list.createdAt.millisecondsSinceEpoch,
      'updatedAt':
          (list.updatedAt ?? list.createdAt).millisecondsSinceEpoch,
      'deletedAt': list.deletedAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _payloadFromListRow(ShoppingListsTableData row) {
    return {
      'id': row.id,
      'ownerId': row.ownerId,
      'name': row.name,
      'isArchived': row.isArchived,
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
ShoppingListsRepository shoppingListsRepository(Ref ref) {
  final dao = ref.watch(shoppingListsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  return DriftShoppingListsRepository(dao, outboxDao);
}
