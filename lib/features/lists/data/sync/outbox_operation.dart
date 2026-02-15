enum OutboxEntityType {
  list,
  item,
}

enum OutboxOpType {
  upsert,
  tombstone,
  restore,
}
