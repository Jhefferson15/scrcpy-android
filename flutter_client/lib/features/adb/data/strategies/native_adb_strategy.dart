import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'adb_strategy_interface.dart';
import '../../../../core/errors/adb_errors.dart';
import '../adb_protocol.dart';

class NativeAdbStrategy implements AdbStrategyInterface {
  static const platform = MethodChannel('com.example.flutter_client/adb');

  @override
  Future<bool> pair(String ip, int port, String code) async {
    try {
      final bool result = await platform.invokeMethod('pair', {
        'host': ip,
        'port': port,
        'code': code,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Native Pairing Error: ${e.message}");
      return false;
    }
  }

  @override
  Future<void> connect(String ip, int port) async {
    try {
      debugPrint("Bridge: Connecting to $ip:$port via Native Layer...");
      await platform.invokeMethod('connect', {
        'host': ip,
        'port': port,
      });
      debugPrint("Bridge: Connected successfully.");
    } on PlatformException catch (e) {
      debugPrint("Bridge Connection Failed: ${e.message}");
      throw ConnectionFailedException("Native Bridge failed: ${e.message}");
    }
  }

  @override
  Future<String> execute(String command) async {
    try {
      final String result = await platform.invokeMethod('execute', {
        'command': command,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Bridge Execute Failed: ${e.message}");
      throw ConnectionFailedException("Command failed: ${e.message}");
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await platform.invokeMethod('disconnect');
    } catch (e) {
      debugPrint("Bridge Disconnect Warning: $e");
    }
  }

  @override
  Future<Stream<Uint8List>> executeStream(String command) async {
    // For now, Native Bridge only supports blocking execute.
    // Streaming would require an EventChannel or specialized handling.
    // We can simulate a stream with the single result for compatibility.
    final result = await execute(command);
    return Stream.value(Uint8List.fromList(result.codeUnits));
  }

  @override
  Future<void> push(Uint8List data, String remotePath) async {
      try {
        await platform.invokeMethod('pushFile', {
          'path': remotePath,
          'data': data,
        });
      } on PlatformException catch (e) {
        debugPrint("Native Push Failed: ${e.message}");
        throw ConnectionFailedException("Push failed: ${e.message}");
      }
  }
}
