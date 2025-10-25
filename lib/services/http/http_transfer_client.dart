import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yolighttransfer/util/transfer_protocol.dart';
import 'package:yolighttransfer/services/file/enhanced_file_hash_service.dart';
import 'package:yolighttransfer/services/file/cache_cleanup_service.dart';

/// HTTP 文件传输客户端（发送端）
/// 支持流式上传、断点续传等功能
class HttpTransferClient {
  final String serverIp;
  final int serverPort;

  // 传输回调
  void Function(int uploadedBytes, int totalBytes)? onProgress;
  void Function(String message)? onLog;
  
  // 日志管理器（可选）
  dynamic logManager;

  HttpTransferClient({
    required this.serverIp,
    required this.serverPort,
    this.logManager,
  });

  /// 获取基础URL
  String get _baseUrl => 'http://$serverIp:$serverPort';

  /// 上传文件（流式上传）
  Future<bool> uploadFile({
    required String filePath,
    required String fileName,
    int maxRetries = 3,
    bool resumeUpload = true,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        _log('❌ 文件不存在: $filePath');
        return false;
      }

      final fileSize = await file.length();

      _log('📤 开始上传文件: $fileName');
      _log('📊 文件大小: ${_formatBytes(fileSize)}');

      // 计算文件哈希
      _log('🔐 计算文件哈希...');
      final stopwatch = Stopwatch()..start();
      final fileHash = await EnhancedFileHashService.calculateFileHash(filePath);
      stopwatch.stop();
      _log('✅ 文件哈希: $fileHash (耗时: ${stopwatch.elapsedMilliseconds}ms)');

      // 查询已上传的字节数（用于断点续传）
      int startByte = 0;
      if (resumeUpload) {
        startByte = await _queryUploadedBytes(fileName);
        if (startByte > 0) {
          _log('🔄 断点续传：从字节 $startByte 开始');
        }
      }

      // 执行流式上传
      final success = await _uploadStream(
        filePath: filePath,
        fileName: fileName,
        fileHash: fileHash,
        fileSize: fileSize,
        startByte: startByte,
        maxRetries: maxRetries,
      );

      // 上传完成后，删除 cache 中的临时文件
      if (success) {
        await _cleanupCacheFile(filePath);
      }

      return success;
    } catch (e) {
      _log('❌ 上传失败: $e');
      // 上传失败也要删除 cache 文件
      await _cleanupCacheFile(filePath);
      return false;
    }
  }

  /// 流式上传文件
  Future<bool> _uploadStream({
    required String filePath,
    required String fileName,
    required String fileHash,
    required int fileSize,
    required int startByte,
    required int maxRetries,
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final file = File(filePath);
        
        // 打开文件流，从指定位置开始
        final stream = file.openRead(startByte);
        
        final request = await HttpClient().postUrl(
          Uri.http('$serverIp:$serverPort', HttpTransferProtocol.UPLOAD_ENDPOINT),
        );

        // 设置请求头
        final encodedFileName = Uri.encodeComponent(fileName);
        request.headers.set(HttpTransferProtocol.HEADER_FILE_NAME, encodedFileName);
        request.headers.set(HttpTransferProtocol.HEADER_FILE_SIZE, fileSize.toString());
        request.headers.set(HttpTransferProtocol.HEADER_FILE_HASH, fileHash);
        request.headers.set('Content-Type', 'application/octet-stream');
        
        // 如果是断点续传，添加 Range 头
        if (startByte > 0) {
          request.headers.set('Range', 'bytes=$startByte-');
        }
        
        // 添加发送设备名称
        final deviceName = await _getDeviceName();
        final encodedDeviceName = Uri.encodeComponent(deviceName);
        request.headers.set('X-Sender-Device-Name', encodedDeviceName);

        // 流式发送文件数据，同时跟踪进度
        int uploadedBytes = startByte;
        await stream.listen(
          (chunk) {
            request.add(chunk);
            uploadedBytes += chunk.length;
            
            // 更新进度
            onProgress?.call(uploadedBytes, fileSize);
            
            // 更新进度日志
            final progress = (uploadedBytes / fileSize * 100).toInt();
            if (uploadedBytes == chunk.length + startByte) {
              // 第一个数据块时，添加进度日志
              logManager?.addProgressLog(
                logId: '${DateTime.now().millisecondsSinceEpoch}_send_$fileName',
                type: 'send',
                fileName: fileName,
                progress: progress,
              );
            } else {
              // 之后的数据块，更新进度日志
              logManager?.updateProgressLog(
                fileName: fileName,
                progress: progress,
              );
            }
          },
          onDone: () async {
            // 流完成，关闭请求
          },
          onError: (error) {
            _log('❌ 流读取错误: $error');
            throw error;
          },
          cancelOnError: true,
        ).asFuture();

        final response = await request.close();

        if (response.statusCode == 200) {
          _log('✅ 流式上传完成: $fileName');
          return true;
        } else if (response.statusCode == 403) {
          _log('❌ 用户拒绝了文件传输: $fileName');
          return false;
        } else {
          _log('⚠️ 上传返回状态码: ${response.statusCode}');
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
          }
        }
      } catch (e) {
        _log('⚠️ 上传异常: $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }

    return false;
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

  /// 查询已上传的字节数
  Future<int> _queryUploadedBytes(String fileName) async {
    try {
      final status = await queryStatus(fileName);
      if (status != null && status.containsKey('receivedBytes')) {
        return status['receivedBytes'] as int;
      }
      return 0;
    } catch (e) {
      _log('❌ 查询已上传字节数失败: $e');
      return 0;
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

  /// 清理 cache 中的临时文件
  Future<void> _cleanupCacheFile(String filePath) async {
    try {
      // 检查是否是 cache 目录中的文件
      if (filePath.contains('/cache/file_picker/') || 
          filePath.contains('\\cache\\file_picker\\')) {
        _log('🧹 清理 cache 中的临时文件: $filePath');
        final deleted = await CacheCleanupService.deleteFile(filePath);
        if (deleted) {
          _log('✅ 临时文件已删除');
        }
      }
    } catch (e) {
      _log('⚠️ 清理临时文件失败: $e');
    }
  }

  /// 记录日志
  void _log(String message) {
    print(message);
    onLog?.call(message);
  }
}
