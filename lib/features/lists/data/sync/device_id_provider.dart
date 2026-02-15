import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_id_provider.g.dart';

final String _generatedDeviceId =
    'device_${DateTime.now().toUtc().millisecondsSinceEpoch}';

@Riverpod(keepAlive: true)
String syncDeviceId(Ref ref) {
  return _generatedDeviceId;
}
