
import 'dart:typed_data';

abstract class AdbStrategyInterface {
  /// Pairs with the device using the specific protocol (e.g., Android 11+ Pairing)
  Future<bool> pair(String ip, int port, String code);

  /// Connects to the device and establishes a session
  Future<void> connect(String ip, int port);

  /// Executes a shell command on the connected device
  Future<String> execute(String command);

  /// Executes a shell command and returns a stream of output data
  Future<Stream<Uint8List>> executeStream(String command);

  /// Pushes a file (binary data) to the remote path
  Future<void> push(Uint8List data, String remotePath);
  
  /// Disconnects the current session
  Future<void> disconnect();
}
