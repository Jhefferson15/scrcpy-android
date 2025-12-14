
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Assuming Riverpod usage as per prompt suggestion

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pair New Device")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Enter Wireless Debugging Details"),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: "IP Address"),
            ),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: "Pairing Port"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: "Pairing Code (6 digits)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _onPair,
              child: _isLoading ? const CircularProgressIndicator() : const Text("Pair"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _onPair() async {
    setState(() => _isLoading = true);
    try {
      // Access AdbManager via provider/riverpod (mocked access here)
      // final adbManager = ref.read(adbManagerProvider);
      // await adbManager.pair(_ipController.text, int.parse(_portController.text), _codeController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pairing Successful!")));
      // Navigate to Connection screen or updated list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
