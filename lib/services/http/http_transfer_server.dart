import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yolighttransfer/util/transfer_protocol.dart';
import 'package:yolighttransfer/services/file/enhanced_file_hash_service.dart';
import 'package:yolighttransfer/services/file/multi_thread_hash_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// HTTP 文件传输服务器（接收端）
/// 支持分片上传、断点续传、Range 请求等功能
class HttpTransferServer {
  final int port;
  final String uploadDir;

  HttpServer? _server;
  bool _running = false;

  // 正在进行的传输任务
  final Map<String, _TransferSession> _activeSessions = {};
  
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
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _running = true;

      print('✅ HTTP 服务器启动成功，监听端口: $port');
      print('📁 上传目录: $uploadDir');

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
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-File-Name, X-File-Size, X-File-Hash, X-Chunk-Index, X-Total-Chunks');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      if (path == HttpTransferProtocol.UPLOAD_ENDPOINT && request.method == 'POST') {
        await _handleUpload(request);
      } else if (path == HttpTransferProtocol.STATUS_ENDPOINT && request.method == 'GET') {
        await _handleStatus(request);
      } else if (path == '/initialize-concurrent-upload' && request.method == 'POST') {
        await _handleInitializeConcurrentUpload(request);
      } else if (path == '/upload-chunk' && request.method == 'POST') {
        await _handleConcurrentUpload(request);
      } else if (path == '/merge-file' && request.method == 'POST') {
        await _handleMergeFile(request);
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

  /// 处理并发上传初始化请求
  Future<void> _handleInitializeConcurrentUpload(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final fileName = data['fileName'] as String?;
      final fileSize = data['fileSize'] as int?;

      if (fileName == null || fileSize == null) {
        request.response.statusCode = 400;
        request.response.write('Missing required fields');
        await request.response.close();
        return;
      }

      // 获取发送设备信息
      final senderDeviceName = '并发上传设备';
      
      // 如果有确认回调，则等待用户确认
      if (onReceiveConfirmation != null) {
        print('📩 收到并发文件传输请求: $fileName (${_formatBytes(fileSize)})');
        
        final confirmed = await onReceiveConfirmation!(senderDeviceName, fileName, fileSize);
        
        if (!confirmed) {
          print('❌ 用户拒绝了文件传输: $fileName');
          request.response.statusCode = 403;
          request.response.write('File transfer rejected by user');
          await request.response.close();
          return;
        }
        
        print('✅ 用户接受了并发文件传输: $fileName');
      }
      
      // 记录接收开始日志
      logManager?.addReceiveStartLog(
        fileName: fileName,
        fileSize: fileSize,
        savePath: '$uploadDir/$fileName',
        sourceDevice: sourceDevice ?? DiscoveredDevice(
          id: 'concurrent',
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

      // 返回成功响应
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'success',
        'message': 'File transfer confirmed',
        'fileName': fileName,
      }));
      await request.response.close();

    } catch (e) {
      print('❌ 初始化请求处理失败: $e');
      request.response.statusCode = 500;
      request.response.write('Initialize failed: $e');
      await request.response.close();
    }
  }

  /// 处理并发上传的分片
  Future<void> _handleConcurrentUpload(HttpRequest request) async {
    try {
      if (request.method != 'POST') {
        request.response.statusCode = 405;
        request.response.write('Method Not Allowed');
        await request.response.close();
        return;
      }

      // 解析 multipart 请求
      final contentType = request.headers.contentType;
      final boundary = contentType?.parameters['boundary'];
      if (boundary == null) {
        request.response.statusCode = 400;
        request.response.write('Missing boundary');
        await request.response.close();
        return;
      }

      // 收集所有请求体字节
      final bodyBytes = await request.fold<List<int>>([], (previous, element) => previous..addAll(element));
      
      final parts = <String, dynamic>{};
      final chunkDataList = <int>[];

      // 使用简单的字符串分割方式解析 multipart
      final boundaryStr = '--$boundary';
      final bodyStr = utf8.decode(bodyBytes);
      final partsList = bodyStr.split(boundaryStr);

      for (final part in partsList) {
        if (part.isEmpty || part == '--\r\n' || part == '--') continue;

        // 分离头部和数据
        final headerEndIndex = part.indexOf('\r\n\r\n');
        if (headerEndIndex == -1) continue;

        final headerStr = part.substring(0, headerEndIndex);
        final dataStartIndex = headerEndIndex + 4;
        var dataEndIndex = part.length;
        
        // 移除末尾的 \r\n
        if (dataEndIndex >= 2 && part.endsWith('\r\n')) {
          dataEndIndex -= 2;
        }

        // 解析 Content-Disposition 头
        String? fieldName;
        final dispositionMatch = RegExp(r'name="([^"]+)"').firstMatch(headerStr);
        if (dispositionMatch != null) {
          fieldName = dispositionMatch.group(1);
        }

        if (fieldName == null) continue;

        // 提取数据
        if (fieldName == 'chunk') {
          // 二进制文件数据 - 从原始字节中提取
          final dataStr = part.substring(dataStartIndex, dataEndIndex);
          chunkDataList.addAll(utf8.encode(dataStr));
        } else {
          // 文本字段
          final fieldValue = part.substring(dataStartIndex, dataEndIndex).trim();
          parts[fieldName] = fieldValue;
        }
      }

      final fileName = parts['fileName'] as String?;
      final fileHash = parts['fileHash'] as String?;
      final chunkIndex = int.tryParse(parts['chunkIndex'] as String? ?? '');
      final totalChunks = int.tryParse(parts['totalChunks'] as String? ?? '');
      final chunkSize = int.tryParse(parts['chunkSize'] as String? ?? '');
      final fileSize = int.tryParse(parts['fileSize'] as String? ?? '');

      // 验证必需字段
      if (fileName == null || fileHash == null || chunkIndex == null || 
          totalChunks == null || chunkSize == null || fileSize == null || 
          chunkDataList.isEmpty) {
        print('❌ 缺少必需字段: fileName=$fileName, fileHash=$fileHash, chunkIndex=$chunkIndex, totalChunks=$totalChunks, chunkSize=$chunkSize, fileSize=$fileSize, dataSize=${chunkDataList.length}');
        request.response.statusCode = 400;
        request.response.write('Missing required fields');
        await request.response.close();
        return;
      }

      // 处理分片上传
      await _processChunkUpload(
        request: request,
        fileName: fileName,
        fileHash: fileHash,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        chunkSize: chunkSize,
        fileSize: fileSize,
        chunkData: chunkDataList,
      );

    } catch (e) {
      print('❌ 并发上传处理失败: $e');
      request.response.statusCode = 500;
      request.response.write('Concurrent upload failed: $e');
      await request.response.close();
    }
  }

  /// 处理文件合并请求
  Future<void> _handleMergeFile(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final fileName = data['fileName'] as String?;
      final fileHash = data['fileHash'] as String?;
      final totalChunks = data['totalChunks'] as int?;

      if (fileName == null || fileHash == null || totalChunks == null) {
        request.response.statusCode = 400;
        request.response.write('Missing required fields');
        await request.response.close();
        return;
      }

      // 检查会话是否存在且已完成
      final session = _activeSessions[fileName];
      if (session == null || !session.isComplete()) {
        request.response.statusCode = 400;
        request.response.write('File not fully uploaded');
        await request.response.close();
        return;
      }

      // 验证文件哈希
      final actualHash = await MultiThreadHashService.calculateFileHash(session.filePath);
      if (actualHash != fileHash) {
        request.response.statusCode = 409;
        request.response.write('Hash mismatch');
        await request.response.close();
        return;
      }

      // 记录完成日志
      logManager?.addCompleteLog(
        logId: '${DateTime.now().millisecondsSinceEpoch}_receive_${fileName.hashCode}',
        type: TransferLogType.receive,
        fileName: fileName,
        fileSize: session.fileSize,
        savePath: session.filePath,
        sourceDevice: sourceDevice,
      );

      // 更新任务管理器状态
      taskManager?.markReceiveCompleted(fileName);

      // 移除会话
      _activeSessions.remove(fileName);

      request.response.statusCode = 200;
      request.response.write('File merged successfully');
      await request.response.close();

      print('✅ 文件合并完成: $fileName');

    } catch (e) {
      print('❌ 文件合并失败: $e');
      request.response.statusCode = 500;
      request.response.write('Merge failed: $e');
      await request.response.close();
    }
  }

  /// 处理分片上传（支持并发）
  Future<void> _processChunkUpload({
    required HttpRequest request,
    required String fileName,
    required String fileHash,
    required int chunkIndex,
    required int totalChunks,
    required int chunkSize,
    required int fileSize,
    required List<int> chunkData,
  }) async {
    // 检查是否是第一个分片，如果是则进行接收确认和日志记录
    if (chunkIndex == 0 && !_activeSessions.containsKey(fileName)) {
      // 获取发送设备信息
      final senderDeviceName = '并发上传设备';
      
      // 如果有确认回调，则等待用户确认
      if (onReceiveConfirmation != null) {
        print('📩 收到并发文件传输请求: $fileName (${_formatBytes(fileSize)})');
        
        final confirmed = await onReceiveConfirmation!(senderDeviceName, fileName, fileSize);
        
        if (!confirmed) {
          print('❌ 用户拒绝了文件传输: $fileName');
          request.response.statusCode = 403;
          request.response.write('File transfer rejected by user');
          await request.response.close();
          return;
        }
        
        print('✅ 用户接受了并发文件传输: $fileName');
      }
      
      // 记录接收开始日志
      logManager?.addReceiveStartLog(
        fileName: fileName,
        fileSize: fileSize,
        savePath: '$uploadDir/$fileName',
        sourceDevice: sourceDevice ?? DiscoveredDevice(
          id: 'concurrent',
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
    final sessionId = fileName;
    final session = _activeSessions.putIfAbsent(
      sessionId,
      () => _TransferSession(
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        uploadDir: uploadDir,
      ),
    );

    // 写入分片（支持并发写入）
    await session.writeChunk(chunkIndex, chunkData);

    // 更新进度日志
    final progress = ((session.uploadedBytes) / fileSize * 100).toInt();
    if (chunkIndex == 0) {
      // 第一个分片时，添加进度日志
      final logId = '${DateTime.now().millisecondsSinceEpoch}_receive_$fileName';
      _progressLogIds[fileName] = logId;
      logManager?.addProgressLog(
        logId: logId,
        type: TransferLogType.receive,
        fileName: fileName,
        progress: progress,
      );
    } else {
      // 之后的分片，更新进度日志
      logManager?.updateProgressLog(
        fileName: fileName,
        progress: progress,
      );
    }

    // 返回成功响应
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'success',
      'fileName': fileName,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'uploadedBytes': session.uploadedBytes,
      'totalBytes': fileSize,
    }));
    await request.response.close();

    print('📤 并发分片 $chunkIndex/$totalChunks 接收成功: ${chunkData.length} 字节');
  }

  /// 处理文件上传（原有逻辑）
  Future<void> _handleUpload(HttpRequest request) async {
    try {
      final encodedFileName = request.headers.value(HttpTransferProtocol.HEADER_FILE_NAME);
      final fileSizeStr = request.headers.value(HttpTransferProtocol.HEADER_FILE_SIZE);
      final chunkIndexStr = request.headers.value(HttpTransferProtocol.HEADER_CHUNK_INDEX);
      final totalChunksStr = request.headers.value(HttpTransferProtocol.HEADER_TOTAL_CHUNKS);

      if (encodedFileName == null || fileSizeStr == null) {
        request.response.statusCode = 400;
        request.response.write('Missing required headers');
        await request.response.close();
        return;
      }

      // 对文件名进行 URL 解码以支持中文等非 ASCII 字符
      final fileName = Uri.decodeComponent(encodedFileName);

      final fileSize = int.parse(fileSizeStr);
      final chunkIndex = chunkIndexStr != null ? int.parse(chunkIndexStr) : 0;
      final totalChunks = totalChunksStr != null ? int.parse(totalChunksStr) : 1;

      // 检查是否是第一个分片，如果是则进行接收确认和日志记录
      if (chunkIndex == 0 && !_activeSessions.containsKey(fileName)) {
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
          savePath: '$uploadDir/$fileName',
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
      final sessionId = fileName;
      final session = _activeSessions.putIfAbsent(
        sessionId,
        () => _TransferSession(
          fileName: fileName,
          fileSize: fileSize,
          totalChunks: totalChunks,
          uploadDir: uploadDir,
        ),
      );

      // 接收分片数据
      final chunkData = await request.fold<List<int>>(
        [],
        (previous, element) => previous..addAll(element),
      );

      // 写入分片
      await session.writeChunk(chunkIndex, chunkData);

      // 更新进度日志
      final progress = ((session.uploadedBytes) / fileSize * 100).toInt();
      if (chunkIndex == 0) {
        // 第一个分片时，添加进度日志
        final logId = '${DateTime.now().millisecondsSinceEpoch}_receive_$fileName';
        _progressLogIds[fileName] = logId;
        logManager?.addProgressLog(
          logId: logId,
          type: TransferLogType.receive,
          fileName: fileName,
          progress: progress,
        );
      } else {
        // 之后的分片，更新进度日志
        logManager?.updateProgressLog(
          fileName: fileName,
          progress: progress,
        );
      }

      // 检查是否完成
      if (session.isComplete()) {
        // 先关闭文件，确保数据写入磁盘
        session.close();
        
        // 验证文件哈希
        final fileHash = request.headers.value(HttpTransferProtocol.HEADER_FILE_HASH);
        if (fileHash != null) {
          // 添加短暂延迟，确保文件完全写入磁盘
          await Future.delayed(Duration(milliseconds: 100));
          
          final actualHash = await EnhancedFileHashService.calculateFileHash(session.filePath);
          
          // 添加详细的哈希验证日志
          print('🔍 哈希验证: 期望=$fileHash, 实际=$actualHash');
          
          if (actualHash != fileHash) {
            // 哈希校验失败
            final failMsg = '❌ 文件一致性校验失败: $fileName';
            print(failMsg);
            
            // 记录哈希校验失败日志
            logManager?.addHashLog(
              message: failMsg,
              fileName: fileName,
              expectedHash: fileHash,
              actualHash: actualHash,
              hashValid: false,
            );
            
            request.response.statusCode = 409;
            request.response.write('Hash mismatch: expected=$fileHash, actual=$actualHash');
            await request.response.close();
            _activeSessions.remove(sessionId);
            return;
          }
          
          // 哈希校验通过
          final successMsg = '✅ 文件一致性校验通过: $fileName';
          print(successMsg);
          
          // 记录哈希校验成功日志
          logManager?.addHashLog(
            message: successMsg,
            fileName: fileName,
            expectedHash: fileHash,
            actualHash: actualHash,
            hashValid: true,
          );
        }

        // 记录接收完成日志
        logManager?.addCompleteLog(
          logId: '${DateTime.now().millisecondsSinceEpoch}_receive_${fileName.hashCode}',
          type: TransferLogType.receive,
          fileName: fileName,
          fileSize: fileSize,
          savePath: session.filePath,
          sourceDevice: sourceDevice,
        );
        
        // 更新任务管理器状态
        taskManager?.markReceiveCompleted(fileName);

        _activeSessions.remove(sessionId);
        print('✅ 文件上传完成: $fileName');
      }

      // 返回成功响应
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'success',
        'fileName': fileName,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'uploadedBytes': session.uploadedBytes,
        'totalBytes': fileSize,
      }));
      await request.response.close();
    } catch (e) {
      print('❌ 上传处理失败: $e');
      request.response.statusCode = 500;
      request.response.write('Upload failed: $e');
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
        'uploadedBytes': session.uploadedBytes,
        'totalBytes': session.fileSize,
        'uploadedChunks': session.uploadedChunks.length,
        'totalChunks': session.totalChunks,
        'progress': (session.uploadedBytes / session.fileSize * 100).toStringAsFixed(2),
      }));
      await request.response.close();
    } catch (e) {
      print('❌ 状态查询失败: $e');
      request.response.statusCode = 500;
      request.response.write('Status query failed: $e');
      await request.response.close();
    }
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
}

/// 传输会话
class _TransferSession {
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final String uploadDir;

  late final String filePath;
  late final RandomAccessFile _file;
  final Set<int> uploadedChunks = {};
  int uploadedBytes = 0;

  _TransferSession({
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
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

  /// 写入分片数据
  Future<void> writeChunk(int chunkIndex, List<int> data) async {
    if (uploadedChunks.contains(chunkIndex)) {
      return; // 已上传过，忽略
    }

    // 使用更简单的方法：按顺序写入，不依赖固定分片大小
    _file.setPositionSync(_file.positionSync());
    _file.writeFromSync(data);

    uploadedChunks.add(chunkIndex);
    uploadedBytes += data.length;
    
    print('📝 写入分片 $chunkIndex: ${data.length} 字节, 累计: $uploadedBytes/$fileSize 字节');
  }

  /// 检查是否完成
  bool isComplete() {
    return uploadedChunks.length == totalChunks;
  }

  /// 关闭文件
  void close() {
    try {
      _file.closeSync();
    } catch (_) {}
  }
}
