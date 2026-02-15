import 'package:flutter/material.dart';

import '../../../core/extensions/build_context_l10n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: Center(
        child: Text(l10n.settingsPlaceholder),
      ),
    );
  }
}
