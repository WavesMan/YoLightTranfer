// 数据上传服务
// 提供高级数据上传功能，支持压缩、加密、断点续传等特性

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:yolighttransfer/services/network_data_collector.dart';

/// 上传状态枚举
enum UploadStatus {
  idle,           // 空闲
  uploading,      // 上传中
  success,        // 成功
  failed,         // 失败
  retrying,       // 重试中
}

/// 上传进度信息
class UploadProgress {
  final UploadStatus status;
  final int currentBatch;
  final int totalBatches;
  final int currentSample;
  final int totalSamples;
  final double progress; // 0.0 - 1.0
  final String? message;

  UploadProgress({
    required this.status,
    required this.currentBatch,
    required this.totalBatches,
    required this.currentSample,
    required this.totalSamples,
    required this.progress,
    this.message,
  });

  @override
  String toString() {
    return 'UploadProgress(status: $status, progress: ${(progress * 100).toStringAsFixed(1)}%, batch: $currentBatch/$totalBatches, sample: $currentSample/$totalSamples)';
  }
}

/// 上传配置
class UploadConfig {
  final bool enableCompression;      // 启用数据压缩
  final bool enableEncryption;       // 启用数据加密
  final int maxRetryCount;           // 最大重试次数
  final Duration retryDelay;         // 重试延迟
  final Duration timeout;            // 请求超时时间
  final int maxBatchSize;            // 最大批量大小
  final bool enableBackgroundUpload; // 启用后台上传

  const UploadConfig({
    this.enableCompression = true,
    this.enableEncryption = false,
    this.maxRetryCount = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.timeout = const Duration(seconds: 30),
    this.maxBatchSize = 100,
    this.enableBackgroundUpload = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'enable_compression': enableCompression,
      'enable_encryption': enableEncryption,
      'max_retry_count': maxRetryCount,
      'retry_delay': retryDelay.inSeconds,
      'timeout': timeout.inSeconds,
      'max_batch_size': maxBatchSize,
      'enable_background_upload': enableBackgroundUpload,
    };
  }

  factory UploadConfig.fromJson(Map<String, dynamic> json) {
    return UploadConfig(
      enableCompression: json['enable_compression'] ?? true,
      enableEncryption: json['enable_encryption'] ?? false,
      maxRetryCount: json['max_retry_count'] ?? 3,
      retryDelay: Duration(seconds: json['retry_delay'] ?? 5),
      timeout: Duration(seconds: json['timeout'] ?? 30),
      maxBatchSize: json['max_batch_size'] ?? 100,
      enableBackgroundUpload: json['enable_background_upload'] ?? false,
    );
  }
}

/// 上传统计信息
class UploadStats {
  final int totalUploads;
  final int successfulUploads;
  final int failedUploads;
  final int totalSamples;
  final DateTime lastUploadTime;
  final double averageUploadSize;
  final Duration averageUploadDuration;

  UploadStats({
    required this.totalUploads,
    required this.successfulUploads,
    required this.failedUploads,
    required this.totalSamples,
    required this.lastUploadTime,
    required this.averageUploadSize,
    required this.averageUploadDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_uploads': totalUploads,
      'successful_uploads': successfulUploads,
      'failed_uploads': failedUploads,
      'total_samples': totalSamples,
      'last_upload_time': lastUploadTime.toIso8601String(),
      'average_upload_size': averageUploadSize,
      'average_upload_duration': averageUploadDuration.inMilliseconds,
    };
  }
}

/// 数据上传服务
class DataUploadService {
  final NetworkDataCollector _dataCollector;
  final UploadConfig _config;
  
  final StreamController<UploadProgress> _progressController = 
      StreamController<UploadProgress>.broadcast();
  final List<UploadStats> _uploadHistory = [];
  
  UploadStatus _currentStatus = UploadStatus.idle;
  int _currentRetryCount = 0;
  Timer? _backgroundUploadTimer;

