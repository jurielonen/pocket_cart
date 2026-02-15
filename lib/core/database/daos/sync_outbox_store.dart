class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.listId,
    required this.opType,
    required this.payloadJson,
    required this.updatedAtMillis,
    required this.attemptCount,
    required this.lastError,
    required this.createdAtMillis,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String? listId;
  final String opType;
  final String payloadJson;
  final int updatedAtMillis;
  final int attemptCount;
  final String? lastError;
  final int createdAtMillis;
}

abstract class SyncOutboxStore {
  Stream<List<SyncOutboxEntry>> watchPending({int limit = 200});

  Future<List<SyncOutboxEntry>> getPending({int limit = 200});

  Future<void> markDone(String id);

  Future<void> markFailed(String id, String error);
}
