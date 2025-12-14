import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../glass_container.dart';
import '../../models/device_model.dart';

class PinPairingDialog extends StatefulWidget {
  final Device device;
  final Function(String) onPair;

  const PinPairingDialog({super.key, required this.device, required this.onPair});

  @override
  State<PinPairingDialog> createState() => _PinPairingDialogState();
}

class _PinPairingDialogState extends State<PinPairingDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        color: AppTheme.surface,
        opacity: 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pairing Request',
              style:
                  GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the Wi-Fi pairing code for ${widget.device.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 24, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final code = _controller.text;
                    if (code.length >= 6) {
                        Navigator.pop(context);
                        widget.onPair(code);
                    }
                  },
                  child: const Text('Pair & Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
