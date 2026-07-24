import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String esp32IpKey = 'esp32_ip';

  Future<void> saveEsp32Ip(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(esp32IpKey, ip);
  }

  Future<String> loadEsp32Ip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(esp32IpKey) ?? '192.168.1.100'; // Default IP
  }
}
