
import 'dart:io';
import 'package:flutter/services.dart';
import '../../adb/data/adb_manager.dart';
import 'native_decoder_bridge.dart';

class ServerRunner {
  static const String _serverPath = '/data/local/tmp/scrcpy-server.jar';
  static const String _serverVersion = '3.3.3';

  /// Deploy scrcpy server and start streaming with dynamic resolution detection
  Future<Map<String, int>> deployAndRun(AdbManager adb, NativeDecoderBridge decoder) async {
    // 1. Load Server Jar
    final ByteData data = await rootBundle.load('assets/scrcpy-server.jar');
    final List<int> bytes = data.buffer.asUint8List();

    // 2. Push to device
    await adb.pushFile(bytes, _serverPath);

    // 3. Get device resolution dynamically
    print('[ServerRunner] Querying device resolution...');
    final resolution = await _getDeviceResolution(adb);
    final width = resolution['width']!;
    final height = resolution['height']!;
    print('[ServerRunner] Device resolution: ${width}x${height}');

    // 4. Calculate scrcpy max_size (maintain aspect ratio, max dimension 1920)
    final maxDim = width > height ? width : height;
    final maxSize = maxDim > 1920 ? 1920 : maxDim;
    
    // Calculate actual stream dimensions
    final scale = maxSize / maxDim;
    final streamWidth = (width * scale).round();
    final streamHeight = (height * scale).round();
    
    print('[ServerRunner] Stream resolution will be: ${streamWidth}x${streamHeight}');

    // 5. Start Server
    final String command = 'CLASSPATH=$_serverPath app_process / com.genymobile.scrcpy.Server $_serverVersion video_codec=h264 audio=false max_size=$maxSize max_fps=60 tunnel_forward=true control=false send_device_meta=false send_frame_meta=false send_dummy_byte=false send_codec_meta=false';
    
    // 6. Start Session via Decoder Bridge
    await decoder.startSession(command);

    // Return stream resolution for caller to use
    return {'width': streamWidth, 'height': streamHeight};
  }

  Future<Map<String, int>> _getDeviceResolution(AdbManager adb) async {
    try {
      // Execute 'wm size' command to get display dimensions
      final output = await adb.executeCommand('wm size');
      // Output format: "Physical size: 1200x2000"
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
      if (match != null) {
        return {
          'width': int.parse(match.group(1)!),
          'height': int.parse(match.group(2)!),
        };
      }
    } catch (e) {
      print('[ServerRunner] Failed to get device resolution: $e');
    }
    
    // Fallback to common resolution if detection fails
    print('[ServerRunner] Using fallback resolution 1080x1920');
    return {'width': 1080, 'height': 1920};
  }
}
