import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/adb_manager.dart';

class DebugTerminalScreen extends ConsumerStatefulWidget {
  final AdbManager adbManager;

  const DebugTerminalScreen({super.key, required this.adbManager});

  @override
  ConsumerState<DebugTerminalScreen> createState() => _DebugTerminalScreenState();
}

class _DebugTerminalScreenState extends ConsumerState<DebugTerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isLoading = false;

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runCommand() async {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _isLoading = true;
    });
    _log("> $cmd");
    _commandController.clear();

    try {
      final result = await widget.adbManager.executeCommand(cmd);
      _log(result);
    } catch (e) {
      _log("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADB Terminal"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(
                      color: Colors.greenAccent, 
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      hintText: "Enter ADB shell command...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _runCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _runCommand,
                  icon: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) 
                    : const Icon(Icons.send),
                ),
              ],
            ),
          ),
          // Quick Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _QuickButton("ls -l /data/local/tmp", (cmd) { _commandController.text = cmd; _runCommand(); }),
                _QuickButton("getprop ro.product.model", (cmd) { _commandController.text = cmd; _runCommand(); }),
                _QuickButton("pm list packages", (cmd) { _commandController.text = cmd; _runCommand(); }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String cmd;
  final Function(String) onTap;
  const _QuickButton(this.cmd, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(cmd),
        onPressed: () => onTap(cmd),
      ),
    );
  }
}
