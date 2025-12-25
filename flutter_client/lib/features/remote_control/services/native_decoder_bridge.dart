
import 'package:flutter/services.dart';

class NativeDecoderBridge {
  static const MethodChannel _channel = MethodChannel('com.seuapp/decoder');

  Future<int> initializeSurface({int width = 1920, int height = 1080}) async {
    final int? textureId = await _channel.invokeMethod('initSurface', {
      'width': width,
      'height': height,
    });
    return textureId ?? -1;
  }


  Future<void> startSession(String command) async {
    await _channel.invokeMethod('startSession', {'command': command});
  }

  Future<void> startTcpSession(String host, int port) async {
    await _channel.invokeMethod('startTcpSession', {'host': host, 'port': port});
  }

  Future<void> feedH264Data(List<int> data) async {
    // Ideally we pass the socket file descriptor or use a direct byte buffer
    // Passing generic List<int> via MethodChannel is slow for video.
    // User requested "MethodChannel para o Kotlin".
    await _channel.invokeMethod('feedData', {'data': data});
  }
}
