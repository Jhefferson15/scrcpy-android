import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_client/features/remote_control/services/native_decoder_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Headless Simulation Test (TCP)', (WidgetTester tester) async {
    print("[-] Starting Headless Simulation Test...");

    // 1. Initialize Decoder
    final decoder = NativeDecoderBridge();
    
    // 2. Initialize Surface (Required for MediaCodec)
    try {
      await decoder.initializeSurface(); 
      print("    [+] Surface Initialized.");
    } catch (e) {
      print("    [!] Surface Init Warning: $e");
    }

    // 3. Connect to Fake Server (Localhost)
    // The fake server should be running on port 5555.
    // ADB forwarding is NOT needed because we are running on Host (Windows) 
    // BUT wait, 'flutter test' runs ON THE DEVICE if --device is passed, or on Host if we use 'flutter run -d windows'?
    // "integration_test" usually runs on the target device.
    // If we run on Android Device, 127.0.0.1 refers to the Android device itself.
    // To reach the Host (where fake server is running), we need 10.0.2.2 (Emulator) or reverse forwarding.
    
    // CRITICAL:
    // If this test runs on a Real Device (RX2W500NBDP), "127.0.0.1" allows connecting to the device itself.
    // BUT the Fake Server is running on the Windows Host.
    // We need 'adb reverse tcp:5555 tcp:5555' so that Device:5555 -> Host:5555.
    // OR we run this test on 'windows' device?
    // The user wants to test "VideoDecoder.kt" which is Android Native code. So we MUST run on Android Device.
    
    // Therefore, the runner MUST set up reverse port forwarding before running this test.
    // runner.py will handle: adb reverse tcp:5555 tcp:5555
    
    const String targetHost = "127.0.0.1";
    const int targetPort = 5566;

    print("[-] Connecting to Simulation Server at $targetHost:$targetPort...");
    
    try {
        await decoder.startTcpSession(targetHost, targetPort);
        print("    [+] Connection initiated.");
    } catch (e) {
        print("    [!] Connection Failed: $e");
        fail("Connection failed: $e");
    }

    // 4. Verification
    // We stream for 5 seconds. The Logs (logcat) will be analyzed by runner.py to confirm frames.
    print("[-] Streaming for 5 seconds...");
    await Future.delayed(const Duration(seconds: 5));
    print("[-] Test Finished.");
  });
}
