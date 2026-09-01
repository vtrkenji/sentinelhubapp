import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/app_globals.dart';
import 'services/module_service.dart';

// Global keys are provided by services/app_globals.dart

// FCM global state
const String _androidNotificationChannelId = 'campainha_alertas';
const String _androidNotificationChannelName = 'Campainha';
const String _defaultFcmTopic = 'campainha'; // Fallback for old modules

late FlutterLocalNotificationsPlugin _fcmNotificationsPlugin;

const AndroidNotificationChannel _highPriorityChannel = AndroidNotificationChannel(
  _androidNotificationChannelId,
  _androidNotificationChannelName,
  description: 'Alertas de campainha e segurança do aplicativo kTsentinel.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

FlutterLocalNotificationsPlugin _createLocalNotificationsPlugin() =>
    FlutterLocalNotificationsPlugin();

Future<void> _initializeForegroundNotifications(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await plugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('[kTsentinel FCM] Notificação tocada: ${response.payload ?? "sem payload"}');
    },
  );

  final androidPlugin =
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_highPriorityChannel);
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
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidNotificationChannelId,
        _androidNotificationChannelName,
        channelDescription: _highPriorityChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'Campainha kTsentinel',
      ),
    ),
    payload: 'campainha',
  );
}

// ============================================================================
// FIREBASE CLOUD MESSAGING (FCM) INITIALIZATION AND HANDLERS
// ============================================================================

Future<void> _initializeFirebaseForAndroid() async {
  if (!Platform.isAndroid) {
    debugPrint('[kTsentinel FCM] Plataforma não Android: Firebase FCM desativado.');
    return;
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('[kTsentinel FCM] Firebase inicializado com sucesso no Android.');
  } catch (e, stackTrace) {
    debugPrint('[kTsentinel FCM] Erro ao inicializar Firebase no Android: $e\n$stackTrace');
  }
}

/// Background handler for FCM messages when app is closed or in background.
/// This must be a top-level function as per Firebase Messaging documentation.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[kTsentinel FCM] Mensagem recebida em segundo plano');
  debugPrint('[kTsentinel FCM] Dados: ${message.data}');
  debugPrint('[kTsentinel FCM] Título: ${message.notification?.title ?? message.data['title'] ?? 'sem título'}');
  debugPrint('[kTsentinel FCM] Corpo: ${message.notification?.body ?? message.data['body'] ?? 'sem corpo'}');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final plugin = _createLocalNotificationsPlugin();
    await _initializeForegroundNotifications(plugin);

    final title = message.notification?.title ??
        message.data['title'] ??
        'Alerta kTsentinel';
    final body = message.notification?.body ??
        message.data['body'] ??
        'Campainha acionada!';
    _showNtfyNotification(plugin, title, body);
    debugPrint('[kTsentinel FCM] Notificação local exibida em segundo plano');
  } catch (e, stackTrace) {
    debugPrint('[kTsentinel FCM] Erro ao processar mensagem em segundo plano: $e\n$stackTrace');
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

    if (Platform.isAndroid) {
      await _initializeFirebaseForAndroid();
    } else {
      debugPrint('[kTsentinel] Plataforma não Android: Firebase/FCM não inicializado.');
    }

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
    if (Platform.isAndroid) {
      _iniciarServicosComSeguranca();
    } else {
      debugPrint('[kTsentinel] Sistema operacional não Android: sem serviços de FCM.');
    }
  }

  Future<void> _iniciarServicosComSeguranca() async {
    debugPrint('[kTsentinel FCM] Inicializando serviços de notificações do app.');
    _fcmNotificationsPlugin = _createLocalNotificationsPlugin();
    await _requestNotificationPermission();
    await _initializeFCMService();
  }

  Future<void> _initializeFCMService() async {
    try {
      _fcmNotificationsPlugin = _createLocalNotificationsPlugin();
      await _initializeForegroundNotifications(_fcmNotificationsPlugin);

      debugPrint('[kTsentinel FCM] Inicializando Firebase Cloud Messaging...');

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        debugPrint('[kTsentinel FCM] Permissões de notificação concedidas');
      } else {
        debugPrint('[kTsentinel FCM] Permissões de notificação não concedidas. Status: $status');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[kTsentinel FCM] Token FCM: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[kTsentinel FCM] Mensagem recebida em primeiro plano');
        debugPrint('[kTsentinel FCM] Título: ${message.notification?.title ?? message.data['title'] ?? 'sem título'}');
        debugPrint('[kTsentinel FCM] Corpo: ${message.notification?.body ?? message.data['body'] ?? 'sem corpo'}');

        try {
          final title = message.notification?.title ??
              message.data['title'] ??
              'Alerta kTsentinel';
          final body = message.notification?.body ??
              message.data['body'] ??
              'Campainha acionada!';
          _showNtfyNotification(_fcmNotificationsPlugin, title, body);
        } catch (e, stackTrace) {
          debugPrint('[kTsentinel FCM] Erro ao processar mensagem em primeiro plano: $e\n$stackTrace');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[kTsentinel FCM] Abertura via toque na notificação: ${message.data}');
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[kTsentinel FCM] Notificação aberta ao iniciar o app: ${initialMessage.data}');
      }

      // Subscribe to all module FCM topics
      await _subscribeToAllModuleTopics();
    } catch (e, stackTrace) {
      debugPrint('[kTsentinel FCM] Falha ao inicializar Firebase Cloud Messaging: $e\n$stackTrace');
    }
  }

  /// Subscribe to FCM topics of all saved modules.
  /// Uses module-specific fcmtopic if available, otherwise falls back to default.
  Future<void> _subscribeToAllModuleTopics() async {
    try {
      final moduleService = ModuleService();
      final modules = await moduleService.getModules();
      
      final Set<String> topicsToSubscribe = {};
      
      for (final module in modules) {
        final fcmTopic = module.specificSettings['fcmtopic'] as String?;
        if (fcmTopic != null && fcmTopic.isNotEmpty) {
          topicsToSubscribe.add(fcmTopic);
        } else {
          // Use default topic for modules without explicit fcmtopic (backward compatibility)
          topicsToSubscribe.add(_defaultFcmTopic);
        }
      }
      
      // Subscribe to each unique topic
      for (final topic in topicsToSubscribe) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
          debugPrint('[kTsentinel FCM] Inscrito no tópico "$topic"');
        } catch (e) {
          debugPrint('[kTsentinel FCM] Erro ao inscrever no tópico "$topic": $e');
        }
      }
      
      if (topicsToSubscribe.isEmpty) {
        debugPrint('[kTsentinel FCM] Nenhum módulo configurado. Inscrito no tópico padrão "$_defaultFcmTopic"');
        await FirebaseMessaging.instance.subscribeToTopic(_defaultFcmTopic);
      }
    } catch (e, stackTrace) {
      debugPrint('[kTsentinel FCM] Erro ao inscrever em tópicos dos módulos: $e\n$stackTrace');
      // Fallback to default topic
      await FirebaseMessaging.instance.subscribeToTopic(_defaultFcmTopic);
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _fcmNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('[kTsentinel FCM] Permissão de notificação do plugin local: $granted');
    }
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