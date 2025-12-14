import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class AdbPacket {
  final String command;
  final int arg0;
  final int arg1;
  final Uint8List payload;

  AdbPacket(this.command, this.arg0, this.arg1, this.payload);

  @override
  String toString() => 'AdbPacket(cmd: $command, arg0: $arg0, arg1: $arg1, len: ${payload.length})';
}

/// Transforms a stream of raw bytes (Uint8List) into a stream of [AdbPacket]s.
/// Handles fragmentation (header split across chunks, payload split across chunks, etc.)
class AdbPacketTransformer extends StreamTransformerBase<Uint8List, AdbPacket> {
  @override
  Stream<AdbPacket> bind(Stream<Uint8List> stream) {
    return _AdbPacketStream(stream).stream;
  }
}

class _AdbPacketStream {
  final StreamController<AdbPacket> _controller = StreamController<AdbPacket>();
  final Stream<Uint8List> _source;
  
  // Buffer state
  final List<int> _buffer = [];
  
  // Parsing state
  bool _readingHeader = true;
  String? _currentCmd;
  int? _currentArg0;
  int? _currentArg1;
  int? _currentPayloadLen;
  
  _AdbPacketStream(this._source) {
    _source.listen(
      _onData,
      onError: _controller.addError,
      onDone: _controller.close,
      cancelOnError: true,
    );
  }

  Stream<AdbPacket> get stream => _controller.stream;

  void _onData(Uint8List chunk) {
    _buffer.addAll(chunk);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      if (_readingHeader) {
        // ADB Header is 24 bytes
        if (_buffer.length >= 24) {
          final headerBytes = Uint8List.fromList(_buffer.sublist(0, 24));
          _parseHeader(headerBytes);
          
          // Remove header from buffer
          _buffer.removeRange(0, 24);
          _readingHeader = false;
        } else {
          // Not enough data for header
          break;
        }
      } else {
        // Reading Payload
        if (_buffer.length >= _currentPayloadLen!) {
          final payloadBytes = Uint8List.fromList(_buffer.sublist(0, _currentPayloadLen!));
          
          // Emit packet
          final packet = AdbPacket(_currentCmd!, _currentArg0!, _currentArg1!, payloadBytes);
          _controller.add(packet);
          
          // Remove payload from buffer
          _buffer.removeRange(0, _currentPayloadLen!);
          
          // Reset state for next packet
          _readingHeader = true;
          _currentCmd = null;
          _currentArg0 = null;
          _currentArg1 = null;
          _currentPayloadLen = null;
        } else {
          // Not enough data for payload
          break;
        }
      }
    }
  }

  void _parseHeader(Uint8List header) {
    final view = ByteData.sublistView(header);
    
    // 0-3: Command
    _currentCmd = String.fromCharCodes(header.sublist(0, 4));
    
    // 4-7: arg0
    _currentArg0 = view.getUint32(4, Endian.little);
    
    // 8-11: arg1
    _currentArg1 = view.getUint32(8, Endian.little);
    
    // 12-15: data_length
    _currentPayloadLen = view.getUint32(12, Endian.little);
    
    // 16-19: data_crc (unused for now)
    
    // 20-23: magic (unused for now)
    
    // debugPrint("Parsed Header: $_currentCmd args: $_currentArg0/$_currentArg1 len: $_currentPayloadLen");
  }
}
