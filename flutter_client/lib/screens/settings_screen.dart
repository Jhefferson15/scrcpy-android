import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_container.dart';
import '../core/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _bitrate = 8;
  double _fps = 60;
  bool _stayAwake = true;
  bool _turnScreenOff = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
           // Background Blobs (Different positions for variety)
           Positioned(
            top: 100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader('Video Quality'),
                GlassContainer(
                  color: AppTheme.surface,
                  opacity: 0.5,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSliderRow(
                        'Bitrate', 
                        '${_bitrate.toInt()} Mbps', 
                        _bitrate, 
                        2, 
                        50, 
                        (v) => setState(() => _bitrate = v),
                        Icons.speed,
                      ),
                      const SizedBox(height: 24),
                      _buildSliderRow(
                        'Max FPS', 
                        '${_fps.toInt()}', 
                        _fps, 
                        30, 
                        120, 
                        (v) => setState(() => _fps = v),
                        Icons.slow_motion_video,
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.1, end: 0, delay: 100.ms).fadeIn(),

                const SizedBox(height: 32),

                _buildSectionHeader('Device Control'),
                GlassContainer(
                  color: AppTheme.surface,
                  opacity: 0.5,
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    children: [
                      _buildSwitchTile('Stay Awake', 'Keep device awake while connected', _stayAwake, (v) => setState(() => _stayAwake = v)),
                      Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                      _buildSwitchTile('Turn Screen Off', 'Turn off device screen on connection', _turnScreenOff, (v) => setState(() => _turnScreenOff = v)),
                    ],
                  ),
                ).animate().slideY(begin: 0.1, end: 0, delay: 200.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, String value, double current, double min, double max, Function(double) onChanged, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.secondary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value, style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: AppTheme.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: current,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppTheme.accent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}
