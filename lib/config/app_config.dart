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
  static const Color primaryColor = Color(0xFF00F0FF);
  static const Color accentColor = Color(0xFF00F0FF);
  static const Color textColor = Color(0xFFE2E8F0);
  static const Color mutedTextColor = Color(0xFF94A3B8);
  static const Color backgroundColor = Color(0xFF070B12);
  static const Color cardColor = Color(0xFF0F172A);
  static const Color alertColor = Color(0xFFFF2A6D);

  // Poll Intervals
  static const Duration ntfyPollInterval = Duration(seconds: 3);
  static const Duration alertResetDuration = Duration(seconds: 10);
  static const Duration streamLoadTimeout = Duration(seconds: 10);
}
