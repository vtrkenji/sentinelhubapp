import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'settings_service.dart';
import 'alert_history_service.dart';
import 'app_globals.dart';

class NtfyNativeService {
  NtfyNativeService._internal();
  static final NtfyNativeService instance = NtfyNativeService._internal();

  final SettingsService _settings = SettingsService();
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  Future<void> init() async {
    // Initialize local notifications (minimal default)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Provide Linux settings as well to avoid "Linux settings must be set" errors
    final LinuxInitializationSettings? linuxSettings =
        Platform.isLinux ? const LinuxInitializationSettings(defaultActionName: 'Abrir') : null;

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );
    await _fln.initialize(settings);
  }

  Future<void> start() async {
    if (_channel != null) return;
    await init();
    _connect();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;
    try {
      final topic = await _settings.loadNtfyTopic();
      final chosen = (topic.trim().isEmpty) ? 'sentinel_hub_vitor' : topic.trim();
      final uri = Uri.parse('wss://ntfy.sh/$chosen/ws');

      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen((event) {
        _handleMessage(event);
      }, onError: (e) {
        _scheduleReconnect();
      }, onDone: () {
        _scheduleReconnect();
      }, cancelOnError: true);
    } catch (e) {
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  void _handleMessage(dynamic event) {
    try {
      // ntfy sends JSON objects; try parsing
      final payload = (event is String) ? jsonDecode(event) : event;
      if (payload is Map && payload['event'] == 'message') {
        final title = payload['title'] ?? 'VSGuard Alert';
        final body = payload['message'] ?? payload['text'] ?? 'Nova mensagem';
        final String t = title.toString();
        final String b = body.toString();
        _showNotification(t, b);

        // Add to in-app history
        AlertHistoryService.instance.addAlert(
          AlertEntry(title: t, body: b, time: DateTime.now()),
        );

        // Show a lightweight snackbar if app is in foreground
        try {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('\$t: \$b'), behavior: SnackBarBehavior.floating),
            );
          }
        } catch (_) {}
      } else if (payload is String) {
        _showNotification('VSGuard', payload);
      }
    } catch (e) {
      // Fallback: show raw text
      _showNotification('VSGuard', event.toString());
    }
  }

  Future<void> _showNotification(String title, String body) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ntfy_channel',
      'Ntfy Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    try {
      await _fln.show(id, title, body, details);
    } catch (_) {}
  }
}
