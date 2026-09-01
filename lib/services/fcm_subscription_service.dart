import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'module_service.dart';

class FcmSubscriptionService {
  /// Manages FCM topic subscriptions for all modules.
  /// Only works on Android platform.

  static const String _defaultTopic = 'campainha';

  /// Subscribe to FCM topics of all saved modules.
  /// Returns list of topics subscribed to.
  static Future<List<String>> subscribeToAllModuleTopics() async {
    if (!Platform.isAndroid) {
      debugPrint('[FcmSubscriptionService] Platform não é Android. Skipping FCM subscription.');
      return [];
    }

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
          topicsToSubscribe.add(_defaultTopic);
        }
      }

      // Subscribe to each unique topic
      for (final topic in topicsToSubscribe) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
          debugPrint('[FcmSubscriptionService] Inscrito no tópico "$topic"');
        } catch (e) {
          debugPrint('[FcmSubscriptionService] Erro ao inscrever no tópico "$topic": $e');
        }
      }

      if (topicsToSubscribe.isEmpty) {
        debugPrint('[FcmSubscriptionService] Nenhum módulo configurado. Inscrito no tópico padrão "$_defaultTopic"');
        await FirebaseMessaging.instance.subscribeToTopic(_defaultTopic);
        return [_defaultTopic];
      }

      return topicsToSubscribe.toList();
    } catch (e, stackTrace) {
      debugPrint('[FcmSubscriptionService] Erro ao inscrever em tópicos dos módulos: $e\n$stackTrace');
      // Fallback to default topic
      await FirebaseMessaging.instance.subscribeToTopic(_defaultTopic);
      return [_defaultTopic];
    }
  }

  /// Unsubscribe from FCM topic if no other modules use it.
  /// Returns true if unsubscribed, false if still in use by other modules.
  static Future<bool> unsubscribeFromTopicIfUnused(String topic) async {
    if (!Platform.isAndroid) {
      return false;
    }

    if (topic == _defaultTopic) {
      // Never unsubscribe from default topic
      return false;
    }

    try {
      final moduleService = ModuleService();
      final modules = await moduleService.getModules();

      // Check if any other module uses this topic
      for (final module in modules) {
        final fcmTopic = module.specificSettings['fcmtopic'] as String?;
        if (fcmTopic == topic) {
          // Topic still in use
          return false;
        }
      }

      // Topic not used by any module, unsubscribe
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('[FcmSubscriptionService] Desinscrito do tópico "$topic"');
      return true;
    } catch (e) {
      debugPrint('[FcmSubscriptionService] Erro ao desinscrever do tópico "$topic": $e');
      return false;
    }
  }
}
