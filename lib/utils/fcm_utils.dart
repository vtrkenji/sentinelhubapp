import 'dart:math';

/// Utility class for FCM topic validation and generation.
class FcmUtils {
  // FCM topic validation rules:
  // - Non-empty
  // - Max 900 characters
  // - Only: letters, numbers, underscore, hyphen, dot, tilde, percent
  static const String _topicPattern = r'^[a-zA-Z0-9_\-.~%]+$';
  static const int _maxTopicLength = 900;

  /// Validates an FCM topic according to FCM rules.
  /// Returns null if valid, otherwise returns error message.
  static String? validateTopic(String? topic) {
    if (topic == null || topic.isEmpty) {
      return 'O tópico FCM não pode ser vazio.';
    }

    if (topic.length > _maxTopicLength) {
      return 'O tópico FCM não pode ter mais de $_maxTopicLength caracteres.';
    }

    if (!RegExp(_topicPattern).hasMatch(topic)) {
      return 'O tópico FCM só pode conter letras, números, _, -, ., ~, %.';
    }

    return null; // Valid
  }

  /// Generates a secure FCM topic in the format: sentinel_<32_hex_chars>
  /// Example: sentinel_7f29c4a9d83e41c2b5f6078a1d9e34bc
  static String generateSecureTopic() {
    const String hexChars = '0123456789abcdef';
    final Random random = Random.secure();
    
    final StringBuffer buffer = StringBuffer('sentinel_');
    for (int i = 0; i < 32; i++) {
      buffer.write(hexChars[random.nextInt(16)]);
    }
    
    return buffer.toString();
  }
}
