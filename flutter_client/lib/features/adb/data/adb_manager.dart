
import 'strategies/adb_strategy_interface.dart';
import 'strategies/android11_wireless_strategy.dart';
import 'strategies/native_adb_strategy.dart'; // Import Native Strategy
import 'strategies/legacy_adb_strategy.dart';
import '../../../../core/crypto/rsa_key_manager.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';
import '../../../../services/adb_service.dart';

class AdbManager {
  AdbStrategyInterface? _currentStrategy;
  final RsaKeyManager _keyManager;
  final AdbService _adbService = AdbService();

  AdbManager(this._keyManager);

  Stream<AdbDevice> get discoveryStream => _discoveryController.stream;
  
  final StreamController<AdbDevice> _discoveryController = StreamController<AdbDevice>.broadcast();
  StreamSubscription? _rawDiscoverySub;
  final Map<String, AdbDevice> _deviceCache = {};

  void startDiscovery() {
    _adbService.startDiscovery();
    _rawDiscoverySub?.cancel();
    _rawDiscoverySub = _adbService.discoveryStream.listen((device) {
       // Use device NAME (mDNS service name) as the stable identity
       // PRO TIP: Differentiate based on type. If we have a CONNECTABLE device, don't overwrite with PAIRING info.
       final key = device.name;
       
       if (_deviceCache.containsKey(key)) {
         final cached = _deviceCache[key]!;
         
         // If incoming is Pairing and Cached is Connect (and valid), IGNORE the update 
         //(or maybe store it separately, but for now we want to prioritize Connect)
         if (device.type == 'pairing' && cached.type != 'pairing') {
             // Ignore pairing update if we already know how to connect
             return;
         }
         
         // Verify if port changed
         if (cached.port != device.port || cached.host != device.host || cached.type != device.type) {
             debugPrint("Device ${device.name} updated. Type: ${device.type} Port: ${device.port}");
             
             // If we are upgrading from Pairing -> Connect, or port changed, update.
             final updated = cached.copyWith(
                 port: device.port, 
                 host: device.host,
                 type: device.type
             );
             _deviceCache[key] = updated;
             _discoveryController.add(updated);
             
             // If it changed to a connectable state, try info fetch again
             if (updated.type != 'pairing') {
                 _fetchDeviceInfo(updated);
             }
         }
         // Else: No meaningful change
       } else {
         // New device found
         debugPrint("New Device Found: ${device.name} (${device.type}) at ${device.port}");
         _deviceCache[key] = device;
         _discoveryController.add(device);
         
         // If connected type, try to fetch info
         if (device.type != 'pairing') {
            _fetchDeviceInfo(device);
         }
       }
    }); 
  }

  void stopDiscovery() {
    _adbService.stopDiscovery();
    _rawDiscoverySub?.cancel();
    _deviceCache.clear();
  }
  
  Future<void> _fetchDeviceInfo(AdbDevice device) async {
     try {
        // DIAGNOSTIC START: specific info fetch via Native Layer first
        if (device.type == 'connect') {
           debugPrint("Diagnostic: Testing Native Connection to ${device.host}:${device.port}...");
           final nativeSuccess = await _adbService.testNativeConnection(device.host, device.port);
           debugPrint("Diagnostic: Native Connection Result: $nativeSuccess");
           if (nativeSuccess) {
              debugPrint("SUCCESS: Native layer CAN connect. Issue is in Dart TLS implementation.");
           } else {
              debugPrint("FAILURE: Native layer CANNOT connect. Issue is likely Keys/Auth/Network.");
              // If native fails, we probably can't do anything, but let's try connect anyway below
           }
        }
        // DIAGNOSTIC END

        // We need to connect to run shell commands. 
        // This might fail if not authenticated, but we try silently.
        await connect(device.host, device.port);
        
        final brand = (await executeCommand('getprop ro.product.brand')).trim();
        final model = (await executeCommand('getprop ro.product.model')).trim();
        
        if (brand.isNotEmpty && model.isNotEmpty) {
           final key = device.name;
           final currentCache = _deviceCache[key] ?? device;
           
           final enriched = currentCache.copyWith(brand: brand, model: model);
           _deviceCache[key] = enriched;
           
           _discoveryController.add(enriched);
           debugPrint("Enriched device info: ${enriched.displayName}");
        }
     } catch (e) {
        // Silent failure is expected for unauthorized devices
        debugPrint("Could not fetch info for ${device.host}:${device.port} : $e");
     }
  }

  // Todo: Logic to detect or select strategy
  void setStrategy(bool isAndroid11) {
    if (isAndroid11) {
      // Use Native Bridge Strategy for 100% parity
      _currentStrategy = NativeAdbStrategy();
    } else {
      _currentStrategy = LegacyAdbStrategy();
    }
  }

  Future<bool> pair(String ip, int port, String code) async {
    _ensureStrategy();
    return await _currentStrategy!.pair(ip, port, code);
  }

  Future<void> connect(String ip, int port) async {
    _ensureStrategy();
    await _currentStrategy!.connect(ip, port);
  }
  
  Future<String> executeCommand(String command) async {
    _ensureStrategy();
    return await _currentStrategy!.execute(command);
  }
  
  Future<Stream<Uint8List>> executeStream(String command) async {
    _ensureStrategy();
    return await _currentStrategy!.executeStream(command);
  }
  
  Future<void> pushFile(List<int> data, String remotePath) async {
     _ensureStrategy();
     await _currentStrategy!.push(Uint8List.fromList(data), remotePath);
  }

  void _ensureStrategy() {
    // Default to Native Strategy
    _currentStrategy ??= NativeAdbStrategy();
  }
}
