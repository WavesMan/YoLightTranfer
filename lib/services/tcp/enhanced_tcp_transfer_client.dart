import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';

/// 增强的 TCP 客户端：集成日志记录功能
class EnhancedTcpTransferClient {
  Socket? _socket;
  _JsonLinePeer? _peer;
  String? _currentLogId;
  TransferLogManager? _logManager;

  bool get isConnected => _socket != null;

  /// 设置日志管理器
  void setLogManager(TransferLogManager logManager) {
    _logManager = logManager;
  }

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
      
      // 监听连接错误
      s.done.then((_) {
        print('TCP连接已断开');
        _socket = null;
        _peer = null;
      }).catchError((e) {
        print('TCP连接错误: $e');
        _socket = null;
        _peer = null;
      });
      
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

  /// 发送文件传输请求并等待确认（带日志记录）
  Future<bool> sendFileTransferRequest({
    required String senderDeviceName,
    required String fileName,
    required int fileSize,
    required String filePath,
    required DiscoveredDevice targetDevice,
  }) async {
    final p = _peer;
    if (p == null) {
      throw StateError('Not connected');
    }

    // 记录发送开始日志
    _currentLogId = '${DateTime.now().millisecondsSinceEpoch}_send_${fileName.hashCode}';
    _logManager?.addSendStartLog(
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      targetDevice: targetDevice,
    );

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

    final accepted = response['type'] == 'FILE_TRANSFER_ACCEPTED';
    
    if (!accepted) {
      // 记录传输被拒绝日志
      _logManager?.addErrorLog(
        type: TransferLogType.send,
        fileName: fileName,
        error: '对方拒绝了文件传输请求',
        targetDevice: targetDevice,
      );
    }

    return accepted;
  }

  /// 通过套接字发送文件（带进度日志记录）
  Future<void> sendFile({
    required File file,
    required String remotePath,
    required DiscoveredDevice targetDevice,
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
    final startTime = DateTime.now();
    
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
        
        // 计算传输速度和预计时间
        final progress = (sent / total * 100).round();
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        final transferSpeed = elapsed > 0 ? (sent / elapsed / 1024).toStringAsFixed(1) : '0.0';
        final remainingBytes = total - sent;
        final estimatedTime = elapsed > 0 ? (remainingBytes / (sent / elapsed)).round() : 0;
        final eta = estimatedTime > 0 ? '${estimatedTime}s' : '计算中...';
        
        // 记录进度日志
        if (_currentLogId != null) {
          _logManager?.addProgressLog(
            logId: _currentLogId!,
            type: TransferLogType.send,
            fileName: name,
            progress: progress,
            transferSpeed: '$transferSpeed KB/s',
            estimatedTime: eta,
          );
        }
        
        onProgress?.call(sent, total);
      }
    } finally {
      await raf.close();
    }
    
    // 发送文件结束标记
    p.send({'type': 'FILE_END'});
    
    // 等待接收端的确认响应
    try {
      // 使用一次性Stream监听，避免重复监听问题
      final ackResponse = await p.frames
          .where((frame) => frame['type'] == 'ACK' && frame['for'] == 'FILE_END')
          .first
          .timeout(Duration(seconds: 10));
      
      print('✓ 收到接收端文件传输完成确认');
      
      // 检查文件传输结果
      final fileValid = ackResponse['fileValid'] ?? false;
      final hashValid = ackResponse['hashValid'] ?? false;
      
      if (fileValid && hashValid) {
        print('✓ 文件传输验证成功');
      } else {
        print('⚠ 文件传输完成但验证失败');
      }
      
    } catch (e) {
      print('✗ 等待接收端确认超时或失败: $e');
      // 记录错误日志
      _logManager?.addErrorLog(
        type: TransferLogType.send,
        fileName: name,
        error: '等待接收端确认失败: $e',
        targetDevice: targetDevice,
      );
      return;
    }
    
    // 记录传输完成日志
    if (_currentLogId != null) {
      _logManager?.addCompleteLog(
        logId: _currentLogId!,
        type: TransferLogType.send,
        fileName: name,
        fileSize: total,
        filePath: file.path,
        targetDevice: targetDevice,
      );
    }
  }

  /// 记录传输错误
  void logTransferError({
    required String fileName,
    required String error,
    required DiscoveredDevice targetDevice,
  }) {
    _logManager?.addErrorLog(
      type: TransferLogType.send,
      fileName: fileName,
      error: error,
      targetDevice: targetDevice,
    );
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
