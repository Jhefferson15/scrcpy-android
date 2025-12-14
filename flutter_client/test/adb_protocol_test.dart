
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_client/features/adb/data/adb_protocol.dart';

void main() {
  group('AdbPacketTransformer Tests', () {
    test('parses a complete single packet correctly', () async {
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
      final packetData = _createPacketBytes("CNXN", 1, 2, payload);
      
      final stream = Stream.value(packetData);
      final packetStream = stream.transform(AdbPacketTransformer());
      
      final packet = await packetStream.first;
      
      expect(packet.command, "CNXN");
      expect(packet.arg0, 1);
      expect(packet.arg1, 2);
      expect(packet.payload, payload);
    });

    test('handles header fragmentation (byte by byte)', () async {
       final payload = Uint8List.fromList([0xAA]);
       final packetData = _createPacketBytes("TEST", 0, 0, payload);
       
       // Emit 1 byte at a time
       final controller = StreamController<Uint8List>();
       final packetStream = controller.stream.transform(AdbPacketTransformer());
       
       scheduleMicrotask(() async {
         for (var byte in packetData) {
           controller.add(Uint8List.fromList([byte]));
           await Future.delayed(Duration.zero); // Yield
         }
         controller.close();
       });
       
       final packet = await packetStream.first;
       expect(packet.command, "TEST");
       expect(packet.payload, payload);
    });

    test('handles combined packets (multiple packets in one chunk)', () async {
       final p1 = _createPacketBytes("CMD1", 0, 0, Uint8List(0));
       final p2 = _createPacketBytes("CMD2", 0, 0, Uint8List(0));
       
       final combined = Uint8List.fromList([...p1, ...p2]);
       final stream = Stream.value(combined).transform(AdbPacketTransformer());
       
       final packets = await stream.toList();
       expect(packets.length, 2);
       expect(packets[0].command, "CMD1");
       expect(packets[1].command, "CMD2");
    });
  });
}

Uint8List _createPacketBytes(String cmd, int arg0, int arg1, Uint8List payload) {
  final header = ByteData(24);
  for (int i=0; i<4; i++) header.setUint8(i, cmd.codeUnitAt(i));
  header.setUint32(4, arg0, Endian.little);
  header.setUint32(8, arg1, Endian.little);
  header.setUint32(12, payload.length, Endian.little);
  // CRC and Magic omitted for simple parsing test as transformer currently ignores them for speed
  return Uint8List.fromList([...header.buffer.asUint8List(), ...payload]);
}
