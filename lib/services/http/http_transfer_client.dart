import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yolighttransfer/util/transfer_protocol.dart';
import 'package:yolighttransfer/services/file/enhanced_file_hash_service.dart';
import 'package:yolighttransfer/services/file/multi_thread_hash_service.dart';
import 'package:yolighttransfer/services/http/concurrent_chunk_uploader.dart';

/// HTTP 文件传输客户端（发送端）
/// 支持分片上传、断点续传、进度回调等功能
class HttpTransferClient {
  final String serverIp;
  final int serverPort;

  // 传输回调
  void Function(int uploadedBytes, int totalBytes)? onProgress;
  void Function(String message)? onLog;
  
  // 日志管理器（可选）
  dynamic logManager;
  
  // 进度日志 ID 映射（用于跟踪每个文件的进度日志）
  final Map<String, String> _progressLogIds = {};

  HttpTransferClient({
    required this.serverIp,
    required this.serverPort,
    this.logManager,
  });

  /// 获取基础URL
  String get _baseUrl => 'http://$serverIp:$serverPort';

  /// 上传文件
  Future<bool> uploadFile({
    required String filePath,
    required String fileName,
    int chunkSize = 1048576, // 1MB
    int maxRetries = 3,
    bool resumeUpload = true,
    bool useConcurrentUpload = true, // 是否使用并发上传
    int maxConcurrent = 4, // 最大并发数
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        _log('❌ 文件不存在: $filePath');
        return false;
      }

      final fileSize = await file.length();
      final totalChunks = (fileSize + chunkSize - 1) ~/ chunkSize;

      _log('📤 开始上传文件: $fileName');
      _log('📊 文件大小: ${_formatBytes(fileSize)}');
      _log('📦 分片数: $totalChunks');

      // 计算文件哈希（使用多线程优化）
      _log('🔐 计算文件哈希...');
      final stopwatch = Stopwatch()..start();
      final fileHash = await MultiThreadHashService.calculateFileHash(filePath);
      stopwatch.stop();
      _log('✅ 文件哈希: $fileHash (耗时: ${stopwatch.elapsedMilliseconds}ms)');

      // 断点续传：查询已上传的分片
      Set<int> uploadedChunks = {};
      if (resumeUpload) {
        uploadedChunks = await _queryUploadedChunks(fileName);
        if (uploadedChunks.isNotEmpty) {
          _log('🔄 断点续传：已上传 ${uploadedChunks.length} 个分片');
        }
      }

      // 选择上传方式
      if (useConcurrentUpload && totalChunks > 1) {
        return await _uploadConcurrent(
          filePath: filePath,
          fileName: fileName,
          fileHash: fileHash,
          totalChunks: totalChunks,
          chunkSize: chunkSize,
          uploadedChunks: uploadedChunks,
          maxConcurrent: maxConcurrent,
        );
      } else {
        return await _uploadSequential(
          filePath: filePath,
          fileName: fileName,
          fileHash: fileHash,
          totalChunks: totalChunks,
          chunkSize: chunkSize,
          uploadedChunks: uploadedChunks,
          maxRetries: maxRetries,
        );
      }
    } on _FileTransferRejectedException {
      // 用户拒绝了文件传输，不打印额外的错误信息
      return false;
    } catch (e) {
      _log('❌ 上传失败: $e');
      return false;
    }
  }

  /// 并发上传
  Future<bool> _uploadConcurrent({
    required String filePath,
    required String fileName,
    required String fileHash,
    required int totalChunks,
    required int chunkSize,
    required Set<int> uploadedChunks,
    required int maxConcurrent,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 创建并发上传器
    final uploader = ConcurrentChunkUploader(
      baseUrl: _baseUrl,
      maxConcurrent: maxConcurrent,
      onProgress: (uploadedChunksCount, totalChunksCount, progress) {
        final uploadedBytes = (progress * fileSize).toInt();
        onProgress?.call(uploadedBytes, fileSize);
        
        // 更新进度日志
        final progressPercent = (progress * 100).toInt();
        if (uploadedChunksCount == 1) {
          // 第一个分片时，添加进度日志
          final logId = '${DateTime.now().millisecondsSinceEpoch}_send_$fileName';
          _progressLogIds[fileName] = logId;
          logManager?.addProgressLog(
            logId: logId,
            type: 'send',
            fileName: fileName,
            progress: progressPercent,
          );
        } else {
          // 之后的分片，更新进度日志
          logManager?.updateProgressLog(
            fileName: fileName,
            progress: progressPercent,
          );
        }
      },
    );

    // 上传所有分片
    final results = await uploader.uploadAllChunks(
      filePath: filePath,
      fileName: fileName,
      fileHash: fileHash,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
    );

    // 检查结果
    final successCount = results.where((r) => r.success).length;
    if (successCount == totalChunks) {
      _log('✅ 并发上传完成: $fileName');
      
      // 通知服务器合并文件
      final mergeSuccess = await uploader.notifyMerge(
        fileName: fileName,
        fileHash: fileHash,
        totalChunks: totalChunks,
      );
      
      if (mergeSuccess) {
        _log('✅ 文件合并成功: $fileName');
      } else {
        _log('⚠️ 文件合并通知失败，但分片已全部上传: $fileName');
      }
      
      return true;
    } else {
      _log('❌ 并发上传失败: $successCount/$totalChunks 个分片上传成功');
      return false;
    }
  }

  /// 顺序上传（兼容原有逻辑）
  Future<bool> _uploadSequential({
    required String filePath,
    required String fileName,
    required String fileHash,
    required int totalChunks,
    required int chunkSize,
    required Set<int> uploadedChunks,
    required int maxRetries,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    
    int uploadedBytes = 0;
    int chunkIndex = 0;

    while (chunkIndex < totalChunks) {
      // 跳过已上传的分片
      if (uploadedChunks.contains(chunkIndex)) {
        final chunkOffset = chunkIndex * chunkSize;
        final chunkEnd = (chunkIndex == totalChunks - 1) 
            ? fileSize 
            : chunkOffset + chunkSize;
        final chunkSizeActual = chunkEnd - chunkOffset;
        
        uploadedBytes += chunkSizeActual;
        chunkIndex++;
        continue;
      }

      // 读取分片数据
      final chunkOffset = chunkIndex * chunkSize;
      final chunkEnd = (chunkIndex == totalChunks - 1) 
          ? fileSize 
          : chunkOffset + chunkSize;
      final chunkSizeActual = chunkEnd - chunkOffset;
      
      final chunkData = await file.readAsBytes().then((bytes) {
        return bytes.sublist(chunkOffset, chunkEnd);
      });

      final uploadedChunkBytes = await _uploadChunk(
        fileName: fileName,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        chunkData: chunkData,
        fileSize: fileSize,
        fileHash: fileHash,
        maxRetries: maxRetries,
      );

      if (uploadedChunkBytes == -1) {
        return false;
      }

      // 只在分片成功上传后才更新进度
      uploadedBytes += uploadedChunkBytes;
      onProgress?.call(uploadedBytes, fileSize);
      
      // 更新进度日志
      final progress = (uploadedBytes / fileSize * 100).toInt();
      if (chunkIndex == 0) {
        // 第一个分片时，添加进度日志
        final logId = '${DateTime.now().millisecondsSinceEpoch}_send_$fileName';
        _progressLogIds[fileName] = logId;
        logManager?.addProgressLog(
          logId: logId,
          type: 'send',
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

      chunkIndex++;
    }

    _log('✅ 顺序上传完成: $fileName');
    return true;
  }

  /// 上传单个分片
  /// 返回成功上传的字节数，失败返回 -1
  Future<int> _uploadChunk({
    required String fileName,
    required int chunkIndex,
    required int totalChunks,
    required List<int> chunkData,
    required int fileSize,
    required String fileHash,
    required int maxRetries,
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final request = await HttpClient().postUrl(
          Uri.http('$serverIp:$serverPort', HttpTransferProtocol.UPLOAD_ENDPOINT),
        );

        // 设置请求头（对文件名进行 URL 编码以支持中文等非 ASCII 字符）
        final encodedFileName = Uri.encodeComponent(fileName);
        request.headers.set(HttpTransferProtocol.HEADER_FILE_NAME, encodedFileName);
        request.headers.set(HttpTransferProtocol.HEADER_FILE_SIZE, fileSize.toString());
        request.headers.set(HttpTransferProtocol.HEADER_CHUNK_INDEX, chunkIndex.toString());
        request.headers.set(HttpTransferProtocol.HEADER_TOTAL_CHUNKS, totalChunks.toString());
        request.headers.set(HttpTransferProtocol.HEADER_FILE_HASH, fileHash);
        request.headers.set('Content-Type', 'application/octet-stream');
        
        // 添加发送设备名称，用于接收端确认（使用 URL 编码处理中文字符）
        final deviceName = await _getDeviceName();
        final encodedDeviceName = Uri.encodeComponent(deviceName);
        request.headers.set('X-Sender-Device-Name', encodedDeviceName);

        // 发送数据
        request.add(chunkData);
        final response = await request.close();

        if (response.statusCode == 200) {
          // 成功上传，返回上传的字节数
          return chunkData.length;
        } else if (response.statusCode == 403) {
          // 403 表示用户拒绝了文件传输，不应该重试
          _log('❌ 用户拒绝了文件传输: $fileName');
          throw _FileTransferRejectedException('用户拒绝了文件传输: $fileName');
        } else {
          _log('! 分片 $chunkIndex 返回状态码: ${response.statusCode}');
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
          }
        }
      } on _FileTransferRejectedException {
        // 用户拒绝了文件传输，直接抛出异常
        rethrow;
      } catch (e) {
        _log('⚠️ 分片 $chunkIndex 上传异常: $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }

    return -1;
  }

  /// 查询上传状态
  Future<Map<String, dynamic>?> queryStatus(String fileName) async {
    try {
      final request = await HttpClient().getUrl(
        Uri.http(
          '$serverIp:$serverPort',
          HttpTransferProtocol.STATUS_ENDPOINT,
          {'fileName': fileName},
        ),
      );

      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      _log('❌ 查询状态失败: $e');
      return null;
    }
  }

  /// 查询已上传的分片
  Future<Set<int>> _queryUploadedChunks(String fileName) async {
    try {
      final status = await queryStatus(fileName);
      if (status != null && status.containsKey('uploadedChunks')) {
        final uploadedChunks = status['uploadedChunks'] as int;
        final totalChunks = status['totalChunks'] as int;
        
        // 这里我们假设服务器返回的是已上传的分片数量
        // 在实际实现中，服务器应该返回具体的分片索引列表
        final uploadedChunksSet = <int>{};
        for (int i = 0; i < uploadedChunks; i++) {
          uploadedChunksSet.add(i);
        }
        return uploadedChunksSet;
      }
      return {};
    } catch (e) {
      _log('❌ 查询已上传分片失败: $e');
      return {};
    }
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  /// 获取设备名称
  Future<String> _getDeviceName() async {
    try {
      // 尝试从平台获取设备名称
      if (Platform.isWindows) {
        return Platform.environment['COMPUTERNAME'] ?? 'Windows设备';
      } else if (Platform.isAndroid) {
        return 'Android设备';
      } else if (Platform.isIOS) {
        return 'iOS设备';
      } else if (Platform.isMacOS) {
        return 'Mac设备';
      } else if (Platform.isLinux) {
        return 'Linux设备';
      } else {
        return '未知设备';
      }
    } catch (e) {
      return '未知设备';
    }
  }

  /// 记录日志
  void _log(String message) {
    print(message);
    onLog?.call(message);
  }
}

/// 文件传输被拒绝异常
class _FileTransferRejectedException implements Exception {
  final String message;
  _FileTransferRejectedException(this.message);

  @override
  String toString() => message;
}
