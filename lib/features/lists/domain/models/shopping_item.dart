import 'package:freezed_annotation/freezed_annotation.dart';

part 'shopping_item.freezed.dart';
part 'shopping_item.g.dart';

@freezed
abstract class ShoppingItem with _$ShoppingItem {
  const factory ShoppingItem({
    required String id,
    required String listId,
    @Default('') String ownerId,
    required String name,
    double? quantity,
    String? unit,
    String? category,
    String? note,
    @Default(false) bool isChecked,
    DateTime? checkedAt,
    @Default(false) bool isDeleted,
    DateTime? deletedAt,
    @Default(0) int sortOrder,
    @Default(0) int revision,
    String? deviceId,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _ShoppingItem;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) =>
      _$ShoppingItemFromJson(json);
}
