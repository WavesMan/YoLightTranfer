import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yolighttransfer/util/transfer_protocol.dart';
import 'package:yolighttransfer/services/file/file_size_verification_service.dart';
import 'package:yolighttransfer/services/file/download_path_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// HTTP 文件传输服务器（接收端）
/// 支持流式上传、断点续传、Range 请求等功能
class HttpTransferServer {
  final int port;
  final String uploadDir;

  HttpServer? _server;
  bool _running = false;

  // 正在进行的传输任务
  final Map<String, _StreamTransferSession> _activeSessions = {};
  
  // 已确认的文件集合（防止重复确认）
  final Set<String> _confirmedFiles = {};

  // 文件接收确认回调
  Future<bool> Function(String senderDeviceName, String fileName, int fileSize)? onReceiveConfirmation;
  
  // 日志管理器和任务管理器（可选）
  TransferLogManager? logManager;
  TransferTaskManager? taskManager;
  DiscoveredDevice? sourceDevice; // 发送设备信息
  
  // 进度日志 ID 映射（用于跟踪每个文件的进度日志）
  final Map<String, String> _progressLogIds = {};

  HttpTransferServer({
    required this.port,
    required this.uploadDir,
    this.logManager,
    this.taskManager,
    this.sourceDevice,
  });

  bool get isRunning => _running;

  /// 启动 HTTP 服务器
  Future<void> start() async {
    if (_running) return;

    try {
      // 确保下载目录存在
      await DownloadPathService.ensureDownloadDirExists();
      
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _running = true;

      final actualUploadDir = await DownloadPathService.getDownloadDir();
      print('✅ HTTP 服务器启动成功，监听端口: $port');
      print('📁 文件保存目录: $actualUploadDir');

      // 处理请求
      _server!.listen(_handleRequest);
    } catch (e) {
      print('❌ HTTP 服务器启动失败: $e');
      rethrow;
    }
  }

  /// 停止 HTTP 服务器
  Future<void> stop() async {
    if (!_running) return;

    try {
      await _server?.close(force: true);
      _running = false;
      print('✅ HTTP 服务器已停止');
    } catch (e) {
      print('❌ HTTP 服务器停止失败: $e');
    }
  }

