import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String esp32IpKey = 'esp32_ip';
  static const String esp32SsidKey = 'esp32_ssid';
  static const String esp32PasswordKey = 'esp32_password';
  static const String esp32TopicKey = 'esp32_topic';
  static const String webhookEnabledKey = 'webhook_enabled';
  static const String webhookPortKey = 'webhook_port';

  Future<void> saveEsp32Ip(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32IpKey, ip);
  }

  Future<String> loadEsp32Ip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32IpKey) ?? '192.168.1.100';
  }

  Future<void> saveEsp32Ssid(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32SsidKey, ssid);
  }

  Future<String> loadEsp32Ssid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32SsidKey) ?? '';
  }

  Future<void> saveEsp32Password(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32PasswordKey, password);
  }

  Future<String> loadEsp32Password() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32PasswordKey) ?? '';
  }

  Future<void> saveEsp32Topic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32TopicKey, topic);
  }

  Future<String> loadEsp32Topic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32TopicKey) ?? '';
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
