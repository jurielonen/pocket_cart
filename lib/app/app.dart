import 'package:flutter/material.dart';

import '../app_router.dart';
import '../core/extensions/build_context_l10n.dart';
import '../l10n/app_localizations.dart';

class PocketCartApp extends StatelessWidget {
  const PocketCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MaterialApp.router(
      title: l10n.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
