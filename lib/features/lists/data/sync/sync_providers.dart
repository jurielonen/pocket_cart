import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_provider.dart';
import '../../../auth/data/firebase_auth_repository.dart';
import '../drift_shopping_items_repository.dart';
import '../drift_shopping_lists_repository.dart';
import 'device_id_provider.dart';
import 'firestore_sync_engine.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseFirestore firebaseFirestore(Ref ref) {
  return FirebaseFirestore.instance;
}

@riverpod
Future<SharedPreferences> sharedPreferences(Ref ref) {
  return SharedPreferences.getInstance();
}

@Riverpod(keepAlive: true)
Future<FirestoreSyncEngine> firestoreSyncEngine(Ref ref) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final deviceId = ref.watch(syncDeviceIdProvider);
  final shoppingListsRepository = ref.watch(shoppingListsRepositoryProvider);
  final shoppingItemsRepository = ref.watch(shoppingItemsRepositoryProvider);
  final outbox = ref.watch(syncOutboxDaoProvider);
  final preferences = await ref.watch(sharedPreferencesProvider.future);

  final engine = FirestoreSyncEngine(
    firestore: firestore,
    preferences: preferences,
    shoppingListsRepository: shoppingListsRepository,
    shoppingItemsRepository: shoppingItemsRepository,
    outbox: outbox,
    deviceId: deviceId,
  );

  ref.onDispose(engine.dispose);
  return engine;
}

@Riverpod(keepAlive: true)
class SyncLifecycle extends _$SyncLifecycle {
  @override
  void build() {
    ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
      unawaited(_handleAuthState(next));
    });

    final current = ref.read(authStateChangesProvider);
    unawaited(_handleAuthState(current));
  }

  Future<void> _handleAuthState(AsyncValue<User?> authValue) async {
    final user = authValue.asData?.value;
    final engine = await ref.read(firestoreSyncEngineProvider.future);

    if (user == null) {
      await engine.stop();
      return;
    }

    await engine.start(user.uid);
  }
}
