import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AdbDevice {
  final String name;
  final String host;
  final int port;
  final String type; // 'pairing' or 'connect'
  final String? brand;
  final String? model;

  AdbDevice({
    required this.name,
    required this.host,
    required this.port,
    required this.type,
    this.brand,
    this.model,
  });

  String get displayName {
     if (brand != null && model != null) {
       return "${brand!.toUpperCase()} $model ($host:$port)";
     }
     return "$host:$port";
  }

  factory AdbDevice.fromMap(Map<dynamic, dynamic> map) {
    return AdbDevice(
      name: map['name'] as String,
      host: map['host'] as String,
      port: map['port'] as int,
      type: map['type'] as String,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
    );
  }

  AdbDevice copyWith({String? brand, String? model, String? host, int? port, String? type}) {
    return AdbDevice(
      name: name,
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdbDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          type == other.type &&
          brand == other.brand &&
          model == other.model;

  @override
  int get hashCode => host.hashCode ^ port.hashCode ^ type.hashCode ^ brand.hashCode ^ model.hashCode;
}

class AdbService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.flutter_client/adb');
  static const EventChannel _eventChannel = EventChannel('com.example.flutter_client/adb/discovery');

  Stream<AdbDevice>? _discoveryStream;

  Stream<AdbDevice> get discoveryStream {
    _discoveryStream ??= _eventChannel.receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event))
      .expand((map) {
         return map.entries.map((entry) {
            try {
               // Format: "ip:port|type"
               // Key: name_type (Composite)
               final val = entry.value as String;
               final parts = val.split('|');
               final addrParts = parts[0].split(':');
               
               if (addrParts.length < 2) return null;
               
               final type = parts.length > 1 ? parts[1] : 'connect';
               
               // Clean name from composite key "Name_type"
               // Note: If name itself has _, we might need lastIndexOf logic, 
               // but for now simple split or assuming format is sufficient.
               // Better: remove suffix "_$type"
               String rawName = entry.key;
               if (rawName.endsWith("_$type")) {
                   rawName = rawName.substring(0, rawName.length - (type.length + 1));
               }
               
               return AdbDevice(
                 name: rawName,
                 host: addrParts[0],
                 port: int.parse(addrParts[1]),
                 type: type,
               );
            } catch (e) {
               debugPrint("Error parsing device entry: $e");
               return null;
            }
         }).whereType<AdbDevice>();
      });
    return _discoveryStream!;
  }

  Future<void> startDiscovery() async {
    try {
       // The EventChannel automatically starts discovery on listen, 
       // but we can also have explicit control if needed via method channel
       await _methodChannel.invokeMethod('startDiscovery');
    } on PlatformException catch (e) {
      debugPrint("Failed to start discovery: '${e.message}'.");
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _methodChannel.invokeMethod('stopDiscovery');
    } on PlatformException catch (e) {
       debugPrint("Failed to stop discovery: '${e.message}'.");
    }
  }

  Future<bool> pair(String host, int port, String code) async {
    try {
      final result = await _methodChannel.invokeMethod('pair', {
        'host': host,
        'port': port,
        'code': code,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint("Pairing failed: '${e.message}'.");
      rethrow;
    }
  }

  Future<bool> testNativeConnection(String host, int port) async {
    try {
      final result = await _methodChannel.invokeMethod('testConnection', {
        'host': host,
        'port': port,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint("Native Connection Test Failed: '${e.message}'.");
      return false;
    }
  }
}