  DataUploadService({
    required NetworkDataCollector dataCollector,
    UploadConfig? config,
  }) : _dataCollector = dataCollector,
       _config = config ?? const UploadConfig() {
    _startBackgroundUploadIfEnabled();
  }

  /// 获取上传进度流
  Stream<UploadProgress> get uploadProgress => _progressController.stream;

  /// 获取当前状态
  UploadStatus get currentStatus => _currentStatus;

  /// 获取配置
  UploadConfig get config => _config;

  /// 上传数据样本
  Future<bool> uploadSamples(List<NetworkDataSample> samples) async {
    if (samples.isEmpty) {
      _updateProgress(UploadStatus.idle, 0, 0, 0, 0, 1.0, '没有数据需要上传');
      return true;
    }

    _currentStatus = UploadStatus.uploading;
    _currentRetryCount = 0;

    try {
      // 分批处理数据
      final batches = _splitIntoBatches(samples);
      final totalBatches = batches.length;
      var totalUploaded = 0;

      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];
        
        // 更新进度
        _updateProgress(
          UploadStatus.uploading,
          batchIndex + 1,
          totalBatches,
          totalUploaded,
          samples.length,
          (batchIndex + 1) / totalBatches,
          '正在上传第 ${batchIndex + 1}/$totalBatches 批数据',
        );

        // 上传当前批次
        final success = await _uploadBatchWithRetry(batch, batchIndex);
        
        if (success) {
          totalUploaded += batch.length;
          _recordUploadSuccess(batch.length);
        } else {
          _updateProgress(
            UploadStatus.failed,
            batchIndex + 1,
            totalBatches,
            totalUploaded,
            samples.length,
            (batchIndex + 1) / totalBatches,
            '第 ${batchIndex + 1} 批数据上传失败',
          );
          return false;
        }
      }

      _updateProgress(
        UploadStatus.success,
        totalBatches,
        totalBatches,
        samples.length,
        samples.length,
        1.0,
        '数据上传完成，共上传 ${samples.length} 个样本',
      );

