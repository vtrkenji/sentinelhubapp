import 'package:http/http.dart' as http;

class NtfyService {
  Future<void> sendNotification({
    required String topicUrl,
    required String title,
    required String message,
  }) async {
    if (topicUrl.isEmpty) {
      // Avoid sending notifications if the topic is not set
      return;
    }

    try {
      await http.post(
        Uri.parse(topicUrl),
        headers: {
          'Title': title,
        },
        body: message,
      );
    } catch (e) {
      // Handle potential errors, e.g., network issues
      print('Error sending ntfy notification: $e');
    }
  }
}