  /// 处理 HTTP 请求
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // 设置 CORS 头
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-File-Name, X-File-Size, X-File-Hash, Range, Content-Range');
      request.response.headers.add('Accept-Ranges', 'bytes');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      if (path == HttpTransferProtocol.UPLOAD_ENDPOINT && request.method == 'POST') {
        await _handleStreamUpload(request);
      } else if (path == HttpTransferProtocol.STATUS_ENDPOINT && request.method == 'GET') {
        await _handleStatus(request);
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      print('❌ 处理请求失败: $e');
      try {
        request.response.statusCode = 500;
        request.response.write('Internal Server Error');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// 处理流式上传
  Future<void> _handleStreamUpload(HttpRequest request) async {
    try {
      final encodedFileName = request.headers.value(HttpTransferProtocol.HEADER_FILE_NAME);
      final fileSizeStr = request.headers.value(HttpTransferProtocol.HEADER_FILE_SIZE);

      if (encodedFileName == null || fileSizeStr == null) {
        request.response.statusCode = 400;
        request.response.write('Missing required headers');
        await request.response.close();
        return;
      }

      // 对文件名进行 URL 解码以支持中文等非 ASCII 字符
      final fileName = Uri.decodeComponent(encodedFileName);
      final fileSize = int.parse(fileSizeStr);

      // 获取系统下载目录
      final downloadDir = await DownloadPathService.getDownloadDir();

      // 检查是否是第一次接收此文件，如果是则进行接收确认和日志记录
      if (!_activeSessions.containsKey(fileName)) {
        // 获取发送设备信息（从请求头中获取，需要进行 URL 解码）
        final encodedDeviceName = request.headers.value('X-Sender-Device-Name') ?? '未知设备';
        final senderDeviceName = Uri.decodeComponent(encodedDeviceName);
        
        // 如果有确认回调，则等待用户确认
        if (onReceiveConfirmation != null) {
          print('📩 收到文件传输请求: $fileName (${_formatBytes(fileSize)}) 来自: $senderDeviceName');
          
          final confirmed = await onReceiveConfirmation!(senderDeviceName, fileName, fileSize);
          
          if (!confirmed) {
            print('❌ 用户拒绝了文件传输: $fileName');
            request.response.statusCode = 403;
            request.response.write('File transfer rejected by user');
            await request.response.close();
            return;
          }
          
          print('✅ 用户接受了文件传输: $fileName');
        }
        
        // 记录接收开始日志
        logManager?.addReceiveStartLog(
          fileName: fileName,
          fileSize: fileSize,
          savePath: '$downloadDir/$fileName',
          sourceDevice: sourceDevice ?? DiscoveredDevice(
            id: 'unknown',
            name: senderDeviceName,
            ip: request.connectionInfo?.remoteAddress.address ?? 'unknown',
            os: 'unknown',
            httpPort: port,
            lastSeenMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        
        // 添加接收任务到任务管理器
        if (taskManager != null) {
          taskManager!.addReceivingTask(
            fileName,
            fileSize,
            sourceDevice,
          );
        }
      }

      // 创建或获取传输会话
      final session = _activeSessions.putIfAbsent(
        fileName,
        () => _StreamTransferSession(
          fileName: fileName,
          fileSize: fileSize,
          uploadDir: downloadDir,
        ),
      );

      // 检查 Range 请求（断点续传）
      int startByte = 0;
      final rangeHeader = request.headers.value('Range');
      if (rangeHeader != null) {
        startByte = _parseRangeHeader(rangeHeader);
        print('📍 断点续传: 从字节 $startByte 开始');
      }

      // 流式接收数据
      int receivedBytes = startByte;
      int lastUpdateProgress = 0; // 记录上次更新的进度，避免过度更新
      int lastSpeedUpdateTime = DateTime.now().millisecondsSinceEpoch;
      int lastSpeedUpdateBytes = startByte;
      
      await request.forEach((chunk) {
        session.writeChunk(chunk);
        receivedBytes += chunk.length;
        
        // 计算当前进度
        final progress = ((receivedBytes) / fileSize * 100).toInt();
        
        // 只在进度百分比变化时更新（优化频率）
        if (progress != lastUpdateProgress) {
          final transferredSizeStr = _formatBytes(receivedBytes);
          
          // 计算网速
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          final timeDiff = currentTime - lastSpeedUpdateTime;
          final bytesDiff = receivedBytes - lastSpeedUpdateBytes;
          
          String transferSpeed = '计算中...';
          if (timeDiff > 0) {
            final speedBytesPerSecond = (bytesDiff / (timeDiff / 1000)).toInt();
            transferSpeed = _formatSpeed(speedBytesPerSecond);
          }
          
          // 更新进度日志
          if (receivedBytes == chunk.length) {
            // 第一个数据块时，添加进度日志
            final logId = '${DateTime.now().millisecondsSinceEpoch}_receive_$fileName';
            _progressLogIds[fileName] = logId;
            logManager?.addProgressLog(
              logId: logId,
              type: TransferLogType.receive,
              fileName: fileName,
              progress: progress,
              transferSpeed: transferSpeed,
            );
          } else {
            // 之后的数据块，更新进度日志
            logManager?.updateProgressLog(
              fileName: fileName,
              progress: progress,
              transferSpeed: transferSpeed,
            );
          }
          
          // 关键修复：同时更新 TaskManager 的进度
          taskManager?.updateProgress(
            fileName: fileName,
            progress: progress,
            transferredSize: transferredSizeStr,
            eta: transferSpeed,
          );
          
          lastUpdateProgress = progress;
          lastSpeedUpdateTime = currentTime;
          lastSpeedUpdateBytes = receivedBytes;
        }
      });

      // 关闭文件
      session.close();

      // 验证文件大小（快速且内存友好）
      await Future.delayed(Duration(milliseconds: 100)); // 确保文件完全写入磁盘
      
      final sizeValid = await FileSizeVerificationService.verifyFileSize(session.filePath, fileSize);
      
      if (!sizeValid) {
        // 文件大小校验失败
        final failMsg = '❌ 文件大小校验失败: $fileName';
        print(failMsg);
        
        // 记录校验失败日志
        logManager?.addHashLog(
          message: failMsg,
          fileName: fileName,
          expectedHash: '文件大小: ${_formatBytes(fileSize)}',
          actualHash: '文件大小不匹配',
          hashValid: false,
        );
        
        request.response.statusCode = 409;
        request.response.write('File size mismatch');
        await request.response.close();
        _activeSessions.remove(fileName);
        return;
      }
      
      // 文件大小校验通过
      final successMsg = '✅ 文件大小校验通过: $fileName (${_formatBytes(fileSize)})';
      print(successMsg);
      
      // 记录校验成功日志
      logManager?.addHashLog(
        message: successMsg,
        fileName: fileName,
        expectedHash: '文件大小: ${_formatBytes(fileSize)}',
        actualHash: '文件大小匹配',
        hashValid: true,
      );

      // 记录接收完成日志
      logManager?.addCompleteLog(
        logId: '${DateTime.now().millisecondsSinceEpoch}_receive_${fileName.hashCode}',
        type: TransferLogType.receive,
        fileName: fileName,
        fileSize: fileSize,
        savePath: '${session.uploadDir}/$fileName',
        sourceDevice: sourceDevice,
      );
      
      // 更新任务管理器状态
      taskManager?.markReceiveCompleted(fileName);

      _activeSessions.remove(fileName);
      print('✅ 文件接收完成: $fileName');

      // 返回成功响应
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'success',
        'fileName': fileName,
        'receivedBytes': receivedBytes,
        'totalBytes': fileSize,
      }));
      await request.response.close();

    } catch (e) {
      print('❌ 流式上传处理失败: $e');
      request.response.statusCode = 500;
      request.response.write('Stream upload failed: $e');
      await request.response.close();
    }
  }

  /// 处理状态查询
  Future<void> _handleStatus(HttpRequest request) async {
    try {
      final fileName = request.uri.queryParameters['fileName'];

      if (fileName == null) {
        request.response.statusCode = 400;
        request.response.write('Missing fileName parameter');
        await request.response.close();
        return;
      }

      final session = _activeSessions[fileName];

      if (session == null) {
        request.response.statusCode = 404;
        request.response.write('Session not found');
        await request.response.close();
        return;
      }

      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'fileName': fileName,
        'receivedBytes': session.receivedBytes,
        'totalBytes': session.fileSize,
        'progress': (session.receivedBytes / session.fileSize * 100).toStringAsFixed(2),
      }));
      await request.response.close();
    } catch (e) {
      print('❌ 状态查询失败: $e');
      request.response.statusCode = 500;
      request.response.write('Status query failed: $e');
      await request.response.close();
    }
  }

  /// 解析 Range 请求头
  /// 格式: "bytes=start-end" 或 "bytes=start-"
  int _parseRangeHeader(String rangeHeader) {
    try {
      if (rangeHeader.startsWith('bytes=')) {
        final range = rangeHeader.substring(6);
        final parts = range.split('-');
        if (parts.isNotEmpty) {
          return int.parse(parts[0]);
        }
      }
    } catch (e) {
      print('⚠️ 解析 Range 头失败: $e');
    }
    return 0;
  }

  /// 释放资源
  void dispose() {
    stop();
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 格式化网速
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

/// 流式传输会话
class _StreamTransferSession {
  final String fileName;
  final int fileSize;
  final String uploadDir;

  late final String filePath;
  late final RandomAccessFile _file;
  int receivedBytes = 0;

  _StreamTransferSession({
    required this.fileName,
    required this.fileSize,
    required this.uploadDir,
  }) {
    filePath = '$uploadDir/$fileName';
    _initFile();
  }

  void _initFile() {
    final dir = Directory(uploadDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      file.createSync();
    }

    _file = file.openSync(mode: FileMode.write);
  }

  /// 写入数据块
  void writeChunk(List<int> data) {
    _file.writeFromSync(data);
    receivedBytes += data.length;
    print('📝 接收数据块: ${data.length} 字节, 累计: $receivedBytes/$fileSize 字节');
  }

  /// 关闭文件
  void close() {
    try {
      _file.closeSync();
    } catch (_) {}
  }
}
