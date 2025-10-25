import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 分片上传结果
class ChunkUploadResult {
  final int chunkIndex;
  final bool success;
  final String? error;
  final int bytesUploaded;

  ChunkUploadResult({
    required this.chunkIndex,
    required this.success,
    this.error,
    required this.bytesUploaded,
  });
}

/// 并发分片上传管理器
class ConcurrentChunkUploader {
  static const int _defaultMaxConcurrent = 4; // 默认最大并发数
  static const int _defaultRetryCount = 3; // 默认重试次数
  static const Duration _defaultRetryDelay = Duration(seconds: 1);

  final String _baseUrl;
  final int _maxConcurrent;
  final int _retryCount;
  final Duration _retryDelay;

  /// 进度回调函数类型
  final void Function(int uploadedChunks, int totalChunks, double progress)? onProgress;

  ConcurrentChunkUploader({
    required String baseUrl,
    int maxConcurrent = _defaultMaxConcurrent,
    int retryCount = _defaultRetryCount,
    Duration retryDelay = _defaultRetryDelay,
    this.onProgress,
  })  : _baseUrl = baseUrl,
        _maxConcurrent = maxConcurrent,
        _retryCount = retryCount,
        _retryDelay = retryDelay;

  /// 并发上传所有分片
  Future<List<ChunkUploadResult>> uploadAllChunks({
    required String filePath,
    required String fileName,
    required String fileHash,
    required int totalChunks,
    required int chunkSize,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    
    print('🚀 开始并发上传 - 文件: $fileName, 分片数: $totalChunks, 并发数: $_maxConcurrent');

    // 第一步：发送初始化请求，获取接收端确认
    print('📩 发送初始化请求到接收端...');
    final initSuccess = await _sendInitializeRequest(
      fileName: fileName,
      fileSize: fileSize.toString(),
    );

    if (!initSuccess) {
      print('❌ 接收端拒绝了文件传输');
      return [];
    }

    print('✅ 接收端已确认，开始并发上传分片');

    final results = <ChunkUploadResult>[];
    int uploadedCount = 0;

    // 创建分片索引队列
    final chunkQueue = List.generate(totalChunks, (index) => index);
    final chunkCompleters = <int, Completer<ChunkUploadResult>>{};

    // 创建并发上传任务
    final uploadTasks = <Future>[];
    for (int i = 0; i < _maxConcurrent; i++) {
      uploadTasks.add(_uploadWorker(
        file: file,
        fileName: fileName,
        fileHash: fileHash,
        totalChunks: totalChunks,
        chunkSize: chunkSize,
        fileSize: fileSize,
        chunkQueue: chunkQueue,
        chunkCompleters: chunkCompleters,
        onChunkComplete: (result) {
          uploadedCount++;
          final progress = uploadedCount / totalChunks;
          onProgress?.call(uploadedCount, totalChunks, progress);
          print('📤 分片 ${result.chunkIndex + 1}/$totalChunks 上传${result.success ? '成功' : '失败'}');
        },
      ));
    }

    // 等待所有上传任务完成
    await Future.wait(uploadTasks);

    // 收集所有结果
    for (int i = 0; i < totalChunks; i++) {
      final result = await chunkCompleters[i]!.future;
      results.add(result);
    }

    // 按分片索引排序
    results.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    final successCount = results.where((r) => r.success).length;
    print('✅ 上传完成 - 成功: $successCount/$totalChunks');

    return results;
  }

  /// 单个上传工作线程
  Future<void> _uploadWorker({
    required File file,
    required String fileName,
    required String fileHash,
    required int totalChunks,
    required int chunkSize,
    required int fileSize,
    required List<int> chunkQueue,
    required Map<int, Completer<ChunkUploadResult>> chunkCompleters,
    required void Function(ChunkUploadResult) onChunkComplete,
  }) async {
    while (chunkQueue.isNotEmpty) {
      final chunkIndex = chunkQueue.removeAt(0);
      
      // 创建Completer用于这个分片
      final completer = Completer<ChunkUploadResult>();
      chunkCompleters[chunkIndex] = completer;

      // 上传分片
      final result = await _uploadChunkWithRetry(
        file: file,
        fileName: fileName,
        fileHash: fileHash,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        chunkSize: chunkSize,
        fileSize: fileSize,
      );

      completer.complete(result);
      onChunkComplete(result);
    }
  }

  /// 带重试机制的分片上传
  Future<ChunkUploadResult> _uploadChunkWithRetry({
    required File file,
    required String fileName,
    required String fileHash,
    required int chunkIndex,
    required int totalChunks,
    required int chunkSize,
    required int fileSize,
  }) async {
    for (int attempt = 0; attempt <= _retryCount; attempt++) {
      try {
        final result = await _uploadSingleChunk(
          file: file,
          fileName: fileName,
          fileHash: fileHash,
          chunkIndex: chunkIndex,
          totalChunks: totalChunks,
          chunkSize: chunkSize,
          fileSize: fileSize,
        );

        if (result.success) {
          return result;
        }

        if (attempt < _retryCount) {
          print('🔄 分片 $chunkIndex 上传失败，${_retryCount - attempt}次重试中...');
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        if (attempt < _retryCount) {
          print('🔄 分片 $chunkIndex 上传异常: $e，${_retryCount - attempt}次重试中...');
          await Future.delayed(_retryDelay);
        } else {
          return ChunkUploadResult(
            chunkIndex: chunkIndex,
            success: false,
            error: e.toString(),
            bytesUploaded: 0,
          );
        }
      }
    }

    return ChunkUploadResult(
      chunkIndex: chunkIndex,
      success: false,
      error: '重试次数用尽',
      bytesUploaded: 0,
    );
  }

  /// 上传单个分片
  Future<ChunkUploadResult> _uploadSingleChunk({
    required File file,
    required String fileName,
    required String fileHash,
    required int chunkIndex,
    required int totalChunks,
    required int chunkSize,
    required int fileSize,
  }) async {
    final start = chunkIndex * chunkSize;
    final end = (chunkIndex + 1) * chunkSize;
    final actualEnd = end > fileSize ? fileSize : end;
    final chunkData = file.openRead(start, actualEnd);

    final url = '$_baseUrl/upload-chunk';
    final request = http.MultipartRequest('POST', Uri.parse(url));

    // 添加分片数据
    request.files.add(http.MultipartFile(
      'chunk',
      chunkData,
      actualEnd - start,
      filename: '$fileName.part$chunkIndex',
    ));

    // 添加元数据
    request.fields.addAll({
      'fileName': fileName,
      'fileHash': fileHash,
      'chunkIndex': chunkIndex.toString(),
      'totalChunks': totalChunks.toString(),
      'chunkSize': chunkSize.toString(),
      'fileSize': fileSize.toString(),
    });

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return ChunkUploadResult(
        chunkIndex: chunkIndex,
        success: true,
        bytesUploaded: actualEnd - start,
      );
    } else {
      return ChunkUploadResult(
        chunkIndex: chunkIndex,
        success: false,
        error: 'HTTP ${response.statusCode}: $responseBody',
        bytesUploaded: 0,
      );
    }
  }

  /// 发送初始化请求
  Future<bool> _sendInitializeRequest({
    required String fileName,
    required String fileSize,
  }) async {
    try {
      final url = '$_baseUrl/initialize-concurrent-upload';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "fileName": "$fileName",
          "fileSize": $fileSize
        }
        ''',
      );

      if (response.statusCode == 200) {
        print('✅ 初始化请求成功');
        return true;
      } else if (response.statusCode == 403) {
        print('❌ 接收端拒绝了文件传输');
        return false;
      } else {
        print('❌ 初始化请求失败: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 初始化请求异常: $e');
      return false;
    }
  }

  /// 通知服务器合并文件
  Future<bool> notifyMerge({
    required String fileName,
    required String fileHash,
    required int totalChunks,
  }) async {
    try {
      final url = '$_baseUrl/merge-file';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "fileName": "$fileName",
          "fileHash": "$fileHash",
          "totalChunks": $totalChunks
        }
        ''',
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ 合并通知失败: $e');
      return false;
    }
  }
}
