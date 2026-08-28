import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/ntfy_native_service.dart';
import 'services/app_globals.dart';

// Global keys are provided by services/app_globals.dart

const List<int> _backgroundBackoffSeconds = <int>[5, 10, 30];
Timer? _backgroundReconnectTimer;
int _backgroundReconnectAttempt = 0;

FlutterLocalNotificationsPlugin _createLocalNotificationsPlugin() =>
    FlutterLocalNotificationsPlugin();

Future<void> _initializeForegroundNotifications(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const LinuxInitializationSettings linuxInitializationSettings =
      LinuxInitializationSettings(defaultActionName: 'Abrir');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    linux: linuxInitializationSettings,
  );

  await plugin.initialize(initializationSettings);
}

void _showNtfyNotification(
  FlutterLocalNotificationsPlugin plugin,
  String title,
  String body,
) {
  plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alertas_seguranca',
        'Alertas de Intrusão',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    ),
  );
}

void _scheduleReconnect(
  Future<void> Function() connect,
  String context,
) {
  if (_backgroundReconnectTimer?.isActive ?? false) {
    return;
  }

  final delaySeconds = _backgroundBackoffSeconds[
      _backgroundReconnectAttempt.clamp(0, _backgroundBackoffSeconds.length - 1)];

  _backgroundReconnectAttempt = (_backgroundReconnectAttempt + 1)
      .clamp(0, _backgroundBackoffSeconds.length);

  debugPrint('[kTsentinel Background] $context - retry em ${delaySeconds}s');
  _backgroundReconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
    try {
      await connect();
    } catch (e, stackTrace) {
      debugPrint('[kTsentinel Background] Reconexão falhou: $e\n$stackTrace');
      _scheduleReconnect(connect, context);
    }
  });
}

void _resetReconnectBackoff() {
  _backgroundReconnectAttempt = 0;
  _backgroundReconnectTimer?.cancel();
  _backgroundReconnectTimer = null;
}

Future<void> _connectNtfyWebSocket(
  FlutterLocalNotificationsPlugin plugin,
  String topic,
  ServiceInstance service,
) async {
  final String wsUrl = 'wss://ntfy.sh/$topic/ws';
  debugPrint('[kTsentinel Background] Conectando via WebSocket: $wsUrl');

  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  channel.stream.listen(
    (dynamic message) {
      try {
        final payload = jsonDecode(message as String);
        final event = payload['event'];
        if (event != 'message') {
          return;
        }

        final mensagemRecebida = payload['message'] ?? 'Campainha acionada!';
        final tituloRecebido = payload['title'] ?? 'Alerta kTsentinel';

        debugPrint('[kTsentinel Background] Alerta capturado: $mensagemRecebida');
        _showNtfyNotification(plugin, tituloRecebido, mensagemRecebida);
        _resetReconnectBackoff();
      } catch (e) {
        debugPrint('[kTsentinel Background] JSON inválido via WebSocket: $e');
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('[kTsentinel Background] WebSocket falhou: $error');
      channel.sink.close();
      _scheduleReconnect(
        () => _connectNtfyWebSocket(plugin, topic, service),
        'WebSocket',
      );
    },
    onDone: () {
      debugPrint('[kTsentinel Background] WebSocket encerrado pelo servidor.');
      _scheduleReconnect(
        () => _connectNtfyWebSocket(plugin, topic, service),
        'WebSocket',
      );
    },
  );
}

Future<void> _connectNtfyHttpStream(
  FlutterLocalNotificationsPlugin plugin,
  String topic,
  ServiceInstance service,
) async {
  final String urlStream = '${AppConfig.ntfyBaseUrl}/$topic/json';
  debugPrint('[kTsentinel Background] Conectando via HTTP stream: $urlStream');

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(urlStream));
    final response = await client.send(request);

    response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (String line) {
        if (line.trim().isEmpty) {
          return;
        }

        try {
          final payload = jsonDecode(line);
          if (payload['event'] != 'message') {
            return;
          }

          final mensagemRecebida = payload['message'] ?? 'Campainha acionada!';
          final tituloRecebido = payload['title'] ?? 'Alerta kTsentinel';

          debugPrint('[kTsentinel Background] Alerta capturado: $mensagemRecebida');
          _showNtfyNotification(plugin, tituloRecebido, mensagemRecebida);
          _resetReconnectBackoff();
        } catch (e) {
          debugPrint('[kTsentinel Background] JSON inválido via HTTP stream: $e');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[kTsentinel Background] HTTP stream falhou: $error');
        client.close();
        _scheduleReconnect(
          () => _connectNtfyHttpStream(plugin, topic, service),
          'HTTP',
        );
      },
      onDone: () {
        debugPrint('[kTsentinel Background] HTTP stream finalizado.');
        client.close();
        _scheduleReconnect(
          () => _connectNtfyHttpStream(plugin, topic, service),
          'HTTP',
        );
      },
    );
  } catch (e) {
    client.close();
    debugPrint('[kTsentinel Background] Erro crítico de rede: $e');
    _scheduleReconnect(
      () => _connectNtfyHttpStream(plugin, topic, service),
      'HTTP',
    );
  }
}

