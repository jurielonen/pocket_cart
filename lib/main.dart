import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/logging/app_logger.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final container = ProviderContainer();
  final logger = container.read(appLoggerProvider);
  logger.i('Pocket Cart app initialized.');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PocketCartApp(),
    ),
  );
}
