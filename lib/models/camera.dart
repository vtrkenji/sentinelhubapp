class Camera {
  final int id;
  final String name;
  final String rtspUrl;
  final String? rtspUrlSecondary;
  final String? description;
  final bool isActive;
  final String? snapshotFormat;
  final String? bitrate;

  Camera({
    required this.id,
    required this.name,
    required this.rtspUrl,
    this.rtspUrlSecondary,
    this.description,
    this.isActive = true,
    this.snapshotFormat,
    this.bitrate,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as int,
      name: json['name'] as String,
      rtspUrl: json['rtspUrl'] as String,
      rtspUrlSecondary: json['rtspUrlSecondary'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      snapshotFormat: json['snapshotFormat'] as String?,
      bitrate: json['bitrate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rtspUrl': rtspUrl,
      'rtspUrlSecondary': rtspUrlSecondary,
      'description': description,
      'isActive': isActive,
      'snapshotFormat': snapshotFormat,
      'bitrate': bitrate,
    };
  }

  Camera copyWith({
    int? id,
    String? name,
    String? rtspUrl,
    String? rtspUrlSecondary,
    String? description,
    bool? isActive,
    String? snapshotFormat,
    String? bitrate,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      rtspUrlSecondary: rtspUrlSecondary ?? this.rtspUrlSecondary,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      snapshotFormat: snapshotFormat ?? this.snapshotFormat,
      bitrate: bitrate ?? this.bitrate,
    );
  }

  String get activeRtspUrl {
    final secondary = rtspUrlSecondary?.trim();
    if (secondary?.isNotEmpty == true && isValidRtspUrl(secondary!)) {
      return secondary;
    }
    return rtspUrl.trim();
  }

  bool get hasValidRtspUrl => isValidRtspUrl(activeRtspUrl);

  static bool isValidRtspUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.scheme.toLowerCase() == 'rtsp' &&
        uri.host.isNotEmpty;
  }
}
