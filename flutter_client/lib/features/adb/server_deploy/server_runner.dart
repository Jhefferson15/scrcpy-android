
import 'package:flutter/foundation.dart';
import '../data/strategies/adb_strategy_interface.dart';

class ServerRunner {
  // ignore: unused_field
  final AdbStrategyInterface _adbStrategy;

  ServerRunner(this._adbStrategy);

  Future<void> startServer(String deviceIp) async {
    // Command to start scrcpy-server
    // Arguments:
    // 1.21 (scrcpy version? - check jar)
    // log_level=info
    // max_size=1024
    // etc.
    
    // Note: If Flutter connects to Server (port 7007), we might need to forward port or have server listen.
    // If we assume LAN visibility, we just run it and connect.
    
    // For now, constructing a basic command
    // We need to verify the arguments supported by the specific scrcpy-server.jar version
    
    final cmd = "CLASSPATH=/data/local/tmp/scrcpy-server.jar app_process / org.las2mile.scrcpy.Server 1.25 info 0 8000000 60 -1 false - false 0 0 0 7007 0 0 0 0";
    
    // Using nohup or similar might be needed to keep it running? 
    // Or we keep the shell stream open.
    debugPrint("Executing: $cmd");
    
    // We do NOT await this fully if it blocks. 
    // But app_process usually blocks. So we might need a separate execute implementation that doesn't wait for exit.
    // _adbStrategy.execute(cmd); 
  }
}
