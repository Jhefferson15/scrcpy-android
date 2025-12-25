import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../models/device_model.dart';
import '../services/adb_service.dart';
import '../features/adb/data/adb_manager.dart'; 
// Wait, AdbManager takes RsaKeyManager. 
// RsaKeyManager is in core/crypto.
import '../core/crypto/rsa_key_manager.dart';
import '../widgets/dialogs/pin_pairing_dialog.dart';
import '../widgets/home/device_list_item.dart';
import '../widgets/home/legacy_connections_section.dart';

import 'settings_screen.dart';
import 'stream_screen.dart';
import '../features/adb/presentation/screens/debug_terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdbManager _adbManager = AdbManager(RsaKeyManager());
  bool _isSearching = false;
  List<Device> _devices = [];
  StreamSubscription<AdbDevice>? _discoverySubscription;
  Timer? _discoveryTimer;

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryTimer?.cancel();
    _adbManager.stopDiscovery();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _devices = [];
    });
    
    // Stop any existing discovery first
    _discoverySubscription?.cancel();
    _adbManager.stopDiscovery();

    // Listen to stream
    _discoverySubscription = _adbManager.discoveryStream.listen((adbDevice) {
       final deviceState = adbDevice.type == 'pairing' 
          ? DeviceState.locked 
          : DeviceState.unlocked; // unlocked implies connected/authorized for this simple UI mapping
          
       final isPairing = adbDevice.type == 'pairing';
       
       setState(() {
         // Avoid duplicates based on host:port
         final existingIndex = _devices.indexWhere((d) => d.ip == '${adbDevice.host}:${adbDevice.port}');
         
         final newDevice = Device(
            adbDevice.displayName, 
            '${adbDevice.host}:${adbDevice.port}', 
            deviceState,
            isPairingMode: isPairing
         );
         
         if (existingIndex >= 0) {
           _devices[existingIndex] = newDevice;
         } else {
           _devices.add(newDevice);
         }
       });
    });

    _adbManager.startDiscovery();
    
    // Auto stop after 30 seconds to save battery/resources
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
            setState(() => _isSearching = false);
            _adbManager.stopDiscovery();
        }
    });
  }
  
  void _stopSearch() {
      _discoveryTimer?.cancel();
      _adbManager.stopDiscovery();
      if (mounted) setState(() => _isSearching = false);
  }

  void _handleDeviceClick(Device device) {
     final hostPort = device.ip.split(':');
     if (hostPort.length != 2) return;
     
     final host = hostPort[0];
     final port = int.tryParse(hostPort[1]) ?? 5555;

    if (device.isPairingMode) {
      _showPinDialog(device, host, port);
    } else {
      // Connect
      _connectToDevice(host, port, device.name);
    }
  }

  Future<void> _connectToDevice(String host, int port, String deviceName) async {
       // Stop discovery before connecting
      _stopSearch();
      
      try {
          // Show loading
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting...'), duration: Duration(seconds: 1)),
            );
          }
          
          await _adbManager.connect(host, port);
          
          if (!mounted) return;
          
          Navigator.push(
             context,
             MaterialPageRoute(builder: (context) => StreamScreen(adbManager: _adbManager, deviceName: deviceName)),
          );
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connection Failed: $e'), backgroundColor: Colors.red),
            );
         }
      }
  }

  void _showPinDialog(Device device, String host, int port) {
    showDialog(
      context: context,
      builder: (dialogContext) => PinPairingDialog(
          device: device,
          onPair: (code) async {
             try {
                final success = await _adbManager.pair(host, port, code);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(success ? 'Pairing Successful!' : 'Pairing Failed'),
                        backgroundColor: success ? Colors.green : Colors.red,
                    ),
                );
                // Refresh discovery to show as connected if successful
                if (success) _startSearch();
             } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
             }
          },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(FontAwesomeIcons.mobileScreen, color: AppTheme.secondary, size: 20)
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 2000.ms, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'SCRCPY CLIENT',
              style: GoogleFonts.outfit(
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.terminal),
            tooltip: "ADB Terminal",
            onPressed: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DebugTerminalScreen(adbManager: _adbManager)),
              );
            },
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.bug),
            tooltip: "Test Fake Server",
            onPressed: () async {
               // Temporary Test Trigger
               // Address 10.0.2.2 is localhost from Android Emulator
               // Address 127.0.0.1 is localhost from Desktop?
               // The user likely has devices connected via USB or Wifi.
               // We need the device to connect to the PC running the python script.
               // Since the python script is on the PC, the device needs the PC's IP.
               // For now, let's assume the user can input it or we just try 10.0.2.2 (standard emulator) 
               // and maybe ask for IP in a dialog if needed. 
               // Let's pop a dialog to get the IP.
               
               final ipController = TextEditingController(text: "192.168.0.x"); // Default hint
               showDialog(
                 context: context, 
                 builder: (ctx) => AlertDialog(
                   title: const Text("Test Fake Server"),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Text("Ensure 'dev_tools/runner.py fake-server' is running on your PC."),
                       const SizedBox(height: 10),
                       TextField(
                         controller: ipController, 
                         decoration: const InputDecoration(labelText: "PC IP Address", hintText: "e.g. 192.168.0.24"),
                       ),
                       const Text("Port is fixed to 5555", style: TextStyle(fontSize: 12, color: Colors.grey)),
                     ],
                   ),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                     TextButton(
                       onPressed: () {
                         Navigator.pop(ctx);
                         // Trigger Connection
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => StreamScreen(
                               adbManager: _adbManager, 
                               deviceName: "Test Stream", 
                               isTestMode: true, 
                               testIp: ipController.text
                           )),
                         );
                       }, 
                       child: const Text("Connect")
                     ),
                   ],
                 )
               );
            },
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.gear),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient blobs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ).animate().scale(duration: 3000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.easeInOut).then(delay: 3000.ms).scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8), curve: Curves.easeInOut),
          
           Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withValues(alpha: 0.3),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Search Button
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isSearching ? _stopSearch : _startSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
                          foregroundColor: AppTheme.primary,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(20),
                             side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5), width: 1),
                          ),
                        ),
                        child: _isSearching 
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 16),
                              Text('Scanning (Tap to Stop)', style: GoogleFonts.outfit(fontSize: 16)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(FontAwesomeIcons.magnifyingGlass, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                'SEARCH FOR DEVICES',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 32),

                  if (_devices.isEmpty && !_isSearching)
                    Center(
                      child: Column(
                        children: [
                          Icon(FontAwesomeIcons.wifi, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 8),
                             Text(
                            'Enable "Wireless Debugging" on your device.',
                            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3), fontSize: 12),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Devices',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DeviceListItem(
                                device: _devices[index], 
                                onTap: () => _handleDeviceClick(_devices[index])
                              ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0),
                            );
                          },
                        ),
                      ],
                    ),

                  const SizedBox(height: 48),

                  const LegacyConnectionsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
