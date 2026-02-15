import 'package:flutter/material.dart';

import '../app_router.dart';

class PocketCartApp extends StatelessWidget {
  const PocketCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pocket Cart',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
