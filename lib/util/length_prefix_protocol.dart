import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 长度前缀协议：[4字节长度][数据]
/// 用于统一处理控制帧（JSON）和二进制数据
class LengthPrefixProtocol {
  /// 编码帧：添加4字节长度前缀
  static List<int> encodeFrame(List<int> data) {
    final length = data.length;
    final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
    return [...lengthBytes.buffer.asUint8List(), ...data];
  }

  /// 编码JSON控制帧
  static List<int> encodeJsonFrame(Map<String, dynamic> json) {
    final data = utf8.encode(jsonEncode(json));
    return encodeFrame(data);
  }

  /// 编码二进制数据帧
  static List<int> encodeBinaryFrame(List<int> data) {
    return encodeFrame(data);
  }

  /// 从字节数据中解析长度
  static int? parseLength(List<int> data) {
    if (data.length < 4) return null;
    final lengthBytes = Uint8List.fromList(data.sublist(0, 4));
    return ByteData.view(lengthBytes.buffer).getUint32(0, Endian.big);
  }

  /// 检查是否有完整的帧
  static bool hasCompleteFrame(List<int> buffer) {
    if (buffer.length < 4) return false;
    final frameLength = parseLength(buffer);
    if (frameLength == null) return false;
    return buffer.length >= 4 + frameLength;
  }

  /// 从缓冲区提取一个完整的帧
  static List<int>? extractFrame(List<int> buffer) {
    if (!hasCompleteFrame(buffer)) return null;
    final frameLength = parseLength(buffer)!;
    return buffer.sublist(0, 4 + frameLength);
  }

  /// 从缓冲区移除一个完整的帧
  static void removeFrame(List<int> buffer) {
    if (!hasCompleteFrame(buffer)) return;
    final frameLength = parseLength(buffer)!;
    buffer.removeRange(0, 4 + frameLength);
  }

  /// 获取帧的数据部分（不包括长度前缀）
  static List<int> getFrameData(List<int> frame) {
    if (frame.length < 4) return [];
    return frame.sublist(4);
  }

  /// 尝试解析为JSON控制帧
  static Map<String, dynamic>? tryParseJsonFrame(List<int> frameData) {
    try {
      final json = jsonDecode(utf8.decode(frameData));
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (e) {
      // 不是有效的JSON，可能是二进制数据
    }
    return null;
  }
}

/// 帧读取器：从Socket读取完整的帧
class FrameReader {
  final Socket socket;
  final List<int> _buffer = [];
  late final StreamSubscription<List<int>> _subscription;
  final _frameController = StreamController<List<int>>();

  FrameReader(this.socket) {
    _subscription = socket.listen(
      _onData,
      onError: _frameController.addError,
      onDone: _frameController.close,
    );
  }

  /// 获取帧流
  Stream<List<int>> get frames => _frameController.stream;

  void _onData(List<int> data) {
    _buffer.addAll(data);
    
    // 提取所有完整的帧
    while (LengthPrefixProtocol.hasCompleteFrame(_buffer)) {
      final frame = LengthPrefixProtocol.extractFrame(_buffer);
      if (frame != null) {
        _frameController.add(frame);
        LengthPrefixProtocol.removeFrame(_buffer);
      } else {
        break;
      }
    }
  }

  /// 读取下一个完整的帧
  Future<List<int>> readFrame({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      return await frames.first.timeout(timeout);
    } catch (e) {
      throw TimeoutException('读取帧超时', timeout);
    }
  }

  /// 读取并解析为JSON控制帧
  Future<Map<String, dynamic>> readJsonFrame({Duration timeout = const Duration(seconds: 30)}) async {
    final frame = await readFrame(timeout: timeout);
    final frameData = LengthPrefixProtocol.getFrameData(frame);
    final json = LengthPrefixProtocol.tryParseJsonFrame(frameData);
    
    if (json == null) {
      throw FormatException('无法解析为JSON控制帧');
    }
    
    return json;
  }

  /// 读取二进制数据帧
  Future<List<int>> readBinaryFrame({Duration timeout = const Duration(seconds: 30)}) async {
    final frame = await readFrame(timeout: timeout);
    return LengthPrefixProtocol.getFrameData(frame);
  }

  /// 释放资源
  void dispose() {
    _subscription.cancel();
    _frameController.close();
  }
}

/// 帧写入器：向Socket写入完整的帧
class FrameWriter {
  final Socket socket;

  FrameWriter(this.socket);

  /// 写入JSON控制帧
  void writeJsonFrame(Map<String, dynamic> json) {
    try {
      final frameData = LengthPrefixProtocol.encodeJsonFrame(json);
      socket.add(frameData);
    } catch (e) {
      print('写入JSON帧失败: $e');
      rethrow;
    }
  }

  /// 写入二进制数据帧
  void writeBinaryFrame(List<int> data) {
    try {
      final frameData = LengthPrefixProtocol.encodeBinaryFrame(data);
      socket.add(frameData);
    } catch (e) {
      print('写入二进制帧失败: $e');
      rethrow;
    }
  }

  /// 刷新缓冲区
  Future<void> flush() async {
    try {
      await socket.flush();
    } catch (e) {
      print('刷新缓冲区失败: $e');
      rethrow;
    }
  }
}
