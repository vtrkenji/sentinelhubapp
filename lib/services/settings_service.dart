import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String esp32IpKey = 'esp32_ip';
  static const String webhookEnabledKey = 'webhook_enabled';
  static const String webhookPortKey = 'webhook_port';

  Future<void> saveEsp32Ip(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32IpKey, ip);
  }

  Future<String> loadEsp32Ip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32IpKey) ?? '192.168.1.100'; // Default IP
  }

  Future<void> saveWebhookEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(webhookEnabledKey, enabled);
  }

  Future<bool> loadWebhookEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(webhookEnabledKey) ?? false;
  }

  Future<void> saveWebhookPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(webhookPortKey, port);
  }

  Future<int> loadWebhookPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(webhookPortKey) ?? 8080;
  }
}
