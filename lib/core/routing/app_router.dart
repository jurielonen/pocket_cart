import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/lists/presentation/home_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    redirect: (context, state) {
      if (authState.isLoading) {
        return null;
      }

      final isSignedIn = authState.asData?.value != null;
      final path = state.matchedLocation;
      const authPaths = {'/signin', '/signup', '/reset-password'};
      final isAuthPath = authPaths.contains(path);

      if (!isSignedIn && !isAuthPath) {
        return '/signin';
      }

      if (isSignedIn && isAuthPath) {
        return '/home';
      }

      if (path == '/') {
        return isSignedIn ? '/home' : '/signin';
      }

      return null;
    },
  );
}
