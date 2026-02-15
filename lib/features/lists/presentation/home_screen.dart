import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_router.dart';
import '../../auth/data/firebase_auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: const Center(
        child: _HomeActions(),
      ),
    );
  }
}

class _HomeActions extends StatelessWidget {
  const _HomeActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Home placeholder (authenticated).'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => const ListDetailRoute('demo-list').push(context),
          child: const Text('Open list detail'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => const SettingsRoute().push(context),
          child: const Text('Settings'),
        ),
      ],
    );
  }
}
