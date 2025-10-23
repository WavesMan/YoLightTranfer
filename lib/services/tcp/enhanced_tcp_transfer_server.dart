import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:yolighttransfer/services/file/file_path_service.dart';
import 'package:yolighttransfer/services/file/file_hash_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// 文件传输请求回调
typedef FileTransferRequestCallback = Future<bool> Function(
  String senderDeviceName,
  String fileName,
  int fileSize,
);

class _DigestCollector implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

/// 增强的 TCP 服务器：支持完整的文件传输流程
class EnhancedTcpTransferServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final _connections = <_EnhancedJsonLineConnection>[];
  FileTransferRequestCallback? _onFileTransferRequest;
  TransferLogManager? _logManager;

  bool get isRunning => _server != null;

  /// 设置文件传输请求回调
  void setFileTransferRequestCallback(FileTransferRequestCallback callback) {
    _onFileTransferRequest = callback;
  }

  /// 设置日志管理器
  void setLogManager(TransferLogManager logManager) {
    _logManager = logManager;
  }

  Future<void> start(int port) async {
    if (_server != null) return;
    
    print('=== 增强TCP服务器启动诊断 ===');
    print('启动端口: $port');
    print('绑定地址: InternetAddress.anyIPv4');
    print('开始启动增强TCP服务器...');
    
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleClient, onError: (e, st) {
        print('增强TCP服务器监听错误: $e');
      }, onDone: stop);
      
      print('✓ 增强TCP服务器启动成功');
      print('服务器地址: ${_server!.address}:${_server!.port}');
      print('====================');
    } catch (e) {
      print('✗ 增强TCP服务器启动失败: $e');
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
    print('=== 增强TCP服务器新客户端连接 ===');
    print('客户端地址: ${client.remoteAddress}:${client.remotePort}');
    print('本地地址: ${client.address}:${client.port}');
    print('连接时间: ${DateTime.now()}');
    
    _clients.add(client);
    final conn = _EnhancedJsonLineConnection(client);
    _connections.add(conn);
    
    print('当前客户端数量: ${_clients.length}');
    print('====================');

    // 记录TCP连接建立日志
    _logManager?.addTcpLog(
      message: 'TCP连接建立 - 客户端 ${client.remoteAddress.address}:${client.remotePort} 已连接',
      clientAddress: client.remoteAddress.address,
    );
    
    // 记录网络状态日志
    _logManager?.addNetworkLog(
      message: '网络连接建立 - 客户端 ${client.remoteAddress.address}:${client.remotePort}',
      clientAddress: client.remoteAddress.address,
      connectionState: 'ESTABLISHED',
    );

    // 启动连接保活检测
    final keepAliveTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_clients.contains(client)) {
        timer.cancel();
        return;
      }
      
      // 发送心跳包
      try {
        conn.send({'type': 'PING', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      } catch (e) {
        print('发送心跳包失败: $e');
        timer.cancel();
        _clients.remove(client);
        _connections.remove(conn);
        conn.dispose();
      }
    });

    // 监听控制帧
    conn.frames.listen((frame) async {
      final type = frame['type'];
      switch (type) {
        case 'PING':
          conn.send({'type': 'PONG'});
          _logManager?.addLog(TransferLog.tcp(
            message: '收到PING请求，发送PONG响应',
            clientAddress: client.remoteAddress.address,
          ));
          break;
        case 'PONG':
          // 心跳响应，更新连接状态
          _logManager?.addLog(TransferLog.tcp(
            message: '收到PONG响应，连接正常',
            clientAddress: client.remoteAddress.address,
          ));
          break;
        case 'HELLO':
          conn.send({'type': 'ACK', 'for': 'HELLO'});
          _logManager?.addLog(TransferLog.tcp(
            message: '收到HELLO握手，发送ACK响应',
            clientAddress: client.remoteAddress.address,
          ));
          break;
        case 'CANCEL':
          // 取消处理占位（待实现具体逻辑）
          _logManager?.addLog(TransferLog.tcp(
            message: '收到传输取消请求',
            clientAddress: client.remoteAddress.address,
          ));
          break;
        case 'FILE_TRANSFER_REQUEST':
          // 处理文件传输请求
          await _handleFileTransferRequest(conn, frame);
          break;
        case 'FILE_META':
          // 开始接收文件数据
          await _handleFileMeta(conn, frame);
          break;
        case 'CHUNK':
          // 准备接收文件分片
          await _handleChunk(conn, frame);
          break;
        case 'FILE_END':
          // 完成文件接收
          await _handleFileEnd(conn, frame);
          break;
        default:
          // 忽略未知类型的控制帧
          _logManager?.addLog(TransferLog.tcp(
            message: '收到未知控制帧类型: $type',
            clientAddress: client.remoteAddress.address,
          ));
      }
    }, onDone: () {
      keepAliveTimer.cancel();
      _logManager?.addLog(TransferLog.tcp(
        message: '客户端 ${client.remoteAddress.address}:${client.remotePort} 连接已断开',
        clientAddress: client.remoteAddress.address,
      ));
      _clients.remove(client);
      _connections.remove(conn);
      conn.dispose();
    }, onError: (error) {
      keepAliveTimer.cancel();
      _logManager?.addLog(TransferLog.tcp(
        message: '客户端连接错误: $error',
        clientAddress: client.remoteAddress.address,
      ));
      _clients.remove(client);
      _connections.remove(conn);
      conn.dispose();
    });
  }

  /// 处理文件传输请求
  Future<void> _handleFileTransferRequest(_EnhancedJsonLineConnection conn, Map<String, dynamic> frame) async {
    final senderDeviceName = frame['senderDeviceName'] as String? ?? '未知设备';
    final fileName = frame['fileName'] as String? ?? '未知文件';
    final fileSize = frame['fileSize'] as int? ?? 0;

    // 记录接收开始日志
    final savePath = await FilePathService.getFileSavePath(fileName);
    _logManager?.addReceiveStartLog(
      fileName: fileName,
      fileSize: fileSize,
      savePath: savePath,
      sourceDevice: DiscoveredDevice(
        id: 'unknown_${senderDeviceName.hashCode}',
        name: senderDeviceName,
        os: 'unknown',
        ip: conn.socket.remoteAddress.address,
        tcpPort: conn.socket.remotePort,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
        networkInterface: 'unknown',
        networkType: 'unknown',
      ),
    );

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

  /// 处理文件元数据
  Future<void> _handleFileMeta(_EnhancedJsonLineConnection conn, Map<String, dynamic> frame) async {
    final fileName = frame['name'] as String? ?? 'unknown';
    final fileSize = frame['size'] as int? ?? 0;
    final remotePath = frame['path'] as String? ?? fileName;
    final expectedHash = frame['hash'] as String?; // 发送端提供的文件哈希

    print('开始接收文件: $fileName, 大小: $fileSize bytes');
    if (expectedHash != null) {
      print('发送端提供文件哈希: ${FileHashService.formatHashForDisplay(expectedHash)}');
    }

    // 设置当前接收的文件信息
    conn.currentFileName = fileName;
    conn.currentFileSize = fileSize;
    conn.currentSavePath = await FilePathService.getFileSavePath(fileName);
    conn.expectedFileHash = expectedHash;

    print('文件保存路径: ${conn.currentSavePath}');

    try {
      // 创建文件输出流
      conn.currentFileStream = File(conn.currentSavePath!).openWrite();
      print('文件输出流创建成功');
    } catch (e) {
      print('创建文件输出流失败: $e');
      // 发送错误响应
      conn.send({'type': 'ERROR', 'message': '无法创建文件: $e'});
      return;
    }

    // 初始化哈希计算器用于实时校验
    conn.hashDigestSink = _DigestCollector();
    conn.hashByteSink = sha256.startChunkedConversion(conn.hashDigestSink!);

    // 记录哈希校验开始日志
    if (expectedHash != null) {
      _logManager?.addLog(TransferLog.info(
        message: '开始文件哈希校验，预期哈希: ${FileHashService.formatHashForDisplay(expectedHash)}',
        fileName: fileName,
      ));
    }

    conn.send({'type': 'ACK', 'for': 'FILE_META'});
  }

  /// 处理文件分片
  Future<void> _handleChunk(_EnhancedJsonLineConnection conn, Map<String, dynamic> frame) async {
    final chunkSize = frame['size'] as int? ?? 0;
    
    if (chunkSize > 0) {
      try {
        // 等待接收指定大小的二进制数据
        final data = await conn.readBinaryData(chunkSize);
        if (data != null && conn.currentFileStream != null) {
          // 写入数据并立即flush确保数据落盘
          conn.currentFileStream!.add(data);
          await conn.currentFileStream!.flush(); // 关键修复：确保数据写入磁盘
          conn.receivedBytes += data.length;

          // 实时计算哈希值
          if (conn.hashByteSink != null) {
            conn.hashByteSink!.add(data);
          }

          // 计算进度
          final progress = (conn.receivedBytes / conn.currentFileSize! * 100).round();
          print('文件接收进度: $progress% ($conn.receivedBytes/$conn.currentFileSize bytes)');

          // 记录进度日志
          _logManager?.addProgressLog(
            logId: '${DateTime.now().millisecondsSinceEpoch}_receive_${conn.currentFileName.hashCode}',
            type: TransferLogType.receive,
            fileName: conn.currentFileName!,
            progress: progress,
            transferSpeed: '计算中...',
            estimatedTime: '计算中...',
          );

          // 每接收10%记录一次哈希校验进度
          if (progress % 10 == 0 && conn.expectedFileHash != null) {
            _logManager?.addLog(TransferLog.info(
              message: '文件接收进度 $progress%，哈希校验进行中...',
              fileName: conn.currentFileName!,
            ));
          }
        }
      } catch (e) {
        print('文件分片写入失败: $e');
        _logManager?.addErrorLog(
          type: TransferLogType.receive,
          fileName: conn.currentFileName ?? '未知文件',
          error: '文件写入失败: $e',
          sourceDevice: DiscoveredDevice(
            id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
            name: '远程设备',
            os: 'unknown',
            ip: conn.socket.remoteAddress.address,
            tcpPort: conn.socket.remotePort,
            lastSeenMs: DateTime.now().millisecondsSinceEpoch,
            networkInterface: 'unknown',
            networkType: 'unknown',
          ),
        );
        // 发送错误响应
        conn.send({'type': 'ERROR', 'message': '文件写入失败: $e'});
        return;
      }
    }

    conn.send({'type': 'ACK', 'for': 'CHUNK'});
  }

  /// 处理文件结束
  Future<void> _handleFileEnd(_EnhancedJsonLineConnection conn, Map<String, dynamic> frame) async {
    print('文件接收完成: ${conn.currentFileName}');

    // 关闭文件输出流
    if (conn.currentFileStream != null) {
      await conn.currentFileStream!.close();
      conn.currentFileStream = null;
    }

    // 检查文件完整性
    bool fileValid = false;
    String? fileHash;
    bool hashValid = false;
    
    if (conn.currentFileName != null && conn.currentSavePath != null) {
      try {
        // 验证文件大小
        final receivedFile = File(conn.currentSavePath!);
        final actualFileSize = await receivedFile.length();
        
        if (actualFileSize == 0) {
          print('警告：接收的文件大小为0KB，可能写入失败');
          _logManager?.addErrorLog(
            type: TransferLogType.receive,
            fileName: conn.currentFileName!,
            error: '文件大小为0KB，写入失败',
            sourceDevice: DiscoveredDevice(
              id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
              name: '远程设备',
              os: 'unknown',
              ip: conn.socket.remoteAddress.address,
              tcpPort: conn.socket.remotePort,
              lastSeenMs: DateTime.now().millisecondsSinceEpoch,
              networkInterface: 'unknown',
              networkType: 'unknown',
            ),
          );
          
          // 删除无效文件
          await receivedFile.delete();
          print('已删除无效的0KB文件: ${conn.currentSavePath}');
          
          // 发送错误响应
          conn.send({
            'type': 'ERROR', 
            'message': '文件写入失败：接收的文件大小为0KB'
          });
          return;
        }
        
        // 检查文件大小是否匹配
        if (actualFileSize != conn.currentFileSize) {
          print('警告：文件大小不匹配，预期: ${conn.currentFileSize}, 实际: $actualFileSize');
          _logManager?.addErrorLog(
            type: TransferLogType.receive,
            fileName: conn.currentFileName!,
            error: '文件大小不匹配，预期: ${conn.currentFileSize}, 实际: $actualFileSize',
            sourceDevice: DiscoveredDevice(
              id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
              name: '远程设备',
              os: 'unknown',
              ip: conn.socket.remoteAddress.address,
              tcpPort: conn.socket.remotePort,
              lastSeenMs: DateTime.now().millisecondsSinceEpoch,
              networkInterface: 'unknown',
              networkType: 'unknown',
            ),
          );
        } else {
          fileValid = true;
          print('✓ 文件大小验证通过: $actualFileSize bytes');
          
          // 计算文件哈希值
          try {
            // 使用实时计算的哈希值
            if (conn.hashByteSink != null) {
              conn.hashByteSink!.close();
              final digest = conn.hashDigestSink?.value;
              if (digest != null) {
                fileHash = digest.toString();
                print('✓ 实时计算文件SHA256哈希: ${FileHashService.formatHashForDisplay(fileHash)}');
              } else {
                print('警告：未能获取到实时计算的哈希值，改为对已保存文件重新计算...');
                fileHash = await FileHashService.calculateFileHash(conn.currentSavePath!);
                print('✓ 重新计算文件SHA256哈希: ${FileHashService.formatHashForDisplay(fileHash)}');
              }
              
              // 验证哈希值是否匹配
              if (conn.expectedFileHash != null) {
                hashValid = fileHash == conn.expectedFileHash;
                if (hashValid) {
                  print('✓ 文件哈希校验通过');
                  _logManager?.addLog(TransferLog.info(
                    message: '文件哈希校验通过，文件完整性验证成功',
                    fileName: conn.currentFileName!,
                  ));
                } else {
                  print('✗ 文件哈希校验失败，预期: ${FileHashService.formatHashForDisplay(conn.expectedFileHash!)}，实际: ${FileHashService.formatHashForDisplay(fileHash)}');
                  _logManager?.addErrorLog(
                    type: TransferLogType.receive,
                    fileName: conn.currentFileName!,
                    error: '文件哈希校验失败，文件可能损坏',
                    sourceDevice: DiscoveredDevice(
                      id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
                      name: '远程设备',
                      os: 'unknown',
                      ip: conn.socket.remoteAddress.address,
                      tcpPort: conn.socket.remotePort,
                      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
                      networkInterface: 'unknown',
                      networkType: 'unknown',
                    ),
                  );
                }
              }
            } else {
              // 如果没有实时计算，使用文件哈希服务
              fileHash = await FileHashService.calculateFileHash(conn.currentSavePath!);
              print('✓ 文件SHA256哈希: ${FileHashService.formatHashForDisplay(fileHash)}');
            }
          } catch (e) {
            print('计算文件哈希失败: $e');
          }
        }
        
        // 记录传输完成日志
        _logManager?.addCompleteLog(
          logId: '${DateTime.now().millisecondsSinceEpoch}_receive_${conn.currentFileName.hashCode}',
          type: TransferLogType.receive,
          fileName: conn.currentFileName!,
          fileSize: actualFileSize,
          savePath: conn.currentSavePath!,
          sourceDevice: DiscoveredDevice(
            id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
            name: '远程设备',
            os: 'unknown',
            ip: conn.socket.remoteAddress.address,
            tcpPort: conn.socket.remotePort,
            lastSeenMs: DateTime.now().millisecondsSinceEpoch,
            networkInterface: 'unknown',
            networkType: 'unknown',
          ),
        );
        
      } catch (e) {
        print('文件完整性检查失败: $e');
        _logManager?.addErrorLog(
          type: TransferLogType.receive,
          fileName: conn.currentFileName!,
          error: '文件完整性检查失败: $e',
          sourceDevice: DiscoveredDevice(
            id: 'unknown_${conn.socket.remoteAddress.address.hashCode}',
            name: '远程设备',
            os: 'unknown',
            ip: conn.socket.remoteAddress.address,
            tcpPort: conn.socket.remotePort,
            lastSeenMs: DateTime.now().millisecondsSinceEpoch,
            networkInterface: 'unknown',
            networkType: 'unknown',
          ),
        );
        
        // 发送错误响应
        conn.send({
          'type': 'ERROR', 
          'message': '文件完整性检查失败: $e'
        });
        return;
      }
    }

    // 重置连接状态
    conn.resetFileTransfer();

    // 发送成功响应，包含文件哈希信息
    final response = {
      'type': 'ACK', 
      'for': 'FILE_END',
      'fileValid': fileValid,
      'hashValid': hashValid,
    };
    
    if (fileHash != null) {
      response['fileHash'] = fileHash;
    }
    
    conn.send(response);
  }
}

