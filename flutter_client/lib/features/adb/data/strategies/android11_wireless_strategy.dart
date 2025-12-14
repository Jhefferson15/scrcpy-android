import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'adb_strategy_interface.dart';
import '../../../../core/crypto/rsa_key_manager.dart';
import '../../../../core/errors/adb_errors.dart';
import '../adb_protocol.dart';

class Android11WirelessStrategy implements AdbStrategyInterface {
  final RsaKeyManager _keyManager;
  SecureSocket? _deviceSocket;
  StreamSubscription<AdbPacket>? _packetSubscription;
  
  // Broadcast stream controller to distribute packets to multiple listeners (handshake, execute, stream)
  final StreamController<AdbPacket> _packetController = StreamController<AdbPacket>.broadcast();

  Android11WirelessStrategy(this._keyManager);

  static const platform = MethodChannel('com.example.flutter_client/adb');

  @override
  Future<bool> pair(String ip, int port, String code) async {
    debugPrint("Attempting to pair with $ip:$port using Native MethodChannel");
    try {
      final bool result = await platform.invokeMethod('pair', {
        'host': ip,
        'port': port,
        'code': code,
      });
      
      debugPrint("Native Pairing Result: $result");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Native Pairing Failed: ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Unexpected error calling native pairing: $e");
      return false;
    }
  }

  @override
  Future<void> connect(String ip, int port) async {
    try {
      // 1. Cleanup previous connection if any
      await disconnect();

      // 2. Load keys
      final keys = await _keyManager.getOrGenerateKey();
      
      // 3. Setup TLS Context
      SecurityContext context = SecurityContext(withTrustedRoots: true);
      
      // Debug: Read and print the key files to verify content
      final debugPriv = await keys.privateKey.readAsString();
      final debugCert = await keys.certificate.readAsString();
      debugPrint("Using Private Key (First 50 chars): ${debugPriv.substring(0, 50)}...");
      debugPrint("Using Certificate (First 50 chars): ${debugCert.substring(0, 50)}...");
      
      // Use File-based loading (Robustness)
      context.usePrivateKey(keys.privateKey.path);
      context.useCertificateChain(keys.certificate.path);
      
      // 4. Connect
      debugPrint("Connecting via TLS to $ip:$port");
      try {
        _deviceSocket = await SecureSocket.connect(ip, port, context: context, onBadCertificate: (cert) {
           debugPrint("Server Certificate presented: Subject: ${cert.subject}, Issuer: ${cert.issuer}");
           return true; 
        });
      } on HandshakeException catch (e) {
         _handleHandshakeError(e);
         rethrow;
      } on SocketException catch (e) {
         debugPrint("Network Connection Failed: ${e.message}");
         rethrow;
      }

      debugPrint("Connected securely to $ip:$port. Starting ADB Handshake...");
      
      // 5. Setup Packet Stream with Transformer
      // We use a broadcast stream so multiple command waiters can listen to different packet IDs
      _packetSubscription = _deviceSocket!
          .transform(AdbPacketTransformer())
          .listen((packet) {
            _packetController.add(packet);
          }, onError: (e) {
            debugPrint("Packet Stream Error: $e");
            _packetController.addError(e);
            disconnect();
          }, onDone: () {
            debugPrint("Packet Stream Closed");
            disconnect();
          });

      // 6. Perform ADB Handshake
      await _performAdbHandshake();

    } catch (e) {
      await disconnect(); 
      throw ConnectionFailedException("TLS Connection failed: $e");
    }
  }
  
  void _handleHandshakeError(HandshakeException e) {
     debugPrint("TLS Handshake Failed!");
     debugPrint("Message: ${e.message}");
     
     if (e.toString().contains("CERTIFICATE_VERIFY_FAILED")) {
        debugPrint("Hint: The device rejected our certificate. Ensure your keys are authorized.");
     } else if (e.osError?.message.contains("Connection reset") ?? false) {
         debugPrint("Hint: The server closed the connection. Check port type (Pairing vs Connect) or revocation.");
     }
  }

  Future<void> _performAdbHandshake() async {
      // CNXN: version(4) + maxdata(4) + system_identity_string
      final version = 0x01000001; // ADB v1.0.0.1
      final maxData = 1024 * 1024; // 1MB
      // Add standard ADB features to identity to prevent rejection by stricter daemons
      final identity = "host::flutter_client:shell_v2,cmd,stat_v2,ls_v2,fixed_push_mkdir";
      
      final payload = ByteData(4 + 4 + identity.length);
      payload.setUint32(0, version, Endian.little);
      payload.setUint32(4, maxData, Endian.little);
      final identityBytes = identity.codeUnits;
      for (int i = 0; i < identityBytes.length; i++) {
        payload.setUint8(8 + i, identityBytes[i]);
      }
      
      _sendAdbPacket("CNXN", payload.buffer.asUint8List()); 
      
      // Wait for CNXN response with timeout
      try {
        await _packetController.stream
            .firstWhere((p) => p.command == "CNXN")
            .timeout(const Duration(seconds: 5), onTimeout: () {
               throw TimeoutException("Timed out waiting for CNXN response");
            });
        debugPrint("ADB Handshake Successful");
      } catch (e) {
        throw ConnectionFailedException("ADB Handshake failed: $e");
      }
  }

