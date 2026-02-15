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
    final rows = await _dao.getItems(listId);
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Stream<List<ShoppingItem>> watchItemsForList(String listId) {
    return _dao.watchItems(listId).map(
          (rows) => rows.map(_toModel).toList(growable: false),
        );
  }

  @override
  Stream<int> watchActiveItemCount(String listId) {
    return _dao.watchActiveItemCount(listId);
  }

  @override
  Future<ShoppingItem?> getById(String id) async {
    final row = await _dao.getItemById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> create(ShoppingItem item) async {
    final now = _now();
    final nextSortOrder = await _dao.getNextSortOrder(item.listId);
    final writeModel = item.copyWith(
      sortOrder: nextSortOrder,
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
      checkedAt: item.isChecked ? now : null,
    );
    await _dao.upsertItem(_toCompanion(writeModel));
    await _enqueueUpsert(writeModel);
  }

  @override
  Future<void> update(ShoppingItem item) async {
    final now = _now();
    final writeModel = item.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
      checkedAt: item.isChecked ? (item.checkedAt ?? now) : null,
    );
    await _dao.upsertItem(_toCompanion(writeModel));
    await _enqueueUpsert(writeModel);
  }

  @override
  Future<void> setChecked({required String id, required bool isChecked}) async {
    await _dao.setItemChecked(id: id, isChecked: isChecked);
    final updated = await _dao.getItemById(id);
    if (updated == null) {
      return;
    }
    await _enqueueUpsert(_toModel(updated));
  }

  @override
  Future<void> tombstoneById(String id) async {
    final existing = await _dao.getItemById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    await _dao.tombstoneItem(id: id, deletedAt: now);
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
  Future<void> restoreById(String id) async {
    final existing = await _dao.getItemById(id);
    if (existing == null || !existing.isDeleted) {
      return;
    }

    await _dao.restoreItem(id: id);
    final restored = await _dao.getItemById(id);
    if (restored == null) {
      return;
    }
    await _enqueueUpsert(_toModel(restored));
  }

  @override
  Future<void> reorder({
    required String listId,
    required List<String> orderedUncheckedIds,
  }) async {
    await _dao.reorderUncheckedItems(
      listId: listId,
      orderedUncheckedIds: orderedUncheckedIds,
    );

    final rows = await _dao.getItems(listId);
    for (final row in rows.where((element) => !element.isChecked)) {
      await _enqueueUpsert(_toModel(row));
    }
  }

  ShoppingItem _toModel(ShoppingItemsTableData row) {
    return ShoppingItem(
      id: row.id,
      listId: row.listId,
      name: row.name,
      quantity: row.quantity,
      isChecked: row.isChecked,
      checkedAt: row.checkedAt,
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
      checkedAt: drift.Value(item.checkedAt),
      isDeleted: drift.Value(item.isDeleted),
      deletedAt: drift.Value(item.deletedAt),
      sortOrder: drift.Value(item.sortOrder),
      createdAt: item.createdAt,
      updatedAt: drift.Value(item.updatedAt ?? item.createdAt),
    );
  }

  Future<void> _enqueueUpsert(ShoppingItem item) {
    return _outboxDao.enqueue(
      SyncOutboxTableCompanion.insert(
        entityType: 'item',
        operation: 'upsert',
        ownerId: '',
        listId: drift.Value(item.listId),
        entityId: item.id,
        payload: jsonEncode(
          {
            'id': item.id,
            'listId': item.listId,
            'name': item.name,
            'quantity': item.quantity,
            'isChecked': item.isChecked,
            'checkedAt': item.checkedAt?.millisecondsSinceEpoch,
            'isDeleted': item.isDeleted,
            'sortOrder': item.sortOrder,
            'createdAt': item.createdAt.millisecondsSinceEpoch,
            'updatedAt':
                (item.updatedAt ?? item.createdAt).millisecondsSinceEpoch,
            'deletedAt': item.deletedAt?.millisecondsSinceEpoch,
          },
        ),
        createdAt: _now(),
      ),
    );
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingItemsRepository shoppingItemsRepository(Ref ref) {
  final dao = ref.watch(shoppingItemsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  return DriftShoppingItemsRepository(dao, outboxDao);
}
