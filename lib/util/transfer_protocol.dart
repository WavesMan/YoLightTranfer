/// 文件传输协议定义
/// 
/// 这个文件定义了所有的传输协议帧类型和数据结构
/// 用于客户端和服务器之间的通信

/// HTTP 传输协议相关常量
/// 
/// 采用流式 HTTP 传输方式：
/// - 单连接流式传输，无分片概念
/// - 支持 Range 请求实现断点续传
/// - 内存占用低，适合超大文件传输
class HttpTransferProtocol {
  // HTTP 端点
  static const String UPLOAD_ENDPOINT = '/upload';
  static const String DOWNLOAD_ENDPOINT = '/download';
  static const String STATUS_ENDPOINT = '/status';
  
  // HTTP 请求头（流式传输）
  static const String HEADER_FILE_NAME = 'X-File-Name';
  static const String HEADER_FILE_SIZE = 'X-File-Size';
  static const String HEADER_FILE_HASH = 'X-File-Hash';
  static const String HEADER_TRANSPORT_METHOD = 'X-Transport-Method';
  
  // Range 请求相关头
  static const String HEADER_RANGE = 'Range';
  static const String HEADER_CONTENT_RANGE = 'Content-Range';
  static const String HEADER_ACCEPT_RANGES = 'Accept-Ranges';
  
  // HTTP 响应码
  static const int SUCCESS = 200;
  static const int PARTIAL_CONTENT = 206;
  static const int BAD_REQUEST = 400;
  static const int NOT_FOUND = 404;
  static const int CONFLICT = 409;
  static const int INTERNAL_ERROR = 500;
  
  // 传输方式
  static const String TRANSPORT_HTTP = 'HTTP';
  static const String TRANSPORT_STREAM = 'STREAM';
}

/// UDP 发现协议相关常量
class DiscoveryProtocol {
  // 发现相关帧类型
  static const String DEVICE_HEARTBEAT = 'DEVICE_HEARTBEAT';
  static const String DEVICE_RESPONSE = 'DEVICE_RESPONSE';
  
  // 心跳包字段
  static const String FIELD_DEVICE_ID = 'Device_ID';
  static const String FIELD_DEVICE_NAME = 'Device_Name';
  static const String FIELD_DEVICE_OS = 'Device_OS';
  static const String FIELD_TRANSPORT_METHOD = 'Transport_Method';
  static const String FIELD_HTTP_PORT = 'HTTP_Port';
  static const String FIELD_TIMESTAMP = 'Timestamp';
  static const String FIELD_NETWORK_INTERFACES = 'Network_Interfaces';
}

/// 传输计划信息
class TransferPlan {
  /// 文件名
  final String fileName;
  
  /// 文件总大小（字节）
  final int fileSize;
  
  /// 每个分片的大小（字节）
  final int chunkSize;
  
  /// 总分片数
  final int totalChunks;
  
  /// 最后一个分片的大小（字节）
  final int lastChunkSize;
  
  /// 文件哈希值（可选）
  final String? fileHash;
  
  /// 传输超时时间（秒）
  final int timeoutSeconds;

  TransferPlan({
    required this.fileName,
    required this.fileSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.lastChunkSize,
    this.fileHash,
    this.timeoutSeconds = 30,
  });

  /// 从Map创建TransferPlan
  factory TransferPlan.fromMap(Map<String, dynamic> map) {
    return TransferPlan(
      fileName: map['fileName'] as String,
      fileSize: map['fileSize'] as int,
      chunkSize: map['chunkSize'] as int,
      totalChunks: map['totalChunks'] as int,
      lastChunkSize: map['lastChunkSize'] as int,
      fileHash: map['fileHash'] as String?,
      timeoutSeconds: map['timeoutSeconds'] as int? ?? 30,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'type': 'TRANSFER_PLAN',
      'fileName': fileName,
      'fileSize': fileSize,
      'chunkSize': chunkSize,
      'totalChunks': totalChunks,
      'lastChunkSize': lastChunkSize,
      if (fileHash != null) 'fileHash': fileHash,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  /// 计算指定分片的大小
  int getChunkSizeAt(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= totalChunks) {
      throw RangeError('分片索引超出范围: $chunkIndex');
    }
    
    // 最后一个分片可能大小不同
    if (chunkIndex == totalChunks - 1) {
      return lastChunkSize;
    }
    
    return chunkSize;
  }

  /// 计算指定分片的起始位置
  int getChunkOffset(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= totalChunks) {
      throw RangeError('分片索引超出范围: $chunkIndex');
    }
    
    return chunkIndex * chunkSize;
  }

