import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GuardWindow {
  GuardWindow({required this.days, required this.start, required this.end});

  /// 0 = segunda ... 6 = domingo
  Set<int> days;
  String start;
  String end;

  factory GuardWindow.fromJson(Map<String, dynamic> j) => GuardWindow(
        days: (j['days'] as List).map((e) => e as int).toSet(),
        start: j['start'] as String,
        end: j['end'] as String,
      );

  Map<String, dynamic> toJson() => {
        'days': (days.toList()..sort()),
        'start': start,
        'end': end,
      };
}

class GuardStatus {
  GuardStatus(
      {required this.armed, required this.active, required this.cameras});

  /// Armado manualmente (botão).
  final bool armed;

  /// Armado de fato agora (botão + agenda).
  final bool active;
  final int cameras;
}

class GuardException implements Exception {
  GuardException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Controle remoto do kTsentinel Guard (daemon no notebook) via API HTTPS.
class GuardService {
  static const _urlKey = 'guard_url';
  static const _tokenKey = 'guard_token';

  Future<String> loadUrl() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_urlKey) ?? '').trim();
  }

  Future<String> loadToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey) ?? '';
  }

  Future<void> saveConnection(String url, String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_urlKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
    await p.setString(_tokenKey, token.trim());
  }

  Future<Map<String, dynamic>> _call(String method, String path,
      {Object? body}) async {
    final url = await loadUrl();
    final token = await loadToken();
    if (url.isEmpty || token.isEmpty) {
      throw GuardException('Informe o endereço e o token do Guard.');
    }
    final uri = Uri.parse('$url$path');
    final headers = {
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    try {
      late http.Response r;
      switch (method) {
        case 'PUT':
          r = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 10));
          break;
        case 'POST':
          r = await http
              .post(uri, headers: headers)
              .timeout(const Duration(seconds: 10));
          break;
        default:
          r = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 10));
      }
      if (r.statusCode == 401) throw GuardException('Token inválido.');
      if (r.statusCode == 429)
        throw GuardException('Muitas tentativas. Aguarde 5 minutos.');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode != 200 || data['ok'] != true) {
        throw GuardException(
            (data['error'] ?? 'Erro ${r.statusCode}').toString());
      }
      return data['result'] as Map<String, dynamic>;
    } on GuardException {
      rethrow;
    } catch (_) {
      throw GuardException('Não foi possível falar com o Guard.');
    }
  }

  Future<GuardStatus> status() async {
    final r = await _call('GET', '/v1/status');
    return GuardStatus(
      armed: r['armed'] == true,
      active: r['scheduleActive'] == true,
      cameras: (r['cameras'] as List?)?.length ?? 0,
    );
  }

  Future<void> setArmed(bool armed) =>
      _call('POST', armed ? '/v1/arm' : '/v1/disarm');

  Future<({bool enabled, List<GuardWindow> windows})> loadSchedule() async {
    final r = await _call('GET', '/v1/schedule');
    return (
      enabled: r['enabled'] == true,
      windows: (r['windows'] as List)
          .map((e) => GuardWindow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> saveSchedule(bool enabled, List<GuardWindow> windows) =>
      _call('PUT', '/v1/schedule', body: {
        'enabled': enabled,
        'windows': windows.map((w) => w.toJson()).toList(),
      });

  Future<List<Map<String, dynamic>>> events({int limit = 50}) async {
    final url = await loadUrl();
    final token = await loadToken();
    if (url.isEmpty || token.isEmpty) {
      throw GuardException('Informe o endereço e o token do Guard.');
    }
    try {
      final r = await http.get(Uri.parse('$url/v1/events?limit=$limit'),
          headers: {
            'Authorization': 'Bearer $token'
          }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 401) throw GuardException('Token inválido.');
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return (data['result'] as List).cast<Map<String, dynamic>>();
    } on GuardException {
      rethrow;
    } catch (_) {
      throw GuardException('Não foi possível falar com o Guard.');
    }
  }

  Future<Map<String, String>> authHeaders() async =>
      {'Authorization': 'Bearer ${await loadToken()}'};

  Future<String> snapshotUrl(int id) async =>
      '${await loadUrl()}/v1/snapshot?id=$id';

  Future<Map<String, dynamic>> loadSettings() => _call('GET', '/v1/settings');

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> values) =>
      _call('PUT', '/v1/settings', body: values);
}
