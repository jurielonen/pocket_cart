import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/build_context_l10n.dart';
import '../domain/models/shopping_item.dart';
import 'controllers/list_providers.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final raw = _textController.text;
    if (raw.trim().isEmpty) {
      return;
    }

    await ref.read(listDetailControllerProvider).addItem(
          listId: widget.listId,
          rawName: raw,
        );

    if (!mounted) {
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itemsAsync = ref.watch(itemStreamProvider(widget.listId));
    final listAsync = ref.watch(listByIdStreamProvider(widget.listId));

    return Scaffold(
      appBar: AppBar(
        title: listAsync.when(
          data: (list) => Text(list?.name ?? l10n.listsDetailFallbackTitle),
          loading: () => Text(l10n.listsDetailFallbackTitle),
          error: (error, stackTrace) => Text(l10n.listsDetailFallbackTitle),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                final unchecked = items.where((item) => !item.isChecked).toList();
                final checked = items.where((item) => item.isChecked).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Text(l10n.listsNoItemsYet),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (unchecked.isNotEmpty)
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unchecked.length,
                        proxyDecorator: (child, animation, dragInfo) => Material(
                          elevation: 4,
                          child: child,
                        ),
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final reordered = [...unchecked];
                          final moved = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, moved);

                          await ref.read(listDetailControllerProvider).reorderUnchecked(
                                listId: widget.listId,
                                orderedUncheckedIds: reordered
                                    .map((item) => item.id)
                                    .toList(growable: false),
                              );
                        },
                        itemBuilder: (context, index) {
                          final item = unchecked[index];
                          return _ItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            onChanged: (checked) => ref
                                .read(listDetailControllerProvider)
                                .setChecked(id: item.id, isChecked: checked),
                            onDelete: () => _deleteWithUndo(item),
                          );
                        },
                      ),
                    if (checked.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          l10n.listsCheckedSection,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    for (final item in checked)
                      _ItemTile(
                        key: ValueKey(item.id),
                        item: item,
                        onChanged: (checked) => ref
                            .read(listDetailControllerProvider)
                            .setChecked(id: item.id, isChecked: checked),
                        onDelete: () => _deleteWithUndo(item),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(l10n.listsFailedToLoadItems(error.toString())),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: l10n.listsAddItemHint,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addItem,
                    child: Text(l10n.commonAdd),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWithUndo(ShoppingItem item) async {
    final l10n = context.l10n;
    await ref.read(listDetailControllerProvider).deleteItem(item.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.listsDeletedItem(item.name)),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () =>
              ref.read(listDetailControllerProvider).restoreItem(item.id),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        key: ValueKey('tile_${item.id}'),
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (value) => onChanged(value ?? false),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
