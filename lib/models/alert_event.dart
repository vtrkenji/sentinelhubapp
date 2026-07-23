class AlertEvent {
  final String id;
  final String message;
  final DateTime timestamp;
  final AlertType type;
  final bool isAcknowledged;

  AlertEvent({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isAcknowledged = false,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      id: json['id'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: AlertType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AlertType.other,
      ),
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'isAcknowledged': isAcknowledged,
    };
  }
}

enum AlertType {
  doorbell,
  motion,
  alarm,
  other,
}
