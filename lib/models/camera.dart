class Camera {
  final int id;
  final String name;
  final String rtspUrl;
  final String? description;
  final bool isActive;

  Camera({
    required this.id,
    required this.name,
    required this.rtspUrl,
    this.description,
    this.isActive = true,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as int,
      name: json['name'] as String,
      rtspUrl: json['rtspUrl'] as String,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rtspUrl': rtspUrl,
      'description': description,
      'isActive': isActive,
    };
  }
}