  @override
  Future<String> execute(String command) async {
    if (_deviceSocket == null) {
        throw ConnectionFailedException("Not connected");
    }
    
    final localId = _generateId();
    final remoteId = 0; // Target is typically 0 for new open
    
    // OPEN shell:command
    final destination = "shell:$command\u0000";
    final payload = Uint8List.fromList(destination.codeUnits);
    
    _sendAdbPacket("OPEN", payload, arg0: localId, arg1: remoteId);
    
    StringBuffer output = StringBuffer();
    final completer = Completer<String>();
    
    // Create a temporary subscription for this command
    // We filter stream for our localId
    final subscription = _packetController.stream.listen((packet) {
       // Only care about packets meant for this stream ID
       // For WRTE/CLSE, arg1 is the destination ID (our localId)
       if (packet.arg1 == localId) {
          if (packet.command == "OKAY") {
             // Remote accepted stream (packet.arg0 is their remoteId)
          } else if (packet.command == "WRTE") {
             output.write(String.fromCharCodes(packet.payload));
             _sendAdbPacket("OKAY", Uint8List(0), arg0: localId, arg1: packet.arg0);
          } else if (packet.command == "CLSE") {
             _sendAdbPacket("CLSE", Uint8List(0), arg0: localId, arg1: packet.arg0);
             if (!completer.isCompleted) completer.complete(output.toString());
          }
       }
       // Note: If server sends packets for *other* streams, this listener ignores them
    });
    
    // Add safety timeout
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
        subscription.cancel();
        throw TimeoutException("Command execution timed out: $command");
    }).whenComplete(() {
        subscription.cancel();
    });
  }

  @override
  Future<Stream<Uint8List>> executeStream(String command) async {
    if (_deviceSocket == null) {
        throw ConnectionFailedException("Not connected");
    }
    
    final localId = _generateId();
    final remoteId = 0;
    
    final destination = "shell:$command\u0000";
    final payload = Uint8List.fromList(destination.codeUnits);
    
    _sendAdbPacket("OPEN", payload, arg0: localId, arg1: remoteId);
    
    final controller = StreamController<Uint8List>();
    
    StreamSubscription? sub;
    sub = _packetController.stream.listen((packet) {
       if (packet.arg1 == localId) {
          if (packet.command == "WRTE") {
             controller.add(packet.payload);
             _sendAdbPacket("OKAY", Uint8List(0), arg0: localId, arg1: packet.arg0);
          } else if (packet.command == "CLSE") {
             // Acknowledge close
             _sendAdbPacket("CLSE", Uint8List(0), arg0: localId, arg1: packet.arg0);
             controller.close();
             sub?.cancel();
          }
       }
    }, onError: controller.addError, onDone: controller.close);
    
    return controller.stream;
  }

  @override
  Future<void> push(Uint8List data, String remotePath) async {
     // TODO: Implement Push using SYNC subcommand
     throw UnimplementedError("Push implementation is next step");
  }

  @override
  Future<void> disconnect() async {
    await _packetSubscription?.cancel();
    _packetSubscription = null;
    await _deviceSocket?.close();
    _deviceSocket = null;
  }
  
  void _sendAdbPacket(String cmd, Uint8List payload, {int arg0 = 0, int arg1 = 0}) {
     if (_deviceSocket == null) return;
     if (cmd.length != 4) {
         throw ArgumentError("Command must be 4 chars");
     }
     
     final header = ByteData(24);
     // Command
     for (int i=0; i<4; i++) {
         header.setUint8(i, cmd.codeUnitAt(i));
     }
     // Arg0, Arg1
     header.setUint32(4, arg0, Endian.little);
     header.setUint32(8, arg1, Endian.little);
     // Data length
     header.setUint32(12, payload.length, Endian.little);
     // CRC
     int crc = 0;
     for (var b in payload) {
         crc += b;
     }
     header.setUint32(16, crc, Endian.little);
     // Magic (cmd ^ 0xFFFFFFFF)
     int magic = 0;
     for (int i=0; i<4; i++) {
         magic |= (cmd.codeUnitAt(i) << (i*8));
     }
     header.setUint32(20, magic ^ 0xFFFFFFFF, Endian.little);
     
     _deviceSocket?.add(header.buffer.asUint8List());
     if (payload.isNotEmpty) {
        _deviceSocket?.add(payload);
     }
  }

  int _idCounter = 1;
  int _generateId() => _idCounter++;
}