  /// 验证传输计划的有效性
  bool isValid() {
    if (fileSize <= 0) return false;
    if (chunkSize <= 0) return false;
    if (totalChunks <= 0) return false;
    if (lastChunkSize <= 0) return false;
    
    // 验证分片数计算是否正确
    final expectedTotalChunks = (fileSize + chunkSize - 1) ~/ chunkSize;
    if (totalChunks != expectedTotalChunks) return false;
    
    // 验证最后一个分片大小
    final expectedLastChunkSize = fileSize - (totalChunks - 1) * chunkSize;
    if (lastChunkSize != expectedLastChunkSize) return false;
    
    return true;
  }

  @override
  String toString() {
    return 'TransferPlan('
        'fileName=$fileName, '
        'fileSize=$fileSize, '
        'chunkSize=$chunkSize, '
        'totalChunks=$totalChunks, '
        'lastChunkSize=$lastChunkSize'
        ')';
  }
}

/// 传输统计信息
class TransferStats {
  /// 已接收/已发送的字节数
  int processedBytes = 0;
  
  /// 已接收/已发送的分片数
  int processedChunks = 0;
  
  /// 开始时间
  final DateTime startTime = DateTime.now();
  
  /// 最后更新时间
  DateTime lastUpdateTime = DateTime.now();

  /// 获取已用时间（秒）
  int get elapsedSeconds {
    return DateTime.now().difference(startTime).inSeconds;
  }

  /// 获取传输速度（KB/s）
  double get transferSpeedKBps {
    final elapsed = elapsedSeconds;
    if (elapsed == 0) return 0;
    return processedBytes / 1024 / elapsed;
  }

  /// 获取预计剩余时间（秒）
  int getEstimatedRemainingSeconds(int totalBytes) {
    final remainingBytes = totalBytes - processedBytes;
    if (transferSpeedKBps == 0) return 0;
    return (remainingBytes / 1024 / transferSpeedKBps).toInt();
  }

  /// 获取进度百分比
  int getProgressPercent(int totalBytes) {
    if (totalBytes == 0) return 0;
    return ((processedBytes / totalBytes) * 100).toInt();
  }

  @override
  String toString() {
    return 'TransferStats('
        'processedBytes=$processedBytes, '
        'processedChunks=$processedChunks, '
        'elapsedSeconds=$elapsedSeconds, '
        'speedKBps=${transferSpeedKBps.toStringAsFixed(2)}'
        ')';
  }
}

/// 传输错误类型
enum TransferErrorType {
  /// 连接错误
  connectionError,
  
  /// 文件不存在
  fileNotFound,
  
  /// 文件读写错误
  fileIOError,
  
  /// 协议错误
  protocolError,
  
  /// 超时错误
  timeoutError,
  
  /// 哈希校验失败
  hashMismatch,
  
  /// 用户取消
  userCancelled,
  
  /// 其他错误
  unknown,
}

/// 传输错误信息
class TransferError {
  /// 错误类型
  final TransferErrorType type;
  
  /// 错误消息
  final String message;
  
  /// 原始异常
  final Exception? originalException;
  
  /// 错误发生的时间
  final DateTime timestamp = DateTime.now();

  TransferError({
    required this.type,
    required this.message,
    this.originalException,
  });

  @override
  String toString() {
    return 'TransferError(type=$type, message=$message)';
  }
}
