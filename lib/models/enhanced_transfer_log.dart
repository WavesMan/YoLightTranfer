import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/models/transfer_state.dart';
import 'package:yolighttransfer/models/transfer_log.dart';

/// 增强的传输日志条目 - 包含详细的传输状态和校验信息
class EnhancedTransferLog {
  final String id;
  final TransferLogType type;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String? savePath;
  final DiscoveredDevice? targetDevice;
  final DiscoveredDevice? sourceDevice;
  final DateTime timestamp;
  final String message;
  final bool success;
  final String? error;
  final int? progress;
  final String? transferSpeed;
  final String? estimatedTime;

  // 新增字段
  final TransferState transferState;
  final ConnectionQuality connectionQuality;
  final FileVerificationResult verificationResult;
  final String? fileHash;
  final String? expectedHash;
  final int? bytesTransferred;
  final int? totalBytes;
  final DateTime? transferStartTime;
  final DateTime? transferEndTime;
  final List<TransferStateChange> stateChanges;
  final Map<String, dynamic>? additionalInfo;

  EnhancedTransferLog({
    required this.id,
    required this.type,
    required this.fileName,
    required this.fileSize,
    this.filePath,
    this.savePath,
    this.targetDevice,
    this.sourceDevice,
    required this.timestamp,
    required this.message,
    required this.success,
    this.error,
    this.progress,
    this.transferSpeed,
    this.estimatedTime,
    required this.transferState,
    required this.connectionQuality,
    required this.verificationResult,
    this.fileHash,
    this.expectedHash,
    this.bytesTransferred,
    this.totalBytes,
    this.transferStartTime,
    this.transferEndTime,
    required this.stateChanges,
    this.additionalInfo,
  });

  /// 从基础TransferLog创建增强日志
  factory EnhancedTransferLog.fromBaseLog(
    TransferLog baseLog, {
    TransferState transferState = TransferState.pending,
    ConnectionQuality connectionQuality = ConnectionQuality.excellent,
    FileVerificationResult verificationResult = FileVerificationResult.pending,
    String? fileHash,
    String? expectedHash,
    int? bytesTransferred,
    int? totalBytes,
    DateTime? transferStartTime,
    DateTime? transferEndTime,
    List<TransferStateChange>? stateChanges,
    Map<String, dynamic>? additionalInfo,
  }) {
    return EnhancedTransferLog(
      id: baseLog.id,
      type: baseLog.type,
      fileName: baseLog.fileName,
      fileSize: baseLog.fileSize,
      filePath: baseLog.filePath,
      savePath: baseLog.savePath,
      targetDevice: baseLog.targetDevice,
      sourceDevice: baseLog.sourceDevice,
      timestamp: baseLog.timestamp,
      message: baseLog.message,
      success: baseLog.success,
      error: baseLog.error,
      progress: baseLog.progress,
      transferSpeed: baseLog.transferSpeed,
      estimatedTime: baseLog.estimatedTime,
      transferState: transferState,
      connectionQuality: connectionQuality,
      verificationResult: verificationResult,
      fileHash: fileHash,
      expectedHash: expectedHash,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      transferStartTime: transferStartTime,
      transferEndTime: transferEndTime,
      stateChanges: stateChanges ?? [],
      additionalInfo: additionalInfo,
    );
  }

