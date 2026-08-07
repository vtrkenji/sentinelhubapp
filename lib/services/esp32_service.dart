import 'dart:async';
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
    } catch (e) {
      // Em qualquer caso de erro, consideramos o dispositivo offline.
      // Em uma aplicação real, seria bom ter um log mais robusto aqui.
      // Ex: log.error('Erro ao checar status do ESP32: $e');
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
        return response.body; // Retorna a mensagem de sucesso do ESP32
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
