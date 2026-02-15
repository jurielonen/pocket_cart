import 'package:freezed_annotation/freezed_annotation.dart';

part 'shopping_item.freezed.dart';
part 'shopping_item.g.dart';

@freezed
abstract class ShoppingItem with _$ShoppingItem {
  const factory ShoppingItem({
    required String id,
    required String listId,
    required String name,
    @Default(1) int quantity,
    @Default(false) bool isChecked,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _ShoppingItem;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) =>
      _$ShoppingItemFromJson(json);
}