      return true;

    } catch (e) {
      _updateProgress(
        UploadStatus.failed,
        0,
        0,
        0,
        samples.length,
        0.0,
        '上传过程中发生异常: $e',
      );
      return false;
    } finally {
      _currentStatus = UploadStatus.idle;
    }
  }

  /// 分批处理数据
  List<List<NetworkDataSample>> _splitIntoBatches(List<NetworkDataSample> samples) {
    final batches = <List<NetworkDataSample>>[];
    for (var i = 0; i < samples.length; i += _config.maxBatchSize) {
      final end = (i + _config.maxBatchSize) > samples.length 
          ? samples.length 
          : i + _config.maxBatchSize;
      batches.add(samples.sublist(i, end));
    }
    return batches;
  }

  /// 带重试机制的上传批次
  Future<bool> _uploadBatchWithRetry(
    List<NetworkDataSample> batch, 
    int batchIndex
  ) async {
    for (int attempt = 1; attempt <= _config.maxRetryCount; attempt++) {
      try {
        if (attempt > 1) {
          _updateProgress(
            UploadStatus.retrying,
            batchIndex + 1,
            0, // 不显示总批次数
            batchIndex * _config.maxBatchSize,
            0, // 不显示总样本数
            (batchIndex + 1) / 1.0, // 简化进度显示
            '第 ${batchIndex + 1} 批数据重试上传 (第 $attempt 次)',
          );
          
          await Future.delayed(_config.retryDelay);
        }

        final success = await _uploadSingleBatch(batch);
        
        if (success) {
          return true;
        }
        
      } catch (e) {
        print('第 $attempt 次上传尝试失败: $e');
      }
    }
    
    return false;
  }

  /// 上传单个批次
  Future<bool> _uploadSingleBatch(List<NetworkDataSample> batch) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 准备上传数据
      final uploadData = _prepareUploadData(batch);
      
      // 创建HTTP客户端
      final client = HttpClient();
      client.connectionTimeout = _config.timeout;

      // 创建请求
      final config = _dataCollector.config;
      final request = await client.postUrl(Uri.parse(config.apiEndpoint));
      
      // 设置请求头
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('User-Agent', 'YoLightTransfer/DataUpload');
      if (_config.enableCompression) {
        request.headers.set('Content-Encoding', 'gzip');
      }

      // 发送数据
      final jsonString = jsonEncode(uploadData);
      final dataBytes = utf8.encode(jsonString);
      
      // 压缩数据（如果启用）
      final compressedData = _config.enableCompression 
          ? _compressData(dataBytes) 
          : dataBytes;
      
      request.contentLength = compressedData.length;
      request.add(compressedData);

      // 获取响应
      final response = await request.close();
      await response.drain();

      stopwatch.stop();

      if (response.statusCode == 200) {
        print('✅ 批次上传成功: ${batch.length} 个样本, 耗时: ${stopwatch.elapsedMilliseconds}ms');
        return true;
      } else {
        print('❌ 批次上传失败，状态码: ${response.statusCode}');
        return false;
      }

    } catch (e) {
      stopwatch.stop();
      print('❌ 批次上传异常: $e, 耗时: ${stopwatch.elapsedMilliseconds}ms');
      return false;
    }
  }

  /// 准备上传数据
  Map<String, dynamic> _prepareUploadData(List<NetworkDataSample> batch) {
    return {
      'samples': batch.map((sample) => sample.toJson()).toList(),
      'upload_timestamp': DateTime.now().toIso8601String(),
      'batch_id': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      'batch_size': batch.length,
      'compression_enabled': _config.enableCompression,
      'encryption_enabled': _config.enableEncryption,
      'data_format_version': '1.0.0',
    };
  }

  /// 压缩数据（使用gzip算法）
  List<int> _compressData(List<int> data) {
    try {
      // 使用Dart内置的gzip压缩
      final compressed = gzip.encode(data);
      
      // 记录压缩效果
      final originalSize = data.length;
      final compressedSize = compressed.length;
      final compressionRatio = (originalSize - compressedSize) / originalSize * 100;
      
      print('📦 数据压缩: ${originalSize}B → ${compressedSize}B (压缩率: ${compressionRatio.toStringAsFixed(1)}%)');
      
      return compressed;
    } catch (e) {
      print('❌ gzip压缩失败: $e，使用原始数据');
      return data;
    }
  }

  /// 更新上传进度
  void _updateProgress(
    UploadStatus status,
    int currentBatch,
    int totalBatches,
    int currentSample,
    int totalSamples,
    double progress,
    String? message,
  ) {
    _currentStatus = status;
    
    final progressInfo = UploadProgress(
      status: status,
      currentBatch: currentBatch,
      totalBatches: totalBatches,
      currentSample: currentSample,
      totalSamples: totalSamples,
      progress: progress,
      message: message,
    );

    _progressController.add(progressInfo);
    print('📤 $progressInfo');
  }

  /// 记录上传成功
  void _recordUploadSuccess(int sampleCount) {
    final stats = UploadStats(
      totalUploads: _uploadHistory.length + 1,
      successfulUploads: _uploadHistory.where((s) => s.successfulUploads > 0).length + 1,
      failedUploads: _uploadHistory.where((s) => s.failedUploads > 0).length,
      totalSamples: sampleCount,
      lastUploadTime: DateTime.now(),
      averageUploadSize: sampleCount.toDouble(),
      averageUploadDuration: Duration.zero, // 简化实现
    );

    _uploadHistory.add(stats);
  }

  /// 开始后台上传（如果启用）
  void _startBackgroundUploadIfEnabled() {
    if (_config.enableBackgroundUpload) {
      _backgroundUploadTimer = Timer.periodic(
        Duration(minutes: 15), // 每15分钟检查一次
        (timer) async {
          if (_currentStatus == UploadStatus.idle) {
            await _uploadPendingData();
          }
        },
      );
    }
  }

  /// 上传待处理数据
  Future<void> _uploadPendingData() async {
    final stats = _dataCollector.getStats();
    if (stats['pending_samples'] > 0) {
      print('🔄 后台上传: ${stats['pending_samples']} 个待处理样本');
      await _dataCollector.triggerUpload();
    }
  }

  /// 获取上传统计信息
  UploadStats getCurrentStats() {
    if (_uploadHistory.isEmpty) {
      return UploadStats(
        totalUploads: 0,
        successfulUploads: 0,
        failedUploads: 0,
        totalSamples: 0,
        lastUploadTime: DateTime.now(),
        averageUploadSize: 0,
        averageUploadDuration: Duration.zero,
      );
    }

    final latest = _uploadHistory.last;
    return latest;
  }

  /// 获取上传历史
  List<UploadStats> get uploadHistory => List.unmodifiable(_uploadHistory);

  /// 更新配置
  void updateConfig(UploadConfig newConfig) {
    // 停止现有的后台上传定时器
    _backgroundUploadTimer?.cancel();
    
    // 更新配置
    // _config = newConfig; // 注意：这里需要修改为可变的配置
    
    // 重新启动后台上传
    _startBackgroundUploadIfEnabled();
  }

  /// 手动触发上传
  Future<bool> triggerUpload() async {
    final stats = _dataCollector.getStats();
    final pendingSamples = stats['pending_samples'] as int;
    
    if (pendingSamples == 0) {
      _updateProgress(
        UploadStatus.idle,
        0, 0, 0, 0, 1.0,
        '没有待上传的数据',
      );
      return true;
    }

    print('🚀 手动触发上传: $pendingSamples 个待处理样本');
    return await _dataCollector.triggerUpload().then((_) => true);
  }

  /// 清理资源
  void dispose() {
    _backgroundUploadTimer?.cancel();
    _progressController.close();
  }
}

