
import 'dart:typed_data';
import 'adb_strategy_interface.dart';

class LegacyAdbStrategy implements AdbStrategyInterface {
  @override
  Future<void> connect(String ip, int port) {
    throw UnimplementedError("Legacy ADB (port 5555) not yet implemented");
  }

  @override
  Future<bool> pair(String ip, int port, String code) {
     throw UnimplementedError("Legacy ADB does not support pairing codes");
  }

  @override
  Future<String> execute(String command) {
    throw UnimplementedError();
  }

  @override
  Future<Stream<Uint8List>> executeStream(String command) {
    throw UnimplementedError();
  }

  @override
  Future<void> push(Uint8List data, String remotePath) {
    throw UnimplementedError();
  }
  
  @override
  Future<void> disconnect() async {}
}
