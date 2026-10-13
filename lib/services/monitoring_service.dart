import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'ntfy_native_service.dart';
import 'settings_service.dart';

/// Liga/desliga o listener de campainha (ntfy) do app. Os alertas via FCM não dependem disso.
class MonitoringService {
  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<bool> isEnabled() => SettingsService().loadBackgroundAtivo();

  static Future<void> setEnabled(bool enabled) async {
    await SettingsService().saveBackgroundAtivo(enabled);
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
    NtfyNativeService.instance.stop();
    if (enabled) {
      await NtfyNativeService.instance.start();
    }
  }
}
