import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_client/features/adb/data/adb_manager.dart';
import 'package:flutter_client/core/crypto/rsa_key_manager.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Push Verification Test', (WidgetTester tester) async {
    print("[-] Starting Push Verification Test...");

    // 1. Initialize Managers
    final adbManager = AdbManager(RsaKeyManager());
    
    // 2. Find Device via Discovery
    print("[-] Starting Discovery...");
    String? targetHost;
    int targetPort = 5555;
    
    final sub = adbManager.discoveryStream.listen((device) {
      print("    [+] Discovered: ${device.host}:${device.port}");
      if (targetHost == null) {
        targetHost = device.host;
        targetPort = device.port;
      }
    });
    
    adbManager.startDiscovery();
    await Future.delayed(const Duration(seconds: 5));
    adbManager.stopDiscovery();
    await sub.cancel();

    if (targetHost == null) {
      print("    [!] No device discovered. Trying 127.0.0.1:5555 (Forwarded)");
      targetHost = "127.0.0.1";
    }

    print("[-] Target: $targetHost:$targetPort");

    // 3. Connect
    try {
      print("[-] Connecting...");
      await adbManager.connect(targetHost!, targetPort);
      print("    [+] Connected via Native ADB Protocol.");
    } catch (e) {
      print("    [!] Connection Failed: $e");
      fail("Failed to connect to device: $e");
    }

    // 4. Load scrcpy-server.jar from assets
    print("[-] Loading scrcpy-server.jar from assets...");
    ByteData serverData;
    try {
      serverData = await rootBundle.load('assets/scrcpy-server.jar');
      print("    [+] Loaded ${serverData.lengthInBytes} bytes");
    } catch (e) {
      print("    [!] Failed to load scrcpy-server.jar: $e");
      fail("Failed to load server file: $e");
    }

    // 5. Push to Device
    final remotePath = "/data/local/tmp/scrcpy-server.jar";
    print("[-] Pushing to $remotePath...");
    
    try {
      await adbManager.pushFile(
        serverData.buffer.asUint8List(),
        remotePath,
      );
      print("    [+] Push completed successfully!");
    } catch (e) {
      print("    [!] Push Failed: $e");
      fail("Failed to push file: $e");
    }

    // 6. Verify File Exists
    print("[-] Verifying file exists...");
    try {
      final output = await adbManager.executeCommand("ls -l $remotePath");
      print("    [+] File exists: $output");
      
      // Check if file is executable
      if (!output.contains("rwxrwxrwx") && !output.contains("rwx")) {
        print("    [!] WARNING: File may not have correct permissions");
      }
    } catch (e) {
      print("    [!] Verification failed: $e");
      fail("File verification failed: $e");
    }

    // 7. Verify File Size
    print("[-] Verifying file size...");
    try {
      final output = await adbManager.executeCommand("stat -c %s $remotePath 2>/dev/null || wc -c < $remotePath");
      final remoteSize = int.tryParse(output.trim());
      
      if (remoteSize == null) {
        print("    [!] Could not determine remote file size");
      } else if (remoteSize == serverData.lengthInBytes) {
        print("    [+] File size matches: $remoteSize bytes");
      } else {
        print("    [!] Size mismatch! Expected: ${serverData.lengthInBytes}, Got: $remoteSize");
        fail("File size mismatch");
      }
    } catch (e) {
      print("    [!] Size check failed: $e");
    }

    print("[-] Push Verification Test Completed Successfully!");
  });
}