/// 增强的套接字 JSON 行封装器：支持混合的控制帧和二进制数据
class _EnhancedJsonLineConnection {
  final Socket socket;
  final StreamController<Map<String, dynamic>> _ctrl = StreamController();
  final StringBuffer _lineBuf = StringBuffer();
  late final StreamSubscription<List<int>> _sub;
  
  // 文件传输相关状态
  String? currentFileName;
  int? currentFileSize;
  String? currentSavePath;
  IOSink? currentFileStream;
  int receivedBytes = 0;
  final List<int> _binaryBuffer = [];
  StreamSubscription<List<int>>? _binaryDataSubscription;
  
  // 二进制数据等待机制
  bool _waitingForBinaryData = false;
  Completer<List<int>?>? _binaryDataCompleter;
  int? _requiredBinarySize;
  
  // 哈希校验相关状态
  String? expectedFileHash;
  _DigestCollector? hashDigestSink;
  ByteConversionSink? hashByteSink;

  _EnhancedJsonLineConnection(this.socket) {
    _sub = socket.listen(_onData, onError: _ctrl.addError, onDone: _ctrl.close);
  }

  Stream<Map<String, dynamic>> get frames => _ctrl.stream;

  void send(Map<String, dynamic> json) {
    try {
      final data = jsonEncode(json);
      socket.add(utf8.encode(data));
      socket.add([10]); // 换行符 \n 分隔一帧
    } catch (e) {
      // 忽略发送错误，连接可能已断开
      print('发送控制帧失败: $e');
    }
  }

