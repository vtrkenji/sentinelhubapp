enum ModuleType {
  wt32Eth01,
  gatewayEsp32C6Rf,
}

extension ModuleTypeExtension on ModuleType {
  String get displayName {
    switch (this) {
      case ModuleType.wt32Eth01:
        return 'Gateway WT32-ETH01';
      case ModuleType.gatewayEsp32C6Rf:
        return 'Gateway ESP32-C6 (RF)';
    }
  }
}

class HardwareModule {
  final String id;
  final String name;
  final ModuleType type;
  final String ipAddress;
  // Campo flexível para configurações específicas de cada tipo de módulo
  final Map<String, dynamic> specificSettings;

  HardwareModule({
    required this.id,
    required this.name,
    required this.type,
    required this.ipAddress,
    this.specificSettings = const {},
  });

  HardwareModule copyWith({
    String? id,
    String? name,
    ModuleType? type,
    String? ipAddress,
    Map<String, dynamic>? specificSettings,
  }) {
    return HardwareModule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ipAddress: ipAddress ?? this.ipAddress,
      specificSettings: specificSettings ?? this.specificSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'ipAddress': ipAddress,
      'specificSettings': specificSettings,
    };
  }

  factory HardwareModule.fromJson(Map<String, dynamic> json) {
    return HardwareModule(
      id: json['id'],
      name: json['name'],
      type: ModuleType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ModuleType.gatewayEsp32C6Rf,
      ),
      ipAddress: json['ipAddress'],
      specificSettings:
          Map<String, dynamic>.from(json['specificSettings'] ?? {}),
    );
  }
}
