
class DeviceEntity {
  final String id; // IP:Port or Serial
  final String model;
  final String type; // 'wifi' or 'usb'
  bool isPaired;

  DeviceEntity({
    required this.id,
    required this.model,
    required this.type,
    this.isPaired = false,
  });
}

enum AdbConnectionState {
  disconnected,
  connecting,
  connected,
  pairing,
}
