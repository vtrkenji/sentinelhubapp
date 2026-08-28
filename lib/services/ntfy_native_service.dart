import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sentinel_hub/services/settings_service.dart';
import 'alert_history_service.dart';

import '../config/app_config.dart';

class NtfyNativeService {
  static final NtfyNativeService instance = NtfyNativeService._internal();
  NtfyNativeService._internal();

  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> start() async {
    final settingsService = SettingsService();
    final backgroundEnabled = await settingsService.loadBackgroundAtivo();
    if (!backgroundEnabled) {
      debugPrint('[NtfyWS] Listener in-app desativado pelo usuário.');
      stop();
      return;
    }

    // 1. Inicialização segura para Mobile e Desktop (Linux/Windows)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Abrir');
    
    const initSettings = InitializationSettings(
      android: androidInit,
      linux: linuxInit, 
    );

    await _localNotifications.initialize(initSettings);

    // 2. Load dynamic topic from SettingsService
    String topic = await settingsService.loadNtfyTopic();
    if (topic.isEmpty) {
      topic = 'sentinel_vitor_01';
    }

    // 3. Transforma a URL HTTP em WSS (WebSocket Seguro)
    final String wsUrl = 'wss://ntfy.sh/$topic/ws';
    
    debugPrint('[NtfyWS] Conectando ao WebSocket: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            
            if (data['event'] == 'message') {
              final String titulo = data['title'] ?? 'Alerta VSGuard OS';
              final String corpo = data['message'] ?? 'Campainha acionada!';

              debugPrint('[NtfyWS] Mensagem recebida: $corpo');
              
              // Exibe o balão nativo
              _mostrarNotificacaoLocal(titulo, corpo);
              
              // Salva no histórico do app usando o objeto AlertEntry correto
              AlertHistoryService.instance.addAlert(
                AlertEntry(
                  title: titulo,
                  body: corpo,
                  time: DateTime.now(),
                ),
              );
            }
          } catch (e) {
            debugPrint('[NtfyWS] Erro ao decodificar JSON do WebSocket: $e');
          }
        },
        onError: (error) {
          debugPrint('[NtfyWS] Erro na conexão WebSocket: $error');
          _tentarReconectar();
        },
        onDone: () {
          debugPrint('[NtfyWS] Conexão WebSocket fechada. Tentando reconectar...');
          _tentarReconectar();
        },
      );
    } catch (e) {
      debugPrint('[NtfyWS] Falha crítica ao iniciar WebSocket: $e');
    }
  }

  Future<void> _mostrarNotificacaoLocal(String titulo, String corpo) async {
    const androidDetails = AndroidNotificationDetails(
      'alertas_seguranca',
      'Alertas de Intrusão',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      linux: LinuxNotificationDetails(),
    );

    // Usa um ID único baseado no tempo para o Linux não recusar por excesso rápido
    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      titulo,
      corpo,
      notificationDetails,
    );
  }

  void _tentarReconectar() {
    Future.delayed(const Duration(seconds: 5), () {
      debugPrint('[NtfyWS] Tentando reconectar ao Ntfy...');
      start();
    });
  }

  void stop() {
    _channel?.sink.close();
    _channel = null;
  }
}