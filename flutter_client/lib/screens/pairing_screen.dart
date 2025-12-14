import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/adb_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final AdbService _adbService = AdbService();
  final Set<AdbDevice> _devices = {};
  late StreamSubscription<AdbDevice> _subscription;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() {
    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });
    
    _subscription = _adbService.discoveryStream.listen((device) {
      if (mounted) {
        setState(() {
          _devices.add(device);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _showPairingDialog(AdbDevice device) async {
    final TextEditingController codeController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Pairing Code for ${device.name}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Enter the 6-digit Wi-Fi pairing code:'),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '123456',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Pair'),
              onPressed: () async {
                final code = codeController.text;
                if (code.isNotEmpty) {
                    Navigator.of(context).pop();
                    _performPairing(device, code);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performPairing(AdbDevice device, String code) async {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pairing...')),
      );

      try {
        final success = await _adbService.pair(device.host, device.port, code);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(success ? 'Pairing Successful!' : 'Pairing Failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                ),
            );
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
         }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADB Wireless Pairing'),
        actions: [
            if (_isDiscovering)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)),
                ))
            else
                IconButton(icon: const Icon(Icons.refresh), onPressed: _startDiscovery),
        ],
      ),
      body: _devices.isEmpty
          ? const Center(
              child: Text(
                'Searching for devices on local network...\n\nMake sure "Wireless Debugging" is enabled\nand "Pair with pairing code" is active.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices.toList()[index];
                return ListTile(
                  leading: Icon(
                      device.type == 'pairing' ? Icons.phonelink_setup : Icons.phonelink,
                      color: device.type == 'pairing' ? Colors.orange : Colors.green,
                  ),
                  title: Text(device.name),
                  subtitle: Text('${device.host}:${device.port} • ${device.type.toUpperCase()}'),
                  trailing: device.type == 'pairing' 
                    ? ElevatedButton(
                        child: const Text("PAIR"),
                        onPressed: () => _showPairingDialog(device),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {
                      if (device.type == 'pairing') {
                          _showPairingDialog(device);
                      }
                  },
                );
              },
            ),
    );
  }
}