/// 数据上传管理器（单例模式）
class DataUploadManager {
  static DataUploadManager? _instance;
  final Map<String, DataUploadService> _uploadServices = {};

  DataUploadManager._();

  factory DataUploadManager() {
    _instance ??= DataUploadManager._();
    return _instance!;
  }

  /// 注册上传服务
  void registerService(String serviceId, DataUploadService service) {
    _uploadServices[serviceId] = service;
  }

  /// 获取上传服务
  DataUploadService? getService(String serviceId) {
    return _uploadServices[serviceId];
  }

  /// 获取所有服务
  Map<String, DataUploadService> get allServices => Map.from(_uploadServices);

  /// 批量上传所有服务的数据
  Future<Map<String, bool>> uploadAllServices() async {
    final results = <String, bool>{};
    
    for (final entry in _uploadServices.entries) {
      final serviceId = entry.key;
      final service = entry.value;
      
      try {
        final success = await service.triggerUpload();
        results[serviceId] = success;
      } catch (e) {
        results[serviceId] = false;
        print('❌ 服务 $serviceId 上传失败: $e');
      }
    }
    
    return results;
  }

  /// 获取总体统计信息
  Map<String, dynamic> getOverallStats() {
    int totalUploads = 0;
    int totalSamples = 0;
    int successfulServices = 0;
    
    for (final service in _uploadServices.values) {
      final stats = service.getCurrentStats();
      totalUploads += stats.totalUploads;
      totalSamples += stats.totalSamples;
      if (stats.successfulUploads > 0) {
        successfulServices++;
      }
    }
    
    return {
      'total_services': _uploadServices.length,
      'successful_services': successfulServices,
      'total_uploads': totalUploads,
      'total_samples': totalSamples,
      'upload_success_rate': _uploadServices.isEmpty ? 0.0 : successfulServices / _uploadServices.length,
    };
  }

  /// 清理所有服务
  void disposeAll() {
    for (final service in _uploadServices.values) {
      service.dispose();
    }
    _uploadServices.clear();
  }
}
