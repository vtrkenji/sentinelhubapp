import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/ntfy_native_service.dart';
import 'services/app_globals.dart';

// Global keys are provided by services/app_globals.dart

// ============================================================================
// SERVIÇO EM SEGUNDO PLANO (Nativo usando http e stream)
// ============================================================================
@pragma('vm:entry-point')
void onStartBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Inicializa o plugin de Notificações Locais
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
    final LinuxInitializationSettings linuxInitializationSettings =
      const LinuxInitializationSettings(defaultActionName: 'Abrir');

    final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    linux: linuxInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final settingsService = SettingsService();
  String topicoSecreto = AppConfig.ntfyTopic;
  try {
    final configuredTopic = await settingsService.loadNtfyTopic();
    if (configuredTopic.trim().isNotEmpty) {
      topicoSecreto = configuredTopic.trim();
    }
  } catch (_) {
    debugPrint('[Sentinel Background] Falha ao carregar tópico ntfy local, usando padrão.');
  }

  final String urlStream = '${AppConfig.ntfyBaseUrl}/$topicoSecreto/json';

debugPrint('[kTsentinel Background] Conectando ao canal nativo: $urlStream');

  try {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(urlStream));
    
    // Abre a conexão e DEIXA ABERTA (Streaming)
    final response = await client.send(request);
    
    response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          
      // Ignora pings vazios que o servidor manda para manter a rede viva
      if (line.trim().isEmpty) return; 
      
      try {
        final payload = jsonDecode(line);
        
        // Se for uma mensagem real disparada pelo seu ESP32
        if (payload['event'] == 'message') {
          final String mensagemRecebida = payload['message'] ?? 'Campainha acionada!';
          final String tituloRecebido = payload['title'] ?? 'Alerta kTsentinel';

          debugPrint("[kTsentinel Background] Alerta Capturado: $mensagemRecebida");

          // Dispara a Notificação Push na tela do telemóvel
          flutterLocalNotificationsPlugin.show(
            DateTime.now().millisecond, 
            tituloRecebido,
            mensagemRecebida,
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
      } catch (e) {
        debugPrint("[Sentinel Background] Erro ao ler pacote JSON: $e");
      }
    });
  } catch (e) {
    debugPrint("[Sentinel Background] Erro crítico de conexão da rede: $e");
  }
}

// ============================================================================
// INICIALIZADOR DO FOREGROUND SERVICE
// ============================================================================
Future<void> inicializarServicoSegundoPlano() async {
  // CRIAÇÃO DO CANAL DE NOTIFICAÇÃO OBRIGATÓRIO PARA O ANDROID
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vsguard_os_foreground', // Tem que ser EXATAMENTE igual ao notificationChannelId abaixo
    'VSGuard Service Channel',
    description: 'Canal usado para manter o serviço de escuta ativo no Android.',
    importance: Importance.low, // Low para não fazer barulho/vibrar toda hora
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // AGORA SIM INICIAMOS O SERVIÇO
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackground,
      autoStart: true,
      isForegroundMode: true, // Garante que o Android não feche o app
      notificationChannelId: 'vsguard_os_foreground',
      initialNotificationTitle: 'kTsentinel',
      initialNotificationContent: 'kTsentinel monitoramento ativo...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), 
  );
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
    _startBackgroundService();
    _requestNotificationPermission();
    // Start native websocket-based ntfy listener for in-app notifications
    Future.microtask(() async {
      try {
        await NtfyNativeService.instance.start();
      } catch (e) {
        debugPrint('Falha ao iniciar NtfyNativeService: $e');
      }
    });
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

    void _requestNotificationPermission() async {
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