  /// 读取指定大小的二进制数据
  Future<List<int>?> readBinaryData(int size) async {
    final completer = Completer<List<int>?>();
    
    // 如果缓冲区已经有足够的数据，直接返回
    if (_binaryBuffer.length >= size) {
      final result = _binaryBuffer.sublist(0, size);
      _binaryBuffer.removeRange(0, size);
      completer.complete(result);
      return completer.future;
    }
    
    // 设置二进制数据等待模式
    _waitingForBinaryData = true;
    _binaryDataCompleter = completer;
    _requiredBinarySize = size;
    
    // 如果缓冲区已经有数据，检查是否足够
    if (_binaryBuffer.isNotEmpty) {
      _checkBinaryBuffer();
    }

    return completer.future;
  }

  /// 检查二进制缓冲区是否满足需求
  void _checkBinaryBuffer() {
    if (_waitingForBinaryData && 
        _binaryDataCompleter != null && 
        _requiredBinarySize != null &&
        _binaryBuffer.length >= _requiredBinarySize!) {
      
      final result = _binaryBuffer.sublist(0, _requiredBinarySize!);
      _binaryBuffer.removeRange(0, _requiredBinarySize!);
      
      _waitingForBinaryData = false;
      _binaryDataCompleter!.complete(result);
      _binaryDataCompleter = null;
      _requiredBinarySize = null;
    }
  }