Future<void> _startNtfyListener(
  FlutterLocalNotificationsPlugin plugin,
  SettingsService settingsService,
  ServiceInstance service,
) async {
  final topic = (await settingsService.loadNtfyTopic()).trim();
  final resolvedTopic = topic.isNotEmpty ? topic : AppConfig.ntfyTopic;

  debugPrint('[kTsentinel Background] Iniciando listener para tópico: $resolvedTopic');

  try {
    await _connectNtfyWebSocket(plugin, resolvedTopic, service);
  } catch (e, stackTrace) {
    debugPrint('[kTsentinel Background] WebSocket indisponível, indo para HTTP fallback: $e\n$stackTrace');
    await _connectNtfyHttpStream(plugin, resolvedTopic, service);
  }
}

@pragma('vm:entry-point')
Future<void> onStartBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      _createLocalNotificationsPlugin();
  await _initializeForegroundNotifications(flutterLocalNotificationsPlugin);

  final settingsService = SettingsService();
  final backgroundAtivo = await settingsService.loadBackgroundAtivo();

  if (!backgroundAtivo) {
    debugPrint('[kTsentinel Background] Serviço bloqueado por background_ativo=false');
    await service.stopSelf();
    return;
  }

  service.on('stopService').listen((event) async {
    debugPrint('[kTsentinel Background] Evento stopService recebido.');
    _backgroundReconnectTimer?.cancel();
    _backgroundReconnectTimer = null;
    await service.stopSelf();
  });

  await _startNtfyListener(flutterLocalNotificationsPlugin, settingsService, service);
}

Future<void> inicializarServicoSegundoPlano() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      _createLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vsguard_os_foreground',
    'VSGuard Service Channel',
    description: 'Canal usado para manter o serviço de escuta ativo no Android.',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackground,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
      notificationChannelId: 'vsguard_os_foreground',
      initialNotificationTitle: 'kTsentinel',
      initialNotificationContent: 'kTsentinel monitoramento ativo...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

Future<void> toggleBackgroundService({required bool enabled}) async {
  final settingsService = SettingsService();
  await settingsService.saveBackgroundAtivo(enabled);

  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();

  if (enabled) {
    await inicializarServicoSegundoPlano();
    if (!isRunning) {
      await service.startService();
    }
    return;
  }

  if (isRunning) {
    service.invoke('stopService');
  }
}

// ============================================================================
// FUNÇÃO MAIN
// ============================================================================
void main() {
  // TUDO deve estar dentro do runZonedGuarded para evitar o erro "Zone mismatch"
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError capturado: ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrint(details.stack.toString());
      }
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: AppConfig.backgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'O aplicativo encontrou um erro inesperado.\nTente reiniciar.\n\n${details.exceptionAsString()}',
              style: const TextStyle(color: AppConfig.textColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    };

    runApp(const SentinelApp());
  }, (error, stackTrace) {
    debugPrint('Erro não capturado: $error');
    debugPrint(stackTrace.toString());
  });
}

// ============================================================================
// APLICAÇÃO (UI)
// ============================================================================
class SentinelApp extends StatefulWidget {
  const SentinelApp({super.key});

