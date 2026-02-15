import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/drift_shopping_items_repository.dart';
import '../../data/drift_shopping_lists_repository.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/models/shopping_list.dart';

part 'list_providers.g.dart';

@riverpod
String currentUserId(Ref ref) {
  return FirebaseAuth.instance.currentUser?.uid ?? 'local-dev-user';
}

@riverpod
Stream<List<ShoppingList>> listStream(Ref ref) {
  final ownerId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(shoppingListsRepositoryProvider);
  return repository.watchListsForOwner(ownerId);
}

@riverpod
Stream<List<ShoppingItem>> itemStream(Ref ref, String listId) {
  final repository = ref.watch(shoppingItemsRepositoryProvider);
  return repository.watchItemsForList(listId);
}

@riverpod
Stream<int> itemCount(Ref ref, String listId) {
  final repository = ref.watch(shoppingItemsRepositoryProvider);
  return repository.watchActiveItemCount(listId);
}

@riverpod
Stream<ShoppingList?> listByIdStream(Ref ref, String listId) {
  final ownerId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(shoppingListsRepositoryProvider);
  return repository.watchListsForOwner(ownerId).map((lists) {
    for (final list in lists) {
      if (list.id == listId) {
        return list;
      }
    }
    return null;
  });
}

@riverpod
HomeListsController homeListsController(Ref ref) {
  return HomeListsController(ref);
}

class HomeListsController {
  HomeListsController(this._ref);

  final Ref _ref;

  Future<void> createList(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = _ref.read(shoppingListsRepositoryProvider);
    final ownerId = _ref.read(currentUserIdProvider);
    final now = DateTime.now().toUtc();
    final id = 'list_${now.microsecondsSinceEpoch}';

    await repository.create(
      ShoppingList(
        id: id,
        ownerId: ownerId,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> renameList({required String id, required String rawName}) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = _ref.read(shoppingListsRepositoryProvider);
    final existing = await repository.getById(id);
    if (existing == null) {
      return;
    }

    await repository.update(existing.copyWith(name: name));
  }

  Future<void> deleteList(String id) async {
    final repository = _ref.read(shoppingListsRepositoryProvider);
    await repository.tombstoneById(id);
  }

  Future<void> restoreList(String id) async {
    final repository = _ref.read(shoppingListsRepositoryProvider);
    await repository.restoreById(id);
  }
}

@riverpod
ListDetailController listDetailController(Ref ref) {
  return ListDetailController(ref);
}

class ListDetailController {
  ListDetailController(this._ref);

  final Ref _ref;

  Future<void> addItem({required String listId, required String rawName}) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = _ref.read(shoppingItemsRepositoryProvider);
    final now = DateTime.now().toUtc();
    final id = 'item_${now.microsecondsSinceEpoch}';

    await repository.create(
      ShoppingItem(
        id: id,
        listId: listId,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> setChecked({required String id, required bool isChecked}) async {
    final repository = _ref.read(shoppingItemsRepositoryProvider);
    await repository.setChecked(id: id, isChecked: isChecked);
  }

  Future<void> deleteItem(String id) async {
    final repository = _ref.read(shoppingItemsRepositoryProvider);
    await repository.tombstoneById(id);
  }

  Future<void> restoreItem(String id) async {
    final repository = _ref.read(shoppingItemsRepositoryProvider);
    await repository.restoreById(id);
  }

  Future<void> reorderUnchecked({
    required String listId,
    required List<String> orderedUncheckedIds,
  }) async {
    final repository = _ref.read(shoppingItemsRepositoryProvider);
    await repository.reorder(
      listId: listId,
      orderedUncheckedIds: orderedUncheckedIds,
    );
  }
}
