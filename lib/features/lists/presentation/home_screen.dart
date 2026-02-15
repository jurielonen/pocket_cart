import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_router.dart';
import '../../auth/data/firebase_auth_repository.dart';
import '../domain/models/shopping_list.dart';
import 'controllers/list_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Lists'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(
              child: Text('No lists yet. Create your first shopping list.'),
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
        error: (error, _) => Center(child: Text('Failed to load lists: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final name = await _showNameInputDialog(
      context: context,
      title: 'Create List',
      initialValue: '',
      confirmLabel: 'Create',
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
    final countAsync = ref.watch(itemCountProvider(list.id));

    return Card(
      child: ListTile(
        onTap: () => ListDetailRoute(list.id).push(context),
        title: Text(list.name),
        subtitle: Text(
          countAsync.when(
            data: (count) => '$count items',
            loading: () => 'Loading items...',
            error: (error, stackTrace) => 'Unable to count items',
          ),
        ),
        trailing: PopupMenuButton<_ListMenuAction>(
          onSelected: (action) async {
            switch (action) {
              case _ListMenuAction.rename:
                final renamed = await _showNameInputDialog(
                  context: context,
                  title: 'Rename List',
                  initialValue: list.name,
                  confirmLabel: 'Save',
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
                    content: Text('Deleted "${list.name}"'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => ref
                          .read(homeListsControllerProvider)
                          .restoreList(list.id),
                    ),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ListMenuAction.rename,
              child: Text('Rename'),
            ),
            PopupMenuItem(
              value: _ListMenuAction.delete,
              child: Text('Delete'),
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
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Name is required';
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
            child: const Text('Cancel'),
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
