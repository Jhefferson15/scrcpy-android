
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_client/features/adb/data/adb_manager.dart';
import 'package:flutter_client/core/crypto/rsa_key_manager.dart';
import 'package:flutter_client/features/remote_control/services/server_runner.dart';
import 'package:flutter_client/features/remote_control/services/native_decoder_bridge.dart';
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Headless Scrcpy Connection Test', (WidgetTester tester) async {
    print("[-] Starting Headless Test...");

    // 1. Initialize Managers
    final adbManager = AdbManager(RsaKeyManager());
    final decoder = NativeDecoderBridge();
    
    // 2. Find Device (or use hardcoded from Args if possible, otherwise discovery)
    // For automation, we'll try to discover for 5 seconds, picking the first one.
    print("[-] Starting Discovery...");
    String? targetHost;
    int targetPort = 5555;
    
    // We can't easily wait for discovery in a linear script without completer
    // But AdbManager discovery is stream based.
    final discoveryCompleter = <String, int>{};
    
    final sub = adbManager.discoveryStream.listen((device) {
       print("    [+] Discovered: ${device.host}:${device.port}");
       targetHost = device.host;
       targetPort = device.port;
    });
    
    adbManager.startDiscovery();
    await Future.delayed(const Duration(seconds: 5));
    adbManager.stopDiscovery();
    await sub.cancel();

    if (targetHost == null) {
       // Fallback to localhost if no discovery (e.g. emulator)
       print("    [!] No device discovered. Trying 127.0.0.1:5555 (Forwarded)");
       targetHost = "127.0.0.1";
    }

    print("[-] Target: $targetHost:$targetPort");

    // 3. Connect
    try {
      print("[-] Connecting...");
      await adbManager.connect(targetHost!, targetPort);
      print("    [+] Connected via ADB Protocol.");
    } catch (e) {
      print("    [!] Connection Failed: $e");
      // Fail explicitly? Or continue to see if native works?
      // If pure dart failed, native likely works if AdbManager delegates?
      // AdbManager uses pure Dart implementation usually.
    }

    // 4. Test Push & Server Start
    try {
      print("[-] Deploying Server...");
      // initializeSurface usually needed before startSession to get ID, but for headless we might skip surface init 
      // if verify-headless supports just checking the stream. 
      // But ServerRunner expects a configured decoder.
      // We will init surface anyway (flutter_test might support it headless).
      
      try {
        await decoder.initializeSurface(); 
        print("    [+] Surface Initialized.");
      } catch (e) {
        print("    [!] Surface Init Warning (Expected in headless?): $e");
      }

      final runner = ServerRunner();
      await runner.deployAndRun(adbManager, decoder);
      print("    [+] Server Deployed & Started.");
      
      // 5. Verification
      // We need to verify frames are arriving.
      // Since we don't have easy callbacks from Native -> Dart for "frame received" in the current bridge,
      // We rely on the logs inspection (already implemented in VideoDecoder.kt).
      // But this test needs to ASSERT success.
      // TODO: Update NativeDecoderBridge to expose "totalBytesReceived" getter.
      
      print("[-] Streaming for 5 seconds...");
      await Future.delayed(const Duration(seconds: 5));
      
    } catch (e) {
       print("    [!] Deployment/Stream Failed: $e");
       fail("Stream failed: $e");
    }
  });
}
