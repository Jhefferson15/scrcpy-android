import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/strategies/adb_strategy_interface.dart';


class ServerInjector {
  final AdbStrategyInterface _adbStrategy;

  ServerInjector(this._adbStrategy);

  Future<void> setupServer(String deviceIp) async {
    // 1. Read JAR from assets
    final ByteData data = await rootBundle.load('assets/scrcpy-server.jar');
    final Uint8List bytes = data.buffer.asUint8List();

    // 2. Push to /data/local/tmp/
    const String remotePath = '/data/local/tmp/scrcpy-server.jar';
    debugPrint("Pushing server to $remotePath...");
    await _adbStrategy.push(bytes, remotePath);

    // 3. Run the server
    // Note: The ServerRunner would typically handle the execution command construction
    // but we can trigger it here or in a separate class.
  }
}
