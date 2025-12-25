import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/glass_container.dart';
import '../core/app_theme.dart';
import '../features/adb/data/adb_manager.dart';
import '../features/remote_control/services/native_decoder_bridge.dart';
import '../features/remote_control/services/server_runner.dart';
import 'package:flutter/services.dart';

class StreamScreen extends StatefulWidget {
  final AdbManager? adbManager;
  final String deviceName;
  final bool isTestMode;
  final String? testIp;

  const StreamScreen({
    super.key, 
    this.adbManager, 
    this.deviceName = 'Unknown Device',
    this.isTestMode = false,
    this.testIp,
  });

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  bool _showControls = true;
  int? _textureId;
  final NativeDecoderBridge _decoder = NativeDecoderBridge();
  bool _isConnected = false;
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
     try {
        if (!widget.isTestMode && widget.adbManager == null) {
           setState(() => _statusMessage = "No ADB Manager provided");
           return;
        }

        if (widget.isTestMode) {
            setState(() => _statusMessage = "Initializing Decoder (Test Mode)...");
            final int textureId = await _decoder.initializeSurface();
            
            setState(() {
               _textureId = textureId;
               _statusMessage = "Connecting to Fake Server...";
            });

            final ip = widget.testIp ?? "10.0.2.2";
            const port = 5555;
            await _decoder.startTcpSession(ip, port);
            setState(() => _statusMessage = "Connected (TCP Test: $ip:$port)");
        } else {
            // Get resolution BEFORE initializing decoder
            setState(() => _statusMessage = "Querying device resolution...");
            final runner = ServerRunner();
            
            // ServerRunner now returns the stream resolution
            setState(() => _statusMessage = "Deploying server...");
            final resolution = await runner.deployAndRun(widget.adbManager!, _decoder);
            
            // Initialize decoder with correct resolution
            setState(() => _statusMessage = "Initializing Decoder...");
            final int textureId = await _decoder.initializeSurface(
              width: resolution['width']!,
              height: resolution['height']!,
            );
            
            setState(() {
               _textureId = textureId;
               _statusMessage = "Connected (${resolution['width']}x${resolution['height']})";
            });
        }

        setState(() {
           _isConnected = true;
        });

     } catch (e) {
        if (mounted) setState(() => _statusMessage = "Error: $e");
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Stream Content
            Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: const Color(0xFF050505),
                child: _textureId != null && _isConnected
                    ? Texture(textureId: _textureId!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isConnected)
                              const Icon(FontAwesomeIcons.signal, size: 64, color: Colors.white24)
                                  .animate(onPlay: (c) => c.repeat())
                                  .shimmer(duration: 2000.ms, color: AppTheme.primary),
                            const SizedBox(height: 24),
                            Text(
                              _statusMessage,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Top Bar
            AnimatedPositioned(
              duration: 300.ms,
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: GlassContainer(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                opacity: 0.3,
                color: Colors.black,
                border: Border.all(color: Colors.transparent),
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.deviceName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    _buildStreamStat('FPS', '60'), // TODO: Real stats
                    const SizedBox(width: 16),
                    _buildStreamStat('BITRATE', '8 Mbps'), // TODO: Real stats
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            AnimatedPositioned(
              duration: 300.ms,
              bottom: _showControls ? 30 : -100,
              left: 20,
              right: 20,
              child: GlassContainer(
                opacity: 0.3,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControl(FontAwesomeIcons.caretLeft, () {}), // Back
                    _buildControl(FontAwesomeIcons.house, () {}), // Home
                    _buildControl(FontAwesomeIcons.square, () {}), // Recent
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: onTap,
      style: IconButton.styleFrom(
        hoverColor: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildStreamStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8)),
      ],
    );
  }
}

