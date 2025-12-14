
import 'package:flutter/services.dart';

class NativeDecoderBridge {
  static const MethodChannel _channel = MethodChannel('com.seuapp/decoder');

  Future<void> initializeSurface(int textureId) async {
    await _channel.invokeMethod('initSurface', {'textureId': textureId});
  }

  Future<void> feedH264Data(List<int> data) async {
    // Ideally we pass the socket file descriptor or use a direct byte buffer
    // Passing generic List<int> via MethodChannel is slow for video.
    // User requested "MethodChannel para o Kotlin".
    await _channel.invokeMethod('feedData', {'data': data});
  }
}
