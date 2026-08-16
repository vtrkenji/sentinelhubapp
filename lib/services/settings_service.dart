import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String esp32IpKey = 'esp32_ip';
  static const String esp32SsidKey = 'esp32_ssid';
  static const String esp32PasswordKey = 'esp32_password';
  static const String esp32TopicKey = 'esp32_topic';
  static const String esp32DuckDomKey = 'esp32_duckdom';
  static const String esp32DuckTokKey = 'esp32_ducktok';
  static const String esp32Camp1Key = 'esp32_camp1';
  static const String esp32Camp2Key = 'esp32_camp2';
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

  Future<void> saveEsp32DuckDom(String duckdom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32DuckDomKey, duckdom);
  }

  Future<String> loadEsp32DuckDom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32DuckDomKey) ?? '';
  }

  Future<void> saveEsp32DuckTok(String ducktok) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32DuckTokKey, ducktok);
  }

  Future<String> loadEsp32DuckTok() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32DuckTokKey) ?? '';
  }

  Future<void> saveEsp32Camp1(String camp1) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32Camp1Key, camp1);
  }

  Future<String> loadEsp32Camp1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32Camp1Key) ?? '130805';
  }

  Future<void> saveEsp32Camp2(String camp2) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32Camp2Key, camp2);
  }

  Future<String> loadEsp32Camp2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32Camp2Key) ?? '4827093';
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
