import 'package:freezed_annotation/freezed_annotation.dart';

import 'firestore_timestamp_converters.dart';

part 'shopping_list.freezed.dart';
part 'shopping_list.g.dart';

@freezed
abstract class ShoppingList with _$ShoppingList {
  const factory ShoppingList({
    required String id,
    required String ownerId,
    required String name,
    int? color,
    String? icon,
    @Default('manual') String sortMode,
    @Default(false) bool isArchived,
    @Default(false) bool isDeleted,
    @NullableFirestoreDateTimeConverter() DateTime? deletedAt,
    @Default(0) int sortOrder,
    @Default(0) int revision,
    String? deviceId,
    @FirestoreDateTimeConverter() required DateTime createdAt,
    @NullableFirestoreDateTimeConverter() DateTime? updatedAt,
  }) = _ShoppingList;

  factory ShoppingList.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListFromJson(json);
}
