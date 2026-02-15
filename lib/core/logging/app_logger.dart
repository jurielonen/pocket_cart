import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_logger.g.dart';

@Riverpod(keepAlive: true)
Logger appLogger(Ref ref) {
  return Logger(
    printer: PrettyPrinter(methodCount: 0),
  );
}
