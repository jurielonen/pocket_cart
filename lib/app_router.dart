import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/lists/presentation/home_screen.dart';
import 'features/lists/presentation/list_detail_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

final GoRouter _router = GoRouter(
  routes: $appRoutes,
  refreshListenable: _AuthRefreshNotifier(FirebaseAuth.instance.authStateChanges()),
  redirect: (BuildContext context, GoRouterState state) {
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    final location = state.matchedLocation;
    const authPaths = <String>{
      SignInRoute.path,
      SignUpRoute.path,
      ResetPasswordRoute.path,
    };
    final isAuthRoute = authPaths.contains(location);

    if (!isSignedIn && !isAuthRoute) {
      return SignInRoute.path;
    }

    if (isSignedIn && isAuthRoute) {
      return HomeRoute.path;
    }

    return null;
  },
);

GoRouter get router => _router;

@TypedGoRoute<HomeRoute>(
  path: HomeRoute.path,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<ListDetailRoute>(path: ListDetailRoute.path),
    TypedGoRoute<SettingsRoute>(path: SettingsRoute.path),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();
  static const String path = '/';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const HomeScreen();
}

class ListDetailRoute extends GoRouteData with $ListDetailRoute {
  const ListDetailRoute(this.listId);
  static const String path = 'lists/:listId';

  final String listId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ListDetailScreen(listId: listId);
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  static const String path = 'settings';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

@TypedGoRoute<SignInRoute>(path: SignInRoute.path)
class SignInRoute extends GoRouteData with $SignInRoute {
  const SignInRoute();
  static const String path = '/sign-in';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignInScreen();
}

@TypedGoRoute<SignUpRoute>(path: SignUpRoute.path)
class SignUpRoute extends GoRouteData with $SignUpRoute {
  const SignUpRoute();
  static const String path = '/sign-up';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignUpScreen();
}

@TypedGoRoute<ResetPasswordRoute>(path: ResetPasswordRoute.path)
class ResetPasswordRoute extends GoRouteData with $ResetPasswordRoute {
  const ResetPasswordRoute();
  static const String path = '/reset-password';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ResetPasswordScreen();
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<User?> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
