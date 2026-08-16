import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'settings_service.dart';

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
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
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
        _showNotification(title.toString(), body.toString());
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
