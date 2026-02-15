import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/shopping_lists_dao.dart';
import '../../../core/database/daos/sync_outbox_dao.dart';
import '../../../core/database/database_provider.dart';
import '../domain/models/shopping_list.dart';
import '../domain/repositories/shopping_lists_repository.dart';
import '../domain/write_origin.dart';
import 'sync/outbox_operation.dart';
import 'sync/device_id_provider.dart';

part 'drift_shopping_lists_repository.g.dart';

class DriftShoppingListsRepository implements ShoppingListsRepository {
  DriftShoppingListsRepository(this._dao, this._outboxDao, this._deviceId);

  final ShoppingListsDao _dao;
  final SyncOutboxDao _outboxDao;
  final String _deviceId;

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
  Future<void> create(ShoppingList list, {WriteOrigin origin = WriteOrigin.localUser}) async {
    if (origin == WriteOrigin.remoteSync) {
      await _upsertInternal(list, origin: origin, opType: OutboxOpType.upsert);
      return;
    }

    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
      revision: list.revision + 1,
      deviceId: _deviceId,
    );
    await _upsertInternal(writeModel, origin: origin, opType: OutboxOpType.upsert);
  }

  @override
  Future<void> update(ShoppingList list, {WriteOrigin origin = WriteOrigin.localUser}) async {
    if (origin == WriteOrigin.remoteSync) {
      await _upsertInternal(list, origin: origin, opType: OutboxOpType.upsert);
      return;
    }

    final now = _now();
    final writeModel = list.copyWith(
      updatedAt: now,
      revision: list.revision + 1,
      deviceId: _deviceId,
    );
    await _upsertInternal(writeModel, origin: origin, opType: OutboxOpType.upsert);
  }

  @override
  Future<void> tombstoneById(String id, {WriteOrigin origin = WriteOrigin.localUser}) async {
    final existing = await _dao.getListById(id);
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
    final existing = await _dao.getListById(id);
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
  Future<void> reorder({required String ownerId, required List<String> orderedIds}) async {
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
        revision: row.revision + 1,
        deviceId: _deviceId,
      );
      await _upsertInternal(updated, origin: WriteOrigin.localUser, opType: OutboxOpType.upsert);
    }
  }

  Future<void> _upsertInternal(
    ShoppingList list, {
    required WriteOrigin origin,
    required OutboxOpType opType,
  }) {
    return _dao.attachedDatabase.transaction(() async {
      await _dao.upsertList(_toCompanion(list));
      if (origin == WriteOrigin.localUser) {
        await _enqueue(list: list, opType: opType);
      }
    });
  }

  Future<void> _enqueue({required ShoppingList list, required OutboxOpType opType}) {
    final millis = (list.updatedAt ?? list.createdAt).millisecondsSinceEpoch;
    return _outboxDao.enqueue(
      id: _outboxId('list', list.id, millis),
      entityType: OutboxEntityType.list,
      entityId: list.id,
      opType: opType,
      payloadJson: jsonEncode(_toRemoteMap(list)),
      updatedAtMillis: millis,
      createdAtMillis: _now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> _toRemoteMap(ShoppingList list) {
    return {
      'id': list.id,
      'ownerId': list.ownerId,
      'name': list.name,
      'color': list.color,
      'icon': list.icon,
      'sortMode': list.sortMode,
      'isArchived': list.isArchived,
      'isDeleted': list.isDeleted,
      'createdAt': list.createdAt.millisecondsSinceEpoch,
      'updatedAt': (list.updatedAt ?? list.createdAt).millisecondsSinceEpoch,
      'deletedAt': list.deletedAt?.millisecondsSinceEpoch,
      'revision': list.revision,
      'deviceId': list.deviceId,
      'sortOrder': list.sortOrder,
    };
  }

  ShoppingList _toModel(ShoppingListsTableData row) {
    return ShoppingList(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      color: row.color,
      icon: row.icon,
      sortMode: row.sortMode,
      isArchived: row.isArchived,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      sortOrder: row.sortOrder,
      revision: row.revision,
      deviceId: row.deviceId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ShoppingListsTableCompanion _toCompanion(ShoppingList list) {
    return ShoppingListsTableCompanion.insert(
      id: list.id,
      ownerId: list.ownerId,
      name: list.name,
      color: drift.Value(list.color),
      icon: drift.Value(list.icon),
      sortMode: drift.Value(list.sortMode),
      isArchived: drift.Value(list.isArchived),
      isDeleted: drift.Value(list.isDeleted),
      deletedAt: drift.Value(list.deletedAt),
      sortOrder: drift.Value(list.sortOrder),
      revision: drift.Value(list.revision),
      deviceId: drift.Value(list.deviceId),
      createdAt: list.createdAt,
      updatedAt: drift.Value(list.updatedAt ?? list.createdAt),
    );
  }

  String _outboxId(String entityType, String entityId, int millis) {
    return '$entityType:$entityId:$millis';
  }

  DateTime _now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
ShoppingListsRepository shoppingListsRepository(Ref ref) {
  final dao = ref.watch(shoppingListsDaoProvider);
  final outboxDao = ref.watch(syncOutboxDaoProvider);
  final deviceId = ref.watch(syncDeviceIdProvider);
  return DriftShoppingListsRepository(dao, outboxDao, deviceId);
}