  void _onData(List<int> data) {
    // 将数据添加到二进制缓冲区
    _binaryBuffer.addAll(data);
    
    // 检查是否有等待的二进制数据请求
    if (_waitingForBinaryData) {
      _checkBinaryBuffer();
    }
    
    // 如果没有等待二进制数据，处理控制帧
    if (!_waitingForBinaryData) {
      _processControlFrames();
    }
  }

  /// 检查缓冲区中是否有完整的控制帧（以换行符结尾）
  bool _hasCompleteControlFrame() {
    for (int i = 0; i < _binaryBuffer.length; i++) {
      if (_binaryBuffer[i] == 10) { // 10 = \n
        return true;
      }
    }
    return false;
  }

  /// 处理控制帧
  void _processControlFrames() {
    // 查找第一个换行符的位置
    int newlineIndex = -1;
    for (int i = 0; i < _binaryBuffer.length; i++) {
      if (_binaryBuffer[i] == 10) { // 10 = \n
        newlineIndex = i;
        break;
      }
    }
    
    if (newlineIndex == -1) {
      // 没有完整的控制帧，将数据添加到行缓冲区
      final text = utf8.decode(_binaryBuffer, allowMalformed: true);
      _binaryBuffer.clear();
      _lineBuf.write(text);
      return;
    }
    
    // 提取控制帧数据（包括换行符）
    final controlFrameData = _binaryBuffer.sublist(0, newlineIndex + 1);
    _binaryBuffer.removeRange(0, newlineIndex + 1);
    
    // 处理控制帧
    final text = utf8.decode(controlFrameData, allowMalformed: true);
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
    
    // 检查是否还有更多控制帧
    if (_hasCompleteControlFrame()) {
      _processControlFrames();
    }
  }

  /// 重置文件传输状态
  void resetFileTransfer() {
    currentFileName = null;
    currentFileSize = null;
    currentSavePath = null;
    currentFileStream = null;
    receivedBytes = 0;
    expectedFileHash = null;
    hashByteSink = null;
    hashDigestSink = null;
    _binaryBuffer.clear();
  }

  void dispose() {
    _sub.cancel();
    if (currentFileStream != null) {
      try {
        currentFileStream!.close();
      } catch (e) {
        // 忽略StreamSink关闭错误
        print('关闭文件流时出错: $e');
      }
    }
    try {
      socket.destroy();
    } catch (e) {
      // 忽略socket销毁错误
      print('销毁socket时出错: $e');
    }
  }
}
