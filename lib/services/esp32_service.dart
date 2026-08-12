import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Esp32Service {
  /// Verifica o status de um dispositivo ESP32 enviando uma requisição GET.
  /// Retorna `true` se o dispositivo responder com status 200, `false` caso contrário.
  Future<bool> checkStatus(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatusJson(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getConfig(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/config'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<bool> updateConfig(
    String ip,
    String ssid,
    String password,
    String topic,
  ) async {
    try {
      final body = jsonEncode(
        <String, String>{
          'ssid': ssid,
          'password': password,
          'topic': topic,
        },
      );
      final response = await http
          .post(
            Uri.parse('http://$ip/updateConfig'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envia um comando de acionamento para o relé do ESP32.
  /// Retorna a resposta do corpo da requisição em caso de sucesso, ou uma mensagem de erro.
  Future<String> triggerRelay(String ip) async {
    try {
      final response = await http
          .post(Uri.parse('http://$ip/trigger'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        return 'Erro: Dispositivo respondeu com status ${response.statusCode}';
      }
    } on TimeoutException {
      return 'Erro: Timeout ao tentar acionar o relé. O dispositivo não respondeu a tempo.';
    } catch (e) {
      return 'Erro desconhecido ao acionar o relé: $e';
    }
  }
}