  /// 转换为Map用于存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
      'savePath': savePath,
      'targetDevice': targetDevice?.toJson(),
      'sourceDevice': sourceDevice?.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'message': message,
      'success': success,
      'error': error,
      'progress': progress,
      'transferSpeed': transferSpeed,
      'estimatedTime': estimatedTime,
      'transferState': transferState.toString(),
      'connectionQuality': connectionQuality.toString(),
      'verificationResult': verificationResult.toString(),
      'fileHash': fileHash,
      'expectedHash': expectedHash,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'transferStartTime': transferStartTime?.millisecondsSinceEpoch,
      'transferEndTime': transferEndTime?.millisecondsSinceEpoch,
      'stateChanges': stateChanges.map((change) => change.toMap()).toList(),
      'additionalInfo': additionalInfo,
    };
  }

  /// 从Map创建增强日志
  factory EnhancedTransferLog.fromMap(Map<String, dynamic> map) {
    return EnhancedTransferLog(
      id: map['id'] ?? '',
      type: TransferLogType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => TransferLogType.info,
      ),
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      filePath: map['filePath'],
      savePath: map['savePath'],
      targetDevice: map['targetDevice'] != null 
          ? DiscoveredDevice.fromBroadcast(Map<String, dynamic>.from(map['targetDevice']), '')
          : null,
      sourceDevice: map['sourceDevice'] != null
          ? DiscoveredDevice.fromBroadcast(Map<String, dynamic>.from(map['sourceDevice']), '')
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      message: map['message'] ?? '',
      success: map['success'] ?? false,
      error: map['error'],
      progress: map['progress'],
      transferSpeed: map['transferSpeed'],
      estimatedTime: map['estimatedTime'],
      transferState: TransferState.values.firstWhere(
        (e) => e.toString() == map['transferState'],
        orElse: () => TransferState.pending,
      ),
      connectionQuality: ConnectionQuality.values.firstWhere(
        (e) => e.toString() == map['connectionQuality'],
        orElse: () => ConnectionQuality.excellent,
      ),
      verificationResult: FileVerificationResult.values.firstWhere(
        (e) => e.toString() == map['verificationResult'],
        orElse: () => FileVerificationResult.pending,
      ),
      fileHash: map['fileHash'],
      expectedHash: map['expectedHash'],
      bytesTransferred: map['bytesTransferred'],
      totalBytes: map['totalBytes'],
      transferStartTime: map['transferStartTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['transferStartTime'])
          : null,
      transferEndTime: map['transferEndTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['transferEndTime'])
          : null,
      stateChanges: (map['stateChanges'] as List<dynamic>?)
          ?.map((change) => TransferStateChange.fromMap(Map<String, dynamic>.from(change)))
          .toList() ?? [],
      additionalInfo: map['additionalInfo'] != null
          ? Map<String, dynamic>.from(map['additionalInfo'])
          : null,
    );
  }

  /// 获取传输持续时间
  Duration? get transferDuration {
    if (transferStartTime != null && transferEndTime != null) {
      return transferEndTime!.difference(transferStartTime!);
    }
    return null;
  }

  /// 获取平均传输速度
  String? get averageTransferSpeed {
    final duration = transferDuration;
    if (duration != null && bytesTransferred != null && duration.inSeconds > 0) {
      final speed = bytesTransferred! / duration.inSeconds;
      final double speedDouble = speed.toDouble();
      if (speedDouble < 1024) return '${speedDouble.toStringAsFixed(1)} B/s';
      if (speedDouble < 1024 * 1024) return '${(speedDouble / 1024).toStringAsFixed(1)} KB/s';
      return '${(speedDouble / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return null;
  }

  /// 获取校验状态描述
  String get verificationStatus {
    switch (verificationResult) {
      case FileVerificationResult.pending:
        return '等待校验';
      case FileVerificationResult.success:
        return fileHash != null ? '校验成功 (SHA256: ${fileHash!.substring(0, 16)}...)' : '校验成功';
      case FileVerificationResult.failed:
        return '校验失败';
      case FileVerificationResult.skipped:
        return '跳过校验';
    }
  }

  /// 获取详细的传输状态描述
  String get detailedStatus {
    final status = StringBuffer();
    status.write('状态: ${transferState.text} ${transferState.icon}');
    
    if (connectionQuality != ConnectionQuality.excellent) {
      status.write(' | 连接: ${connectionQuality.text} ${connectionQuality.icon}');
    }
    
    if (verificationResult != FileVerificationResult.pending) {
      status.write(' | 校验: ${verificationResult.text} ${verificationResult.icon}');
    }
    
    return status.toString();
  }

  /// 转换为基础TransferLog（用于兼容现有代码）
  TransferLog toBaseLog() {
    return TransferLog(
      id: id,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      savePath: savePath,
      targetDevice: targetDevice,
      sourceDevice: sourceDevice,
      timestamp: timestamp,
      message: message,
      success: success,
      error: error,
      progress: progress,
      transferSpeed: transferSpeed,
      estimatedTime: estimatedTime,
    );
  }
}

/// 传输状态变更记录
class TransferStateChange {
  final TransferState fromState;
  final TransferState toState;
  final DateTime timestamp;
  final String? reason;

  TransferStateChange({
    required this.fromState,
    required this.toState,
    required this.timestamp,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'fromState': fromState.toString(),
      'toState': toState.toString(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  factory TransferStateChange.fromMap(Map<String, dynamic> map) {
    return TransferStateChange(
      fromState: TransferState.values.firstWhere(
        (e) => e.toString() == map['fromState'],
        orElse: () => TransferState.pending,
      ),
      toState: TransferState.values.firstWhere(
        (e) => e.toString() == map['toState'],
        orElse: () => TransferState.pending,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      reason: map['reason'],
    );
  }

  /// 获取状态变更描述
  String get description {
    final desc = '${fromState.text} → ${toState.text}';
    if (reason != null) {
      return '$desc ($reason)';
    }
    return desc;
  }
}

/// 传输统计信息
class TransferStatistics {
  final int totalTransfers;
  final int successfulTransfers;
  final int failedTransfers;
  final int cancelledTransfers;
  final double successRate;
  final int totalBytesTransferred;
  final Duration totalTransferTime;
  final double averageTransferSpeed;
  final Map<TransferState, int> stateDistribution;
  final Map<ConnectionQuality, int> connectionQualityDistribution;
  final Map<FileVerificationResult, int> verificationResultDistribution;

  TransferStatistics({
    required this.totalTransfers,
    required this.successfulTransfers,
    required this.failedTransfers,
    required this.cancelledTransfers,
    required this.successRate,
    required this.totalBytesTransferred,
    required this.totalTransferTime,
    required this.averageTransferSpeed,
    required this.stateDistribution,
    required this.connectionQualityDistribution,
    required this.verificationResultDistribution,
  });

  /// 从日志列表计算统计信息
  factory TransferStatistics.fromLogs(List<EnhancedTransferLog> logs) {
    final totalTransfers = logs.length;
    final successfulTransfers = logs.where((log) => log.success).length;
    final failedTransfers = logs.where((log) => log.transferState == TransferState.failed).length;
    final cancelledTransfers = logs.where((log) => log.transferState == TransferState.cancelled).length;
    final successRate = totalTransfers > 0 ? (successfulTransfers / totalTransfers * 100).toDouble() : 0.0;

    int totalBytes = 0;
    int totalSeconds = 0;
    final stateDistribution = <TransferState, int>{};
    final connectionQualityDistribution = <ConnectionQuality, int>{};
    final verificationResultDistribution = <FileVerificationResult, int>{};

    for (final log in logs) {
      totalBytes += log.bytesTransferred ?? 0;
      
      final duration = log.transferDuration;
      if (duration != null) {
        totalSeconds += duration.inSeconds;
      }

      stateDistribution.update(
        log.transferState,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      connectionQualityDistribution.update(
        log.connectionQuality,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      verificationResultDistribution.update(
        log.verificationResult,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final averageTransferSpeed = totalSeconds > 0 ? totalBytes.toDouble() / totalSeconds : 0.0;

    return TransferStatistics(
      totalTransfers: totalTransfers,
      successfulTransfers: successfulTransfers,
      failedTransfers: failedTransfers,
      cancelledTransfers: cancelledTransfers,
      successRate: successRate,
      totalBytesTransferred: totalBytes,
      totalTransferTime: Duration(seconds: totalSeconds),
      averageTransferSpeed: averageTransferSpeed,
      stateDistribution: stateDistribution,
      connectionQualityDistribution: connectionQualityDistribution,
      verificationResultDistribution: verificationResultDistribution,
    );
  }
}
