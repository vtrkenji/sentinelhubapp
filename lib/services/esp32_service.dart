import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Esp32Service {
  /// Verifica o status de um dispositivo ESP32 enviando uma requisição GET.
  /// Retorna o JSON decodificado contendo o status e os valores atuais.
  Future<Map<String, dynamic>> checkStatus(String ipAddress) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ipAddress/status'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Envia as configurações do ESP32-C6 RF usando POST (form-urlencoded).
  Future<bool> salvarConfiguracoes({
    required String ip,
    required String duckdom,
    required String ducktok,
    required String camp1,
    required String camp2,
    required String fcmTopic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://$ip/salvar'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'duckdom': duckdom,
          'ducktok': ducktok,
          'camp1': camp1,
          'camp2': camp2,
          'fcmtopic': fcmTopic,
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Esp32Service] Erro ao salvar configurações do módulo: $e');
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
