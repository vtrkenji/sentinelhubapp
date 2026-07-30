import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rf_device.dart';

class SettingsService {
  static const String esp32IpKey = 'esp32_ip';
  static const String webhookEnabledKey = 'webhook_enabled';
  static const String webhookPortKey = 'webhook_port';
  static const String ntfyEnabledKey = 'ntfy_enabled';
  static const String ntfyTopicUrlKey = 'ntfy_topic_url';
  static const String rfDevicesKey = 'rf_devices';

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

  Future<void> saveNtfyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ntfyEnabledKey, enabled);
  }

  Future<bool> loadNtfyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(ntfyEnabledKey) ?? false;
  }

  Future<void> saveNtfyTopicUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ntfyTopicUrlKey, url);
  }

  Future<String> loadNtfyTopicUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ntfyTopicUrlKey) ?? '';
  }

  Future<void> saveRfDevices(List<RFDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(devices.map((d) => d.toJson()).toList());
    await prefs.setString(rfDevicesKey, jsonString);
  }

  Future<List<RFDevice>> loadRfDevices() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(rfDevicesKey);
    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => RFDevice.fromJson(json)).toList();
    }
    return [];
  }
}
