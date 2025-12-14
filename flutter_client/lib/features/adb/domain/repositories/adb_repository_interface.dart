
import '../entities/device_entity.dart';

abstract class IAdbRepository {
  Future<void> pairDevice(String ip, int port, String pairingCode);
  Future<void> connectDevice(String ip, int port);
  Future<void> deployServer(String deviceIp);
  Stream<DeviceEntity> get discoveredDevices;
}