  @override
  State<SentinelApp> createState() => _SentinelAppState();
}

class _SentinelAppState extends State<SentinelApp> {
  @override
  void initState() {
    super.initState();
    _iniciarServicosComSeguranca();
    // Start native websocket-based ntfy listener for in-app notifications
    Future.microtask(() async {
      try {
        final backgroundAtivo = await SettingsService().loadBackgroundAtivo();
        if (backgroundAtivo) {
          await NtfyNativeService.instance.start();
        }
      } catch (e) {
        debugPrint('Falha ao iniciar NtfyNativeService: $e');
      }
    });
  }

  // Garante que a permissão de notificação seja concedida ANTES de iniciar o
  // foreground service, evitando o crash do Android 13+ ao exibir a
  // notificação obrigatória do serviço sem permissão ainda concedida.
  Future<void> _iniciarServicosComSeguranca() async {
    final settingsService = SettingsService();
    final backgroundAtivo = await settingsService.loadBackgroundAtivo();
    if (!backgroundAtivo) {
      debugPrint('[kTsentinel] Serviço em segundo plano desativado pelo usuário.');
      return;
    }

    await _requestNotificationPermission();
    _startBackgroundService();
  }

  void _startBackgroundService() {
    if (Platform.isAndroid || Platform.isIOS) {
      Future.microtask(() async {
        try {
          await inicializarServicoSegundoPlano();
        } catch (e, stackTrace) {
          debugPrint('Falha ao iniciar serviço em segundo plano: $e\n$stackTrace');
        }
      });
    } else {
      debugPrint('Background service ignorado (não suportado no Desktop).');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kTsentinel',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppConfig.backgroundColor,
        canvasColor: AppConfig.backgroundColor,
        cardColor: AppConfig.cardColor,
        primaryColor: AppConfig.accentColor,
        colorScheme: const ColorScheme.dark(
          primary: AppConfig.accentColor,
          secondary: AppConfig.accentColor,
          surface: AppConfig.cardColor,
          error: AppConfig.alertColor,
          onPrimary: AppConfig.backgroundColor,
          onSecondary: AppConfig.backgroundColor,
          onSurface: AppConfig.textColor,
          onError: AppConfig.backgroundColor,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: AppConfig.textColor,
              displayColor: AppConfig.textColor,
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppConfig.cardColor.withAlpha((0.92 * 255).round()),
          elevation: 0,
          iconTheme: const IconThemeData(color: AppConfig.accentColor),
          titleTextStyle: const TextStyle(
            color: AppConfig.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          actionsIconTheme: const IconThemeData(color: AppConfig.accentColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppConfig.cardColor,
          filled: true,
          hintStyle: const TextStyle(color: AppConfig.mutedTextColor),
          labelStyle: TextStyle(color: AppConfig.textColor.withAlpha((0.92 * 255).round())),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppConfig.accentColor.withAlpha((0.16 * 255).round())),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppConfig.accentColor.withAlpha((0.16 * 255).round())),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppConfig.accentColor.withAlpha((0.40 * 255).round())),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppConfig.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppConfig.accentColor.withAlpha((0.10 * 255).round())),
          ),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.accentColor,
            foregroundColor: AppConfig.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConfig.accentColor,
            side: BorderSide(color: AppConfig.accentColor.withAlpha((0.30 * 255).round())),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppConfig.accentColor,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppConfig.cardColor,
          selectedItemColor: AppConfig.accentColor,
          unselectedItemColor: AppConfig.textColor.withAlpha((0.68 * 255).round()),
          selectedIconTheme: const IconThemeData(color: AppConfig.accentColor),
          unselectedIconTheme: IconThemeData(color: AppConfig.textColor.withAlpha((0.68 * 255).round())),
          type: BottomNavigationBarType.fixed,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppConfig.cardColor,
          contentTextStyle: TextStyle(color: AppConfig.textColor),
          actionTextColor: AppConfig.accentColor,
        ),
      ),
      home: const HomeScreen(), // A sua tela principal original!
    );
  }
}