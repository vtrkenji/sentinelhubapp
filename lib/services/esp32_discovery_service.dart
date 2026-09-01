import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class Esp32DiscoveryResult {
  final String protocol;
  final String device;
  final String moduleType;
  final String name;
  final String ip;
  final int httpPort;

  const Esp32DiscoveryResult({
    required this.protocol,
    required this.device,
    required this.moduleType,
    required this.name,
    required this.ip,
    required this.httpPort,
  });

  factory Esp32DiscoveryResult.fromJson(Map<String, dynamic> json) {
    return Esp32DiscoveryResult(
      protocol: json['protocol']?.toString() ?? '',
      device: json['device']?.toString() ?? 'SentinelHub',
      moduleType: json['moduleType']?.toString() ?? 'esp32c6-rf',
      name: json['name']?.toString() ?? 'SentinelHub',
      ip: json['ip']?.toString() ?? '',
      httpPort: int.tryParse(json['httpPort']?.toString() ?? '') ?? 80,
    );
  }
}

class Esp32DiscoveryService {
  static const String _discoverMessage = 'SENTINEL_DISCOVER_V1';
  static const int _udpPort = 4210;

  Future<List<Esp32DiscoveryResult>> discoverDevices({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final results = <Esp32DiscoveryResult>[];
    final seenIps = <String>{};
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );

      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          if (address.type != InternetAddressType.IPv4) {
            continue;
          }

          final parts = address.address.split('.');
          if (parts.length != 4 || parts[0] == '127') {
            continue;
          }

          final broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          targets.add(InternetAddress(broadcastAddress));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ESP discovery] Falha ao listar interfaces de rede: $e\n$stackTrace');
    }

    final data = utf8.encode(_discoverMessage);
    for (final target in targets) {
      try {
        socket.send(data, target, _udpPort);
      } catch (e, stackTrace) {
        debugPrint('[ESP discovery] Falha ao enviar broadcast para $target: $e\n$stackTrace');
      }
    }

    final completer = Completer<List<Esp32DiscoveryResult>>();
    socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = socket.receive();
      if (datagram == null) {
        return;
      }

      try {
        final payload = utf8.decode(datagram.data);
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        final protocol = decoded['protocol']?.toString();
        if (protocol != _discoverMessage) {
          return;
        }

        final ip = decoded['ip']?.toString() ?? '';
        if (ip.isEmpty || !seenIps.add(ip)) {
          return;
        }

        results.add(Esp32DiscoveryResult.fromJson(decoded));
      } catch (e) {
        debugPrint('[ESP discovery] Resposta UDP inválida ignorada: $e');
      }
    }, onError: (error) {
      debugPrint('[ESP discovery] Erro no socket UDP: $error');
    });

    await Future.delayed(timeout);
    socket.close();
    if (!completer.isCompleted) {
      completer.complete(results);
    }
    return await completer.future;
  }
}
