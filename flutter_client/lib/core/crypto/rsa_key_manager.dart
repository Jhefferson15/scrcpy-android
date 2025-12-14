import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AdbKeyPair {
  final File privateKey;
  final File certificate;

  AdbKeyPair({required this.privateKey, required this.certificate});
}

class RsaKeyManager {
  static const platform = MethodChannel('com.example.flutter_client/adb');

  Future<AdbKeyPair> getOrGenerateKey() async {
    final keyFile = await _getPrivateKeyFile();
    final pubKeyFile = await _getPublicKeyFile();

    try {
      // 1. Always Sync from Native first (Source of Truth)
      final Map<Object?, Object?>? nativeKeys = await platform.invokeMethod('getAdbKeyPair');
      if (nativeKeys != null) {
           final privBytes = (nativeKeys['privateKey'] as List<dynamic>).cast<int>();
           final certBytes = (nativeKeys['certificate'] as List<dynamic>).cast<int>();
           
           // Convert to PEM format (Required by SecurityContext)
           final privPem = _toPem(privBytes, "PRIVATE KEY");
           final certPem = _toPem(certBytes, "CERTIFICATE");
           
           // Force overwrite local cache to ensure consistency with Native (pairing source)
           await keyFile.writeAsString(privPem);
           await pubKeyFile.writeAsString(certPem);
           
           debugPrint("Keys successfully synced from Native layer.");
           // Return FILE handles
           return AdbKeyPair(
             privateKey: keyFile, 
             certificate: pubKeyFile
           );
      }
    } catch (e) {
      debugPrint("Native Key Sync Warning: $e");
    }

    // 2. Fallback to File Storage
    if (await keyFile.exists() && await pubKeyFile.exists()) {
       debugPrint("Loading keys from local cache.");
       return AdbKeyPair(
         privateKey: keyFile,
         certificate: pubKeyFile,
       );
    }
    
    throw Exception("No ADB keys found. Please restart app to generate them in Native layer.");
  }

  String _toPem(List<int> bytes, String label) {
    final base64Str = base64.encode(bytes);
    final chunks = <String>[];
    for (int i = 0; i < base64Str.length; i += 64) {
      chunks.add(base64Str.substring(i, i + 64 > base64Str.length ? base64Str.length : i + 64));
    }
    return "-----BEGIN $label-----\n${chunks.join('\n')}\n-----END $label-----\n";
  }

  Future<File> _getPrivateKeyFile() async {
    final dir = await _getStoreDir();
    return File(p.join(dir.path, 'adbkey_synced.private'));
  }
  
  Future<File> _getPublicKeyFile() async {
    final dir = await _getStoreDir();
    return File(p.join(dir.path, 'adbkey_synced.cert'));
  }

  Future<Directory> _getStoreDir() async {
     return await getApplicationSupportDirectory();
  }
}
