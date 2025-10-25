import 'dart:async';
import 'dart:io';

/// 传输性能监控器
class TransferPerformanceMonitor {
  static final TransferPerformanceMonitor _instance = TransferPerformanceMonitor._internal();
  
  factory TransferPerformanceMonitor() => _instance;
  
  TransferPerformanceMonitor._internal();

  /// 性能数据记录
  final Map<String, PerformanceRecord> _records = {};

  /// 开始监控传输
  String startMonitoring({
    required String fileName,
    required int fileSize,
    required String transferType,
    required bool useConcurrent,
    int maxConcurrent = 1,
  }) {
    final recordId = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    
    _records[recordId] = PerformanceRecord(
      id: recordId,
      fileName: fileName,
      fileSize: fileSize,
      transferType: transferType,
      useConcurrent: useConcurrent,
      maxConcurrent: maxConcurrent,
      startTime: DateTime.now(),
    );

    print('📊 开始性能监控: $fileName ($transferType)');
    return recordId;
  }

  /// 记录哈希计算完成
  void recordHashComplete(String recordId, Duration duration) {
    final record = _records[recordId];
    if (record != null) {
      record.hashDuration = duration;
      print('🔐 哈希计算耗时: ${duration.inMilliseconds}ms');
    }
  }

  /// 记录传输开始
  void recordTransferStart(String recordId) {
    final record = _records[recordId];
    if (record != null) {
      record.transferStartTime = DateTime.now();
    }
  }

  /// 记录传输进度
  void recordTransferProgress(String recordId, int uploadedBytes, int totalBytes) {
    final record = _records[recordId];
    if (record != null) {
      record.currentBytes = uploadedBytes;
      record.totalBytes = totalBytes;
      
      final progress = (uploadedBytes / totalBytes * 100).toInt();
      if (progress % 10 == 0 && progress != record.lastProgress) {
        print('📈 传输进度: $progress%');
        record.lastProgress = progress;
      }
    }
  }

  /// 记录传输完成
  void recordTransferComplete(String recordId) {
    final record = _records[recordId];
    if (record != null) {
      record.transferEndTime = DateTime.now();
      record.isComplete = true;
      
      final transferDuration = record.transferDuration;
      final hashDuration = record.hashDuration?.inMilliseconds ?? 0;
      final totalDuration = record.totalDuration.inMilliseconds;
      
      print('''
🎯 传输性能报告:
  文件: ${record.fileName}
  大小: ${_formatBytes(record.fileSize)}
  类型: ${record.transferType}
  并发: ${record.useConcurrent ? '是 (${record.maxConcurrent}线程)' : '否'}
  哈希耗时: ${hashDuration}ms
  传输耗时: ${transferDuration.inMilliseconds}ms
  总耗时: ${totalDuration}ms
  平均速度: ${_formatBytes((record.fileSize / transferDuration.inMilliseconds * 1000).toInt())}/s
      ''');
    }
  }

  /// 获取性能报告
  PerformanceRecord? getRecord(String recordId) {
    return _records[recordId];
  }

  /// 获取所有记录
  List<PerformanceRecord> getAllRecords() {
    return _records.values.toList();
  }

  /// 清理旧记录
  void cleanupOldRecords({Duration maxAge = const Duration(hours: 24)}) {
    final cutoffTime = DateTime.now().subtract(maxAge);
    _records.removeWhere((key, record) => record.startTime.isBefore(cutoffTime));
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// 性能记录
class PerformanceRecord {
  final String id;
  final String fileName;
  final int fileSize;
  final String transferType;
  final bool useConcurrent;
  final int maxConcurrent;
  final DateTime startTime;
  
  DateTime? transferStartTime;
  DateTime? transferEndTime;
  Duration? hashDuration;
  int currentBytes = 0;
  int totalBytes = 0;
  int lastProgress = 0;
  bool isComplete = false;

  PerformanceRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.transferType,
    required this.useConcurrent,
    required this.maxConcurrent,
    required this.startTime,
  });

  /// 获取传输耗时
  Duration get transferDuration {
    if (transferStartTime == null || transferEndTime == null) {
      return Duration.zero;
    }
    return transferEndTime!.difference(transferStartTime!);
  }

  /// 获取总耗时
  Duration get totalDuration {
    if (isComplete) {
      return transferEndTime!.difference(startTime);
    }
    return DateTime.now().difference(startTime);
  }

  /// 获取传输速度 (bytes/s)
  double get transferSpeed {
    final durationMs = transferDuration.inMilliseconds;
    if (durationMs == 0) return 0;
    return fileSize / (durationMs / 1000);
  }

  /// 获取进度百分比
  double get progress {
    if (totalBytes == 0) return 0;
    return currentBytes / totalBytes * 100;
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'transferType': transferType,
      'useConcurrent': useConcurrent,
      'maxConcurrent': maxConcurrent,
      'startTime': startTime.toIso8601String(),
      'transferStartTime': transferStartTime?.toIso8601String(),
      'transferEndTime': transferEndTime?.toIso8601String(),
      'hashDuration': hashDuration?.inMilliseconds,
      'currentBytes': currentBytes,
      'totalBytes': totalBytes,
      'progress': progress,
      'isComplete': isComplete,
      'transferDuration': transferDuration.inMilliseconds,
      'totalDuration': totalDuration.inMilliseconds,
      'transferSpeed': transferSpeed,
    };
  }
}

/// 性能比较工具
class PerformanceComparator {
  /// 比较两个传输的性能
  static void comparePerformance(PerformanceRecord record1, PerformanceRecord record2) {
    if (!record1.isComplete || !record2.isComplete) {
      print('⚠️ 无法比较：传输未完成');
      return;
    }

    final speed1 = record1.transferSpeed;
    final speed2 = record2.transferSpeed;
    final duration1 = record1.totalDuration.inMilliseconds;
    final duration2 = record2.totalDuration.inMilliseconds;

    final speedRatio = speed2 / speed1;
    final durationRatio = duration1 / duration2;

    print('''
📊 性能比较报告:
  
  传输1 (${record1.useConcurrent ? '并发' : '顺序'}):
    - 文件: ${record1.fileName}
    - 大小: ${_formatBytes(record1.fileSize)}
    - 耗时: ${duration1}ms
    - 速度: ${_formatBytes(speed1.toInt())}/s
  
  传输2 (${record2.useConcurrent ? '并发' : '顺序'}):
    - 文件: ${record2.fileName}
    - 大小: ${_formatBytes(record2.fileSize)}
    - 耗时: ${duration2}ms
    - 速度: ${_formatBytes(speed2.toInt())}/s
  
  性能提升:
    - 速度提升: ${(speedRatio - 1) * 100}%
    - 时间减少: ${(durationRatio - 1) * 100}%
    ''');
  }

  /// 格式化字节大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
