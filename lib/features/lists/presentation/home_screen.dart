import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_router.dart';
import '../../../core/extensions/build_context_l10n.dart';
import '../../auth/data/firebase_auth_repository.dart';
import '../domain/models/shopping_list.dart';
import 'controllers/list_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listsAsync = ref.watch(listStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.listsTitle),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: l10n.commonSignOut,
          ),
        ],
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Text(l10n.listsEmptyState),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: lists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final list = lists[index];
              return _ListCard(list: list);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text(l10n.listsFailedToLoad(error.toString()))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.listsNewList),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await _showNameInputDialog(
      context: context,
      title: l10n.listsCreateListTitle,
      initialValue: '',
      confirmLabel: l10n.commonCreate,
    );
    if (name == null) {
      return;
    }

    await ref.read(homeListsControllerProvider).createList(name);
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final countAsync = ref.watch(itemCountProvider(list.id));

    return Card(
      child: ListTile(
        onTap: () => ListDetailRoute(list.id).push(context),
        title: Text(list.name),
        subtitle: Text(
          countAsync.when(
            data: (count) => l10n.listsItemCount(count),
            loading: () => l10n.listsItemCountLoading,
            error: (error, stackTrace) => l10n.listsItemCountError,
          ),
        ),
        trailing: PopupMenuButton<_ListMenuAction>(
          onSelected: (action) async {
            switch (action) {
              case _ListMenuAction.rename:
                final renamed = await _showNameInputDialog(
                  context: context,
                  title: l10n.listsRenameListTitle(list.name),
                  initialValue: list.name,
                  confirmLabel: l10n.commonSave,
                );
                if (renamed != null) {
                  await ref
                      .read(homeListsControllerProvider)
                      .renameList(id: list.id, rawName: renamed);
                }
                break;
              case _ListMenuAction.delete:
                await ref.read(homeListsControllerProvider).deleteList(list.id);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.listsDeletedList(list.name)),
                    action: SnackBarAction(
                      label: l10n.commonUndo,
                      onPressed: () => ref
                          .read(homeListsControllerProvider)
                          .restoreList(list.id),
                    ),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ListMenuAction.rename,
              child: Text(l10n.commonRename),
            ),
            PopupMenuItem(
              value: _ListMenuAction.delete,
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ListMenuAction { rename, delete }

Future<String?> _showNameInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirmLabel,
}) async {
  final l10n = context.l10n;
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.commonName),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return l10n.listsNameRequired;
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
