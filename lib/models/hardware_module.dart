enum ModuleType {
  wt32Eth01, // Para o gateway com Telegram e campainha RF
  genericEsp32, // Para outros dispositivos ESP32 genéricos
  rfGateway, // Focado apenas em RF
  pirSensor,
  relayModule,
}

extension ModuleTypeExtension on ModuleType {
  String get displayName {
    switch (this) {
      case ModuleType.wt32Eth01:
        return 'Gateway WT32-ETH01 (Telegram/RF)';
      case ModuleType.genericEsp32:
        return 'Módulo ESP32 Genérico';
      case ModuleType.rfGateway:
        return 'Gateway RF 433MHz';
      case ModuleType.pirSensor:
        return 'Sensor de Presença (PIR)';
      case ModuleType.relayModule:
        return 'Módulo Relé';
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
        orElse: () => ModuleType.genericEsp32,
      ),
      ipAddress: json['ipAddress'],
      specificSettings:
          Map<String, dynamic>.from(json['specificSettings'] ?? {}),
    );
  }
}
