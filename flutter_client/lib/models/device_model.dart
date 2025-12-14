enum DeviceState { locked, unlocked, pairing }

class Device {
  final String name;
  final String ip;
  final DeviceState state;
  final bool isPairingMode;

  const Device(
    this.name, 
    this.ip, 
    this.state, {
    this.isPairingMode = false,
  });
}
