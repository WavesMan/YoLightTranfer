import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yolighttransfer/widgets/file_receive_dialog.dart';
import 'package:yolighttransfer/services/file/file_path_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// 文件传输请求回调
typedef FileTransferRequestCallback = Future<bool> Function(
  String senderDeviceName,
  String fileName,
  int fileSize,
);

/// 增强的 TCP 服务器：支持文件传输请求确认机制
class TcpTransferServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final _connections = <_JsonLineConnection>[];
  FileTransferRequestCallback? _onFileTransferRequest;

  bool get isRunning => _server != null;

  /// 设置文件传输请求回调
  void setFileTransferRequestCallback(FileTransferRequestCallback callback) {
    _onFileTransferRequest = callback;
  }

  Future<void> start(int port) async {
    if (_server != null) return;
    
    print('=== TCP服务器启动诊断 ===');
    print('启动端口: $port');
    print('绑定地址: InternetAddress.anyIPv4');
    print('开始启动TCP服务器...');
    
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleClient, onError: (e, st) {
        print('TCP服务器监听错误: $e');
      }, onDone: stop);
      
      print('✓ TCP服务器启动成功');
      print('服务器地址: ${_server!.address}:${_server!.port}');
      print('====================');
    } catch (e) {
      print('✗ TCP服务器启动失败: $e');
      print('启动详情: 端口 $port');
      print('====================');
      rethrow;
    }
  }

  Future<void> stop() async {
    for (final c in List<Socket>.from(_clients)) {
      await c.close();
    }
    _clients.clear();
    for (final jc in _connections) {
      jc.dispose();
    }
    _connections.clear();
    await _server?.close();
    _server = null;
  }

  void _handleClient(Socket client) {
    print('=== TCP服务器新客户端连接 ===');
    print('客户端地址: ${client.remoteAddress}:${client.remotePort}');
    print('本地地址: ${client.address}:${client.port}');
    print('连接时间: ${DateTime.now()}');
    
    _clients.add(client);
    final conn = _JsonLineConnection(client);
    _connections.add(conn);
    
    print('当前客户端数量: ${_clients.length}');
    print('====================');

    conn.frames.listen((frame) async {
      final type = frame['type'];
      switch (type) {
        case 'PING':
          conn.send({'type': 'PONG'});
          break;
        case 'HELLO':
          // 客户端握手：返回简单 ACK 确认
          conn.send({'type': 'ACK', 'for': 'HELLO'});
          break;
        case 'CANCEL':
          // 取消处理占位（待实现具体逻辑）
          break;
        case 'FILE_TRANSFER_REQUEST':
          // 处理文件传输请求
          await _handleFileTransferRequest(conn, frame);
          break;
        case 'FILE_META':
          // 示例：{type: FILE_META, name: ..., size: N, path: 可选保存路径, offset: 0}
          conn.send({'type': 'ACK', 'for': 'FILE_META'});
          break;
        case 'FILE_END':
          conn.send({'type': 'ACK', 'for': 'FILE_END'});
          break;
        default:
        // 忽略未知类型的控制帧
      }
    }, onDone: () {
      _clients.remove(client);
      _connections.remove(conn);
      conn.dispose();
    }, onError: (_) {
      _clients.remove(client);
      _connections.remove(conn);
      conn.dispose();
    });
  }

  /// 处理文件传输请求
  Future<void> _handleFileTransferRequest(_JsonLineConnection conn, Map<String, dynamic> frame) async {
    final senderDeviceName = frame['senderDeviceName'] as String? ?? '未知设备';
    final fileName = frame['fileName'] as String? ?? '未知文件';
    final fileSize = frame['fileSize'] as int? ?? 0;

    // 如果有回调函数，使用回调处理确认
    if (_onFileTransferRequest != null) {
      final accepted = await _onFileTransferRequest!(senderDeviceName, fileName, fileSize);
      if (accepted) {
        conn.send({
          'type': 'FILE_TRANSFER_ACCEPTED',
          'fileName': fileName,
          'savePath': await FilePathService.getFileSavePath(fileName),
        });
      } else {
        conn.send({
          'type': 'FILE_TRANSFER_REJECTED',
          'fileName': fileName,
        });
      }
    } else {
      // 如果没有回调，默认接受传输
      conn.send({
        'type': 'FILE_TRANSFER_ACCEPTED',
        'fileName': fileName,
        'savePath': await FilePathService.getFileSavePath(fileName),
      });
    }
  }
}

/// 套接字 JSON 行封装器：负责发送/接收按行分隔的 JSON 控制帧。
class _JsonLineConnection {
  final Socket socket;
  final StreamController<Map<String, dynamic>> _ctrl = StreamController();
  final StringBuffer _lineBuf = StringBuffer();
  late final StreamSubscription<List<int>> _sub;

  _JsonLineConnection(this.socket) {
    _sub = socket.listen(_onData, onError: _ctrl.addError, onDone: _ctrl.close);
  }

  Stream<Map<String, dynamic>> get frames => _ctrl.stream;

  void send(Map<String, dynamic> json) {
    final data = jsonEncode(json);
    socket.add(utf8.encode(data));
    socket.add([10]); // 换行符 \n 分隔一帧
    if (json['type'] == 'PING') {
      // 可在此设置 PING 超时检测等逻辑
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

  void dispose() {
    _sub.cancel();
    socket.destroy();
  }
}
