import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_items_dao.dart';
import '../../../core/database/daos/sync_outbox_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_item.dart';
import '../domain/repositories/shopping_items_repository.dart';
import '../domain/write_origin.dart';
import 'sync/outbox_operation.dart';
import 'sync/device_id_provider.dart';

part 'drift_shopping_items_repository.g.dart';

class DriftShoppingItemsRepository implements ShoppingItemsRepository {
  DriftShoppingItemsRepository(this._dao, this._outboxDao, this._deviceId);

  final ShoppingItemsDao _dao;
  final SyncOutboxDao _outboxDao;
  final String _deviceId;

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
  Future<void> create(ShoppingItem item, {WriteOrigin origin = WriteOrigin.localUser}) async {
    if (origin == WriteOrigin.remoteSync) {
      await _upsertInternal(item, origin: origin, opType: OutboxOpType.upsert);
      return;
    }

    final now = _now();
    final nextSortOrder = await _dao.getNextSortOrder(item.listId);
    final writeModel = item.copyWith(
      sortOrder: nextSortOrder,
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
      checkedAt: item.isChecked ? (item.checkedAt ?? now) : null,
      revision: item.revision + 1,
      deviceId: _deviceId,
    );
    await _upsertInternal(writeModel, origin: origin, opType: OutboxOpType.upsert);
  }

  @override
  Future<void> update(ShoppingItem item, {WriteOrigin origin = WriteOrigin.localUser}) async {
    if (origin == WriteOrigin.remoteSync) {
      await _upsertInternal(item, origin: origin, opType: OutboxOpType.upsert);
      return;
    }

    final now = _now();
    final writeModel = item.copyWith(
      updatedAt: now,
      checkedAt: item.isChecked ? (item.checkedAt ?? now) : null,
      revision: item.revision + 1,
      deviceId: _deviceId,
    );
    await _upsertInternal(writeModel, origin: origin, opType: OutboxOpType.upsert);
  }

  @override
  Future<void> setChecked({required String id, required bool isChecked, WriteOrigin origin = WriteOrigin.localUser}) async {
    final existing = await _dao.getItemById(id);
    if (existing == null) {
      return;
    }

    final now = _now();
    final updated = _toModel(existing).copyWith(
          isChecked: isChecked,
          checkedAt: isChecked ? now : null,
          updatedAt: now,
          revision: existing.revision + 1,
          deviceId: _deviceId,
        );
    await _upsertInternal(updated, origin: origin, opType: OutboxOpType.upsert);
  }

  @override
  Future<void> tombstoneById(String id, {WriteOrigin origin = WriteOrigin.localUser}) async {
    final existing = await _dao.getItemById(id);
    if (existing == null || existing.isDeleted) {
      return;
    }

    final now = _now();
    final tombstoned = _toModel(existing).copyWith(
          isDeleted: true,
          deletedAt: now,
          updatedAt: now,
          revision: existing.revision + 1,
          deviceId: _deviceId,
        );
    await _upsertInternal(tombstoned, origin: origin, opType: OutboxOpType.tombstone);
  }

  @override
  Future<void> restoreById(String id, {WriteOrigin origin = WriteOrigin.localUser}) async {
    final existing = await _dao.getItemById(id);
    if (existing == null || !existing.isDeleted) {
      return;
    }

    final now = _now();
    final restored = _toModel(existing).copyWith(
          isDeleted: false,
          deletedAt: null,
          updatedAt: now,
          revision: existing.revision + 1,
          deviceId: _deviceId,
        );
    await _upsertInternal(restored, origin: origin, opType: OutboxOpType.restore);
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
      final updated = _toModel(row).copyWith(
        revision: row.revision + 1,
        deviceId: _deviceId,
      );
      await _upsertInternal(updated, origin: WriteOrigin.localUser, opType: OutboxOpType.upsert);
    }
  }

  Future<void> _upsertInternal(
    ShoppingItem item, {
    required WriteOrigin origin,
    required OutboxOpType opType,
  }) {
    return _dao.attachedDatabase.transaction(() async {
      await _dao.upsertItem(_toCompanion(item));
      if (origin == WriteOrigin.localUser) {
        await _enqueue(item: item, opType: opType);
      }
    });
  }

  Future<void> _enqueue({required ShoppingItem item, required OutboxOpType opType}) {
    final millis = (item.updatedAt ?? item.createdAt).millisecondsSinceEpoch;
    return _outboxDao.enqueue(
      id: _outboxId('item', item.id, millis),
      entityType: OutboxEntityType.item,
      entityId: item.id,
      listId: item.listId,
      opType: opType,
      payloadJson: jsonEncode(_toRemoteMap(item)),
      updatedAtMillis: millis,
      createdAtMillis: _now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> _toRemoteMap(ShoppingItem item) {
    return {
      'id': item.id,
      'listId': item.listId,
      'ownerId': item.ownerId,
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'category': item.category,
      'note': item.note,
      'isChecked': item.isChecked,
      'checkedAt': item.checkedAt?.millisecondsSinceEpoch,
      'sortOrder': item.sortOrder,
      'isDeleted': item.isDeleted,
      'createdAt': item.createdAt.millisecondsSinceEpoch,
      'updatedAt': (item.updatedAt ?? item.createdAt).millisecondsSinceEpoch,
      'deletedAt': item.deletedAt?.millisecondsSinceEpoch,
      'revision': item.revision,
      'deviceId': item.deviceId,
    };
  }

  ShoppingItem _toModel(ShoppingItemsTableData row) {
    return ShoppingItem(
      id: row.id,
      listId: row.listId,
      ownerId: row.ownerId,
      name: row.name,
      quantity: row.quantity,
      unit: row.unit,
      category: row.category,
      note: row.note,
      isChecked: row.isChecked,
      checkedAt: row.checkedAt,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      sortOrder: row.sortOrder,
      revision: row.revision,
      deviceId: row.deviceId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingItemsTableCompanion _toCompanion(ShoppingItem item) {
    return ShoppingItemsTableCompanion.insert(
      id: item.id,
      listId: item.listId,
      ownerId: drift.Value(item.ownerId),
      name: item.name,
      quantity: drift.Value(item.quantity),
      unit: drift.Value(item.unit),
      category: drift.Value(item.category),
      note: drift.Value(item.note),
      isChecked: drift.Value(item.isChecked),
      checkedAt: drift.Value(item.checkedAt),
      isDeleted: drift.Value(item.isDeleted),
      deletedAt: drift.Value(item.deletedAt),
      sortOrder: drift.Value(item.sortOrder),
      revision: drift.Value(item.revision),
      deviceId: drift.Value(item.deviceId),
      createdAt: item.createdAt,
      updatedAt: drift.Value(item.updatedAt ?? item.createdAt),
    );
  }

  String _outboxId(String entityType, String entityId, int millis) {
    return '$entityType:$entityId:$millis';
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingItemsRepository shoppingItemsRepository(Ref ref) {
  final dao = ref.watch(shoppingItemsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  final deviceId = ref.watch(syncDeviceIdProvider);
  return DriftShoppingItemsRepository(dao, outboxDao, deviceId);
}
