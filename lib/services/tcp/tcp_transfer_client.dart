import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// TCP 客户端：连接对端并使用“每行一个 JSON”的控制帧进行通信。
/// 提供按固定分片大小发送文件的辅助方法，并带有进度回调。
class TcpTransferClient {
  Socket? _socket;
  _JsonLinePeer? _peer;

  bool get isConnected => _socket != null;

  Future<void> connect({required String host, required int port, Duration timeout = const Duration(seconds: 5)}) async {
    if (_socket != null) return;
    
    print('=== TCP客户端连接诊断 ===');
    print('连接目标: $host:$port');
    print('连接超时: ${timeout.inSeconds}秒');
    print('开始建立TCP连接...');
    
    try {
      final s = await Socket.connect(host, port, timeout: timeout);
      _socket = s;
      _peer = _JsonLinePeer(s);
      
      print('✓ TCP连接成功建立');
      print('本地地址: ${s.address}:${s.port}');
      print('远程地址: ${s.remoteAddress}:${s.remotePort}');
      print('====================');
    } catch (e) {
      print('✗ TCP连接失败: $e');
      print('连接详情: $host:$port');
      print('====================');
      rethrow;
    }
  }

  Future<void> close() async {
    await _peer?.dispose();
    _peer = null;
    await _socket?.close();
    _socket = null;
  }

  /// 发送一条 JSON 控制帧。
  void send(Map<String, dynamic> json) {
    _peer?.send(json);
  }

  /// 监听服务端返回的控制帧。
  Stream<Map<String, dynamic>> get frames => _peer?.frames ?? const Stream.empty();

  /// 发送文件传输请求并等待确认
  Future<bool> sendFileTransferRequest({
    required String senderDeviceName,
    required String fileName,
    required int fileSize,
  }) async {
    final p = _peer;
    if (p == null) {
      throw StateError('Not connected');
    }

    // 发送文件传输请求
    p.send({
      'type': 'FILE_TRANSFER_REQUEST',
      'senderDeviceName': senderDeviceName,
      'fileName': fileName,
      'fileSize': fileSize,
    });

    // 等待响应
    final response = await p.frames.firstWhere(
      (frame) => frame['type'] == 'FILE_TRANSFER_ACCEPTED' || frame['type'] == 'FILE_TRANSFER_REJECTED',
      orElse: () => {'type': 'FILE_TRANSFER_REJECTED'},
    );

    return response['type'] == 'FILE_TRANSFER_ACCEPTED';
  }

  /// 通过套接字发送文件（在此之前会发送 FILE_META 控制帧）。
  ///
  /// 简化协议说明：
  /// 1) 发送 FILE_META（json + \n）声明文件信息；
  /// 2) 对于每个分片，先发送一行 JSON：{type: CHUNK, size: N}\n；
  /// 3) 紧接着写入 N 个原始字节；
  /// 4) 最后发送 {type: FILE_END}。
  /// 服务端需实现对应的读取逻辑与落盘处理。
  Future<void> sendFile({
    required File file,
    required String remotePath,
    int chunkSize = 1024 * 1024,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    final s = _socket;
    final p = _peer;
    if (s == null || p == null) {
      throw StateError('Not connected');
    }

    final stat = await file.stat();
    final total = stat.size;
    final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';

    // 发送文件元数据（FILE_META）声明
    p.send({
      'type': 'FILE_META',
      'name': name,
      'size': total,
      'path': remotePath,
      'offset': 0,
    });

    final raf = await file.open(mode: FileMode.read);
    int sent = 0;
    final buffer = List<int>.filled(chunkSize, 0, growable: false);
    try {
      while (true) {
        final read = await raf.readInto(buffer);
        if (read == 0) break;
        // 告知服务端即将发送的分片大小
        p.send({
          'type': 'CHUNK',
          'size': read,
        });
        // 写入本分片的原始字节数据
        s.add(buffer.sublist(0, read));
        await s.flush();
        sent += read;
        onProgress?.call(sent, total);
      }
    } finally {
      await raf.close();
    }
    p.send({'type': 'FILE_END'});
  }
}

class _JsonLinePeer {
  final Socket socket;
  final StreamController<Map<String, dynamic>> _ctrl = StreamController();
  final StringBuffer _lineBuf = StringBuffer();
  late final StreamSubscription<List<int>> _sub;

  _JsonLinePeer(this.socket) {
    _sub = socket.listen(_onData, onError: _ctrl.addError, onDone: _ctrl.close);
  }

  Stream<Map<String, dynamic>> get frames => _ctrl.stream;

  void send(Map<String, dynamic> json) {
    final data = jsonEncode(json);
    socket.add(utf8.encode(data));
    socket.add([10]); // 换行符 \n 分隔一帧
    if (json['type'] == 'PING') {
      // 可选：设置等待 PONG 的超时处理
    }
  }

  void _onData(List<int> data) {
    final text = utf8.decode(data);
    for (final ch in text.split('')) {
      if (ch == '\n') {
        final line = _lineBuf.toString();
        _lineBuf.clear();
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line);
          if (obj is Map<String, dynamic>) {
            _ctrl.add(obj);
          }
        } catch (_) {
          // 忽略格式错误的行
        }
      } else {
        _lineBuf.write(ch);
      }
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    socket.destroy();
  }
}
