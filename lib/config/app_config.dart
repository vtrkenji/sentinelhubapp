import 'package:flutter/material.dart';

// Configurações do DVR AITEK
class AppConfig {
  // DVR Credentials
  static const String dvrUsername = 'vtr';
  static const String dvrPassword = 'vitor6721';
  static const String dvrHost = 'sentinelhub.ddns.net:554';

  // Câmera IP
  static const String cameraIpUsername = 'admin';
  static const String cameraIpPassword = 'admin123456';
  static const String cameraIpHost = '192.168.15.19:8554';

  // ntfy.sh
  static const String ntfyTopic = 'sentinel_hub_vitor';
  static const String ntfyBaseUrl = 'https://ntfy.sh';

  // UI
  static const Color primaryColor = Color(0xFFE5B14D);
  static const Color accentColor = Color(0xFFE5B14D);
  static const Color textColor = Color(0xFFE7EDF2);
  static const Color mutedTextColor = Color(0xFF8897A6);
  static const Color backgroundColor = Color(0xFF070C12);
  static const Color cardColor = Color(0xFF101A22);
  static const Color alertColor = Color(0xFFE66C6C);

  // Poll Intervals
  static const Duration ntfyPollInterval = Duration(seconds: 3);
  static const Duration alertResetDuration = Duration(seconds: 10);
  static const Duration streamLoadTimeout = Duration(seconds: 10);
}
