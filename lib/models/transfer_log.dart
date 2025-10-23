import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/models/transfer_state.dart';

/// 传输日志类型
enum TransferLogType {
  send,    // 发送
  receive, // 接收
  error,   // 错误
  info,    // 信息
  tcp,     // TCP连接传输流程
  hash,    // 哈希校验
  network, // 网络状态
}

/// 传输日志条目
class TransferLog {
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

  TransferLog({
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
  });

  /// 创建发送文件日志
  factory TransferLog.sendStart({
    required String fileName,
    required int fileSize,
    required String filePath,
    required DiscoveredDevice targetDevice,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_send_${fileName.hashCode}',
      type: TransferLogType.send,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      targetDevice: targetDevice,
      timestamp: DateTime.now(),
      message: '开始发送文件: $fileName 到 ${targetDevice.name}',
      success: true,
      progress: 0,
    );
  }

  /// 创建接收文件日志
  factory TransferLog.receiveStart({
    required String fileName,
    required int fileSize,
    required String savePath,
    required DiscoveredDevice sourceDevice,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_receive_${fileName.hashCode}',
      type: TransferLogType.receive,
      fileName: fileName,
      fileSize: fileSize,
      savePath: savePath,
      sourceDevice: sourceDevice,
      timestamp: DateTime.now(),
      message: '开始接收文件: $fileName 来自 ${sourceDevice.name}',
      success: true,
      progress: 0,
    );
  }

  /// 创建传输进度日志
  factory TransferLog.progress({
    required String id,
    required TransferLogType type,
    required String fileName,
    required int progress,
    String? transferSpeed,
    String? estimatedTime,
  }) {
    return TransferLog(
      id: id,
      type: type,
      fileName: fileName,
      fileSize: 0,
      timestamp: DateTime.now(),
      message: '传输进度: $progress%',
      success: true,
      progress: progress,
      transferSpeed: transferSpeed,
      estimatedTime: estimatedTime,
    );
  }

  /// 创建传输完成日志
  factory TransferLog.complete({
    required String id,
    required TransferLogType type,
    required String fileName,
    required int fileSize,
    String? filePath,
    String? savePath,
    DiscoveredDevice? targetDevice,
    DiscoveredDevice? sourceDevice,
  }) {
    return TransferLog(
      id: id,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      savePath: savePath,
      targetDevice: targetDevice,
      sourceDevice: sourceDevice,
      timestamp: DateTime.now(),
      message: '文件传输完成: $fileName',
      success: true,
      progress: 100,
    );
  }

  /// 创建传输错误日志
  factory TransferLog.error({
    required TransferLogType type,
    required String fileName,
    required String error,
    DiscoveredDevice? targetDevice,
    DiscoveredDevice? sourceDevice,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_error_${fileName.hashCode}',
      type: TransferLogType.error,
      fileName: fileName,
      fileSize: 0,
      targetDevice: targetDevice,
      sourceDevice: sourceDevice,
      timestamp: DateTime.now(),
      message: '传输失败: $fileName - $error',
      success: false,
      error: error,
    );
  }

  /// 创建信息日志
  factory TransferLog.info({
    required String message,
    String? fileName,
    DiscoveredDevice? device,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_info_${message.hashCode}',
      type: TransferLogType.info,
      fileName: fileName ?? '',
      fileSize: 0,
      targetDevice: device,
      timestamp: DateTime.now(),
      message: message,
      success: true,
    );
  }

  /// 创建TCP连接流程日志
  factory TransferLog.tcp({
    required String message,
    String? fileName,
    String? clientAddress,
    int? fileSize,
    int? bytesTransferred,
    int? progress,
    String? transferSpeed,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_tcp_${message.hashCode}',
      type: TransferLogType.tcp,
      fileName: fileName ?? '',
      fileSize: fileSize ?? 0,
      timestamp: DateTime.now(),
      message: message,
      success: true,
      progress: progress,
      transferSpeed: transferSpeed,
    );
  }

  /// 创建哈希校验日志
  factory TransferLog.hash({
    required String message,
    required String fileName,
    String? expectedHash,
    String? actualHash,
    bool? hashValid,
    int? progress,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_hash_${fileName.hashCode}',
      type: TransferLogType.hash,
      fileName: fileName,
      fileSize: 0,
      timestamp: DateTime.now(),
      message: message,
      success: hashValid ?? true,
      progress: progress,
    );
  }

  /// 创建网络状态日志
  factory TransferLog.network({
    required String message,
    String? clientAddress,
    String? networkType,
    String? connectionState,
    int? latency,
    int? packetLoss,
  }) {
    return TransferLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_network_${message.hashCode}',
      type: TransferLogType.network,
      fileName: '',
      fileSize: 0,
      timestamp: DateTime.now(),
      message: message,
      success: true,
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
    };
  }

  /// 从Map创建日志
  factory TransferLog.fromMap(Map<String, dynamic> map) {
    return TransferLog(
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
    );
  }

  /// 获取日志类型显示文本
  String get typeText {
    switch (type) {
      case TransferLogType.send:
        return '发送';
      case TransferLogType.receive:
        return '接收';
      case TransferLogType.error:
        return '错误';
      case TransferLogType.info:
        return '信息';
      case TransferLogType.tcp:
        return 'TCP';
      case TransferLogType.hash:
        return '哈希校验';
      case TransferLogType.network:
        return '网络状态';
    }
  }

  /// 获取设备名称
  String get deviceName {
    if (type == TransferLogType.send && targetDevice != null) {
      return targetDevice!.name;
    } else if (type == TransferLogType.receive && sourceDevice != null) {
      return sourceDevice!.name;
    }
    return '未知设备';
  }

  /// 获取文件大小显示文本
  String get fileSizeText {
    if (fileSize == 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取时间显示文本
  String get timeText {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
