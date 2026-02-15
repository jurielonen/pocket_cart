import 'package:freezed_annotation/freezed_annotation.dart';

part 'shopping_list.freezed.dart';
part 'shopping_list.g.dart';

@freezed
abstract class ShoppingList with _$ShoppingList {
  const factory ShoppingList({
    required String id,
    required String ownerId,
    required String name,
    @Default(false) bool isArchived,
    @Default(0) int sortOrder,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _ShoppingList;

  factory ShoppingList.fromJson(Map<String, dynamic> json) =>
      _$ShoppingListFromJson(json);
}
