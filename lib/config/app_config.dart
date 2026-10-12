import 'package:flutter/material.dart';

// Constantes de UI. Credenciais e endereços ficam nas configurações do app, nunca no código.
class AppConfig {
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
