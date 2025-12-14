import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/app_theme.dart';
import '../../models/device_model.dart';
import '../glass_container.dart';

class DeviceListItem extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const DeviceListItem({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        color: AppTheme.surface,
        opacity: 0.4,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.state == DeviceState.unlocked
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  FontAwesomeIcons.android,
                  color: device.state == DeviceState.unlocked
                      ? AppTheme.primary
                      : Colors.white54,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    device.ip,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Status Icons
            Row(
              children: [
                if (device.isPairingMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: const Icon(
                      FontAwesomeIcons.wifi,
                      color: AppTheme.secondary,
                      size: 16,
                    ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 1000.ms).then().fadeOut(duration: 1000.ms),
                  ),

                Icon(
                  device.state == DeviceState.unlocked
                      ? FontAwesomeIcons.lockOpen
                      : FontAwesomeIcons.lock,
                  color: device.state == DeviceState.unlocked
                      ? Colors.green
                      : AppTheme.error,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
