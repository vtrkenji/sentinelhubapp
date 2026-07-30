import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../main.dart';
import '../screens/live_view_screen.dart';
import 'settings_service.dart';

class NtfyStreamService {
  final SettingsService _settingsService;
  http.Client? _client;
  StreamSubscription? _subscription;
  bool _isRunning = false;

  NtfyStreamService(this._settingsService);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    final ntfyEnabled = await _settingsService.loadNtfyEnabled();
    if (!ntfyEnabled) {
      print('Ntfy stream is disabled in settings.');
      return;
    }

    final topicUrl = await _settingsService.loadNtfyTopicUrl();
    if (topicUrl.isEmpty) {
      print('Ntfy topic URL is not set.');
      return;
    }

    final streamUrl = '$topicUrl/json';
    _client = http.Client();
    final request = http.Request('GET', Uri.parse(streamUrl));

    print('Starting ntfy stream...');
    _isRunning = true;

    try {
      final response = await _client!.send(request);

      _subscription = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.startsWith('data:')) {
            final jsonString = line.substring(5);
            _handleEvent(jsonString);
          }
        },
        onDone: () {
          print('Ntfy stream disconnected.');
          _isRunning = false;
          // Optionally restart the stream
          if (ntfyEnabled) {
             Future.delayed(Duration(seconds: 5), start);
          }
        },
        onError: (error) {
          print('Ntfy stream error: $error');
          _isRunning = false;
          // Optionally restart the stream
          if (ntfyEnabled) {
             Future.delayed(Duration(seconds: 5), start);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Could not connect to ntfy stream: $e');
      _isRunning = false;
    }
  }

  void stop() {
    print('Stopping ntfy stream...');
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
    _isRunning = false;
  }
  
  Future<void> restart() async {
    stop();
    await start();
  }

  void _handleEvent(String jsonString) {
    try {
      final event = jsonDecode(jsonString);
      final String title = event['title'] ?? '';
      final String message = event['message'] ?? '';
      final String? clickUrl = event['click'];

      print('Received ntfy event: $title');

      if (title.contains('Campainha')) {
        if (clickUrl != null && clickUrl.startsWith('rtsp://')) {
          final camera = Camera(id: 99, name: 'Campainha', rtspUrl: clickUrl);
          // Navigate to live view
          final context = navigatorKey.currentState?.context;
          if (context != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveViewScreen(camera: camera),
              ),
            );
          }
        }
      } else if (title.contains('Alerta de RF')) {
        // Show a snackbar
        final context = scaffoldMessengerKey.currentState?.context;
        if (context != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Error handling ntfy event: $e');
    }
  }
}

