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
    final rows = await _dao.getLists(ownerId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingList>> watchListsForOwner(String ownerId) {
    return _dao.watchLists(ownerId).map(
          (rows) => rows.map(_toModel).toList(growable: false),
        );
  }

  @override
  Future<ShoppingList?> getById(String id) async {
    final row = await _dao.getListById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingList list) async {
    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
    );
    await _dao.upsertList(_toCompanion(writeModel));
    await _enqueueUpsert(writeModel);
  }

  @override
  Future<void> update(ShoppingList list) async {
    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
    );
    await _dao.upsertList(_toCompanion(writeModel));
    await _enqueueUpsert(writeModel);
  }

  @override
  Future<void> tombstoneById(String id) async {
    final existing = await _dao.getListById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _dao.tombstoneList(id: id, deletedAt: now);
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
  Future<void> restoreById(String id) async {
    final existing = await _dao.getListById(id);
    if (existing == null || !existing.isDeleted) {
      return;
    }

    await _dao.restoreList(id: id);
    final restored = await _dao.getListById(id);
    if (restored == null) {
      return;
    }
    await _enqueueUpsert(_toModel(restored));
  }

  @override
  Future<void> reorder({
    required String ownerId,
    required List<String> orderedIds,
  }) async {
    final existing = await _dao.getLists(ownerId);
    for (var index = 0; index < orderedIds.length; index++) {
      final id = orderedIds[index];
      ShoppingListsTableData? row;
      for (final item in existing) {
        if (item.id == id) {
          row = item;
          break;
        }
      }
      if (row == null) {
        continue;
      }
      final updated = _toModel(row).copyWith(
        sortOrder: (index + 1) * 1000,
        updatedAt: _now(),
      );
      await _dao.upsertList(_toCompanion(updated));
      await _enqueueUpsert(updated);
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
      updatedAt: drift.Value(list.updatedAt ?? list.createdAt),
    );
  }

  Future<void> _enqueueUpsert(ShoppingList list) {
    return _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'list',
        operation: 'upsert',
        ownerId: list.ownerId,
        entityId: list.id,
        payload: jsonEncode(
          {
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
          },
        ),
        createdAt: _now(),
      ),
    );
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingListsRepository shoppingListsRepository(Ref ref) {
  final dao = ref.watch(shoppingListsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  return DriftShoppingListsRepository(dao, outboxDao);
}
