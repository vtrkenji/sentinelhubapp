class RFDevice {
  int code;
  String name;

  RFDevice({required this.code, required this.name});

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }

  factory RFDevice.fromJson(Map<String, dynamic> json) {
    return RFDevice(
      code: json['code'],
      name: json['name'],
    );
  }
}
