import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/alert_event.dart';

class NtfyService {
  final String topicUrl = 'https://ntfy.sh/sentinel_hub_vitor/json?since=last';
  Timer? _pollTimer;
  final List<AlertEvent> _alerts = [];
  final StreamController<AlertEvent> _alertStream =
      StreamController<AlertEvent>.broadcast();

  Stream<AlertEvent> get alertStream => _alertStream.stream;

  List<AlertEvent> get alerts => List.unmodifiable(_alerts);

  void startListening({Duration pollInterval = const Duration(seconds: 3)}) {
    _pollTimer = Timer.periodic(pollInterval, (_) async {
      await _fetchAlerts();
    });
  }

  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse(topicUrl));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          final data = jsonDecode(line);

          if (data['event'] == 'message') {
            final alert = AlertEvent(
              id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              message: data['message'] ?? 'Alerta recebido',
              timestamp: DateTime.now(),
              type: _parseAlertType(data['message'] ?? ''),
            );

            // Evita duplicatas
            if (!_alerts.any((a) => a.id == alert.id)) {
              _alerts.add(alert);
              _alertStream.add(alert);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar alertas do ntfy: $e');
    }
  }

  AlertType _parseAlertType(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('campainha') || lowerMessage.contains('doorbell')) {
      return AlertType.doorbell;
    } else if (lowerMessage.contains('movimento') || lowerMessage.contains('motion')) {
      return AlertType.motion;
    } else if (lowerMessage.contains('alarme') || lowerMessage.contains('alarm')) {
      return AlertType.alarm;
    }
    return AlertType.other;
  }

  Future<void> triggerAlert(String message) async {
    try {
      await http.post(
        Uri.parse('https://ntfy.sh/sentinel_hub_vitor'),
        body: message,
      );
    } catch (e) {
      debugPrint('Erro ao enviar alerta: $e');
      rethrow;
    }
  }

  void dispose() {
    stopListening();
    _alertStream.close();
  }
}
