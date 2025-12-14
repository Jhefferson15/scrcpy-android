import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../glass_container.dart';

class LegacyConnectionsSection extends StatelessWidget {
  const LegacyConnectionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Legacy Connections',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('COMING SOON',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(20),
            color: Colors.black,
            opacity: 0.2,
            child: Column(
              children: [
                _buildLegacyItem(FontAwesomeIcons.usb, 'USB Connection'),
                const Divider(color: Colors.white10),
                _buildLegacyItem(
                    FontAwesomeIcons.networkWired, 'ADB TCP/IP (Standard)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(color: Colors.white38)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
        ],
      ),
    );
  }
}
