class Recording {
  final String id;
  final int cameraId;
  final String cameraName;
  final DateTime startTime;
  final DateTime endTime;
  final int sizeBytes;
  final String rtspUrl;

  Recording({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.startTime,
    required this.endTime,
    required this.sizeBytes,
    required this.rtspUrl,
  });

  Duration get duration => endTime.difference(startTime);

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(2)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      cameraId: json['cameraId'] as int,
      cameraName: json['cameraName'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      sizeBytes: json['sizeBytes'] as int,
      rtspUrl: json['rtspUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cameraId': cameraId,
      'cameraName': cameraName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'sizeBytes': sizeBytes,
      'rtspUrl': rtspUrl,
    };
  }
}
