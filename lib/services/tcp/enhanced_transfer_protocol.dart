import 'dart:convert';
import 'dart:io';

/// 增强的TCP传输协议控制帧类型
enum ControlFrameType {
  fileTransferRequest,    // 文件传输请求
  fileTransferAccepted,   // 传输接受
  fileTransferRejected,   // 传输拒绝
  fileMeta,              // 文件元数据
  chunk,                 // 数据分片
  fileEnd,               // 文件结束
  hashRequest,           // 哈希请求
  hashResponse,          // 哈希响应
  transferComplete,      // 传输完成确认
  transferFailed,        // 传输失败
  connectionKeepAlive,   // 连接保活
  stateUpdate,           // 状态更新
  verificationResult,    // 校验结果
  retryRequest,          // 重传请求
  cancelTransfer,        // 取消传输
}

/// 控制帧类型扩展方法
extension ControlFrameTypeExtension on ControlFrameType {
  /// 获取控制帧类型字符串
  String get value {
    switch (this) {
      case ControlFrameType.fileTransferRequest:
        return 'FILE_TRANSFER_REQUEST';
      case ControlFrameType.fileTransferAccepted:
        return 'FILE_TRANSFER_ACCEPTED';
      case ControlFrameType.fileTransferRejected:
        return 'FILE_TRANSFER_REJECTED';
      case ControlFrameType.fileMeta:
        return 'FILE_META';
      case ControlFrameType.chunk:
        return 'CHUNK';
      case ControlFrameType.fileEnd:
        return 'FILE_END';
      case ControlFrameType.hashRequest:
        return 'HASH_REQUEST';
      case ControlFrameType.hashResponse:
        return 'HASH_RESPONSE';
      case ControlFrameType.transferComplete:
        return 'TRANSFER_COMPLETE';
      case ControlFrameType.transferFailed:
        return 'TRANSFER_FAILED';
      case ControlFrameType.connectionKeepAlive:
        return 'CONNECTION_KEEP_ALIVE';
      case ControlFrameType.stateUpdate:
        return 'STATE_UPDATE';
      case ControlFrameType.verificationResult:
        return 'VERIFICATION_RESULT';
      case ControlFrameType.retryRequest:
        return 'RETRY_REQUEST';
      case ControlFrameType.cancelTransfer:
        return 'CANCEL_TRANSFER';
    }
  }

  /// 从字符串解析控制帧类型
  static ControlFrameType fromString(String value) {
    switch (value) {
      case 'FILE_TRANSFER_REQUEST':
        return ControlFrameType.fileTransferRequest;
      case 'FILE_TRANSFER_ACCEPTED':
        return ControlFrameType.fileTransferAccepted;
      case 'FILE_TRANSFER_REJECTED':
        return ControlFrameType.fileTransferRejected;
      case 'FILE_META':
        return ControlFrameType.fileMeta;
      case 'CHUNK':
        return ControlFrameType.chunk;
      case 'FILE_END':
        return ControlFrameType.fileEnd;
      case 'HASH_REQUEST':
        return ControlFrameType.hashRequest;
      case 'HASH_RESPONSE':
        return ControlFrameType.hashResponse;
      case 'TRANSFER_COMPLETE':
        return ControlFrameType.transferComplete;
      case 'TRANSFER_FAILED':
        return ControlFrameType.transferFailed;
      case 'CONNECTION_KEEP_ALIVE':
        return ControlFrameType.connectionKeepAlive;
      case 'STATE_UPDATE':
        return ControlFrameType.stateUpdate;
      case 'VERIFICATION_RESULT':
        return ControlFrameType.verificationResult;
      case 'RETRY_REQUEST':
        return ControlFrameType.retryRequest;
      case 'CANCEL_TRANSFER':
        return ControlFrameType.cancelTransfer;
      default:
        throw ArgumentError('未知的控制帧类型: $value');
    }
  }
}

/// 控制帧构建器
class ControlFrameBuilder {
  /// 构建文件传输请求帧
  static Map<String, dynamic> buildFileTransferRequest({
    required String senderDeviceName,
    required String fileName,
    required int fileSize,
    required String fileHash,
  }) {
    return {
      'type': ControlFrameType.fileTransferRequest.value,
      'senderDeviceName': senderDeviceName,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileHash': fileHash,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建文件传输接受帧
  static Map<String, dynamic> buildFileTransferAccepted({
    required String fileName,
    required String savePath,
  }) {
    return {
      'type': ControlFrameType.fileTransferAccepted.value,
      'fileName': fileName,
      'savePath': savePath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建文件传输拒绝帧
  static Map<String, dynamic> buildFileTransferRejected({
    required String fileName,
    String? reason,
  }) {
    return {
      'type': ControlFrameType.fileTransferRejected.value,
      'fileName': fileName,
      'reason': reason ?? '用户拒绝接收',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建文件元数据帧
  static Map<String, dynamic> buildFileMeta({
    required String name,
    required int size,
    required String path,
    required String hash,
  }) {
    return {
      'type': ControlFrameType.fileMeta.value,
      'name': name,
      'size': size,
      'path': path,
      'hash': hash,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建数据分片帧
  static Map<String, dynamic> buildChunk({
    required int sequence,
    required int size,
    required int offset,
    required int totalSize,
  }) {
    return {
      'type': ControlFrameType.chunk.value,
      'sequence': sequence,
      'size': size,
      'offset': offset,
      'totalSize': totalSize,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建文件结束帧
  static Map<String, dynamic> buildFileEnd({
    required String fileName,
    required int totalBytes,
    required String expectedHash,
  }) {
    return {
      'type': ControlFrameType.fileEnd.value,
      'fileName': fileName,
      'totalBytes': totalBytes,
      'expectedHash': expectedHash,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建哈希请求帧
  static Map<String, dynamic> buildHashRequest({
    required String fileName,
  }) {
    return {
      'type': ControlFrameType.hashRequest.value,
      'fileName': fileName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建哈希响应帧
  static Map<String, dynamic> buildHashResponse({
    required String fileName,
    required String fileHash,
    required bool hashMatches,
  }) {
    return {
      'type': ControlFrameType.hashResponse.value,
      'fileName': fileName,
      'fileHash': fileHash,
      'hashMatches': hashMatches,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建传输完成确认帧
  static Map<String, dynamic> buildTransferComplete({
    required String fileName,
    required bool verificationSuccess,
    String? verificationMessage,
  }) {
    return {
      'type': ControlFrameType.transferComplete.value,
      'fileName': fileName,
      'verificationSuccess': verificationSuccess,
      'verificationMessage': verificationMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建传输失败帧
  static Map<String, dynamic> buildTransferFailed({
    required String fileName,
    required String error,
    bool canRetry = false,
  }) {
    return {
      'type': ControlFrameType.transferFailed.value,
      'fileName': fileName,
      'error': error,
      'canRetry': canRetry,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建连接保活帧
  static Map<String, dynamic> buildConnectionKeepAlive() {
    return {
      'type': ControlFrameType.connectionKeepAlive.value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建状态更新帧
  static Map<String, dynamic> buildStateUpdate({
    required String fileName,
    required String state,
    int? progress,
    String? transferSpeed,
    String? estimatedTime,
  }) {
    return {
      'type': ControlFrameType.stateUpdate.value,
      'fileName': fileName,
      'state': state,
      'progress': progress,
      'transferSpeed': transferSpeed,
      'estimatedTime': estimatedTime,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建校验结果帧
  static Map<String, dynamic> buildVerificationResult({
    required String fileName,
    required bool success,
    String? actualHash,
    String? expectedHash,
    String? message,
  }) {
    return {
      'type': ControlFrameType.verificationResult.value,
      'fileName': fileName,
      'success': success,
      'actualHash': actualHash,
      'expectedHash': expectedHash,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建重传请求帧
  static Map<String, dynamic> buildRetryRequest({
    required String fileName,
    required int fromOffset,
    String? reason,
  }) {
    return {
      'type': ControlFrameType.retryRequest.value,
      'fileName': fileName,
      'fromOffset': fromOffset,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建取消传输帧
  static Map<String, dynamic> buildCancelTransfer({
    required String fileName,
    String? reason,
  }) {
    return {
      'type': ControlFrameType.cancelTransfer.value,
      'fileName': fileName,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 构建确认帧
  static Map<String, dynamic> buildAck({
    required String forType,
    String? fileName,
    Map<String, dynamic>? additionalData,
  }) {
    final frame = {
      'type': 'ACK',
      'for': forType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (fileName != null) {
      frame['fileName'] = fileName;
    }

    if (additionalData != null) {
      frame.addAll(Map<String, Object>.from(additionalData));
    }

    return frame;
  }

  /// 构建错误帧
  static Map<String, dynamic> buildError({
    required String message,
    String? fileName,
    String? errorCode,
  }) {
    final frame = {
      'type': 'ERROR',
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (fileName != null) {
      frame['fileName'] = fileName;
    }

    if (errorCode != null) {
      frame['errorCode'] = errorCode;
    }

    return frame;
  }
}

/// 控制帧解析器
class ControlFrameParser {
  /// 解析控制帧类型
  static ControlFrameType parseType(Map<String, dynamic> frame) {
    final typeString = frame['type'] as String?;
    if (typeString == null) {
      throw ArgumentError('控制帧缺少type字段');
    }

    try {
      return ControlFrameTypeExtension.fromString(typeString);
    } catch (e) {
      // 如果是ACK或ERROR类型，返回特殊处理
      if (typeString == 'ACK' || typeString == 'ERROR') {
        throw ArgumentError('特殊控制帧类型: $typeString');
      }
      rethrow;
    }
  }

  /// 验证控制帧格式
  static bool validateFrame(Map<String, dynamic> frame) {
    final typeString = frame['type'] as String?;
    if (typeString == null) return false;

    // 检查必需字段
    switch (typeString) {
      case 'FILE_TRANSFER_REQUEST':
        return frame['senderDeviceName'] != null &&
               frame['fileName'] != null &&
               frame['fileSize'] != null;
      case 'FILE_META':
        return frame['name'] != null && frame['size'] != null;
      case 'CHUNK':
        return frame['sequence'] != null && frame['size'] != null;
      case 'FILE_END':
        return frame['fileName'] != null && frame['totalBytes'] != null;
      case 'HASH_RESPONSE':
        return frame['fileName'] != null && frame['fileHash'] != null;
      case 'VERIFICATION_RESULT':
        return frame['fileName'] != null && frame['success'] != null;
      default:
        return true; // 其他类型没有强制字段要求
    }
  }

  /// 获取控制帧描述
  static String getFrameDescription(Map<String, dynamic> frame) {
    final typeString = frame['type'] as String? ?? 'UNKNOWN';
    final fileName = frame['fileName'] as String? ?? frame['name'] as String?;

    switch (typeString) {
      case 'FILE_TRANSFER_REQUEST':
        return '文件传输请求: ${frame['fileName']} (${frame['fileSize']} bytes)';
      case 'FILE_TRANSFER_ACCEPTED':
        return '文件传输接受: $fileName';
      case 'FILE_TRANSFER_REJECTED':
        return '文件传输拒绝: $fileName - ${frame['reason']}';
      case 'FILE_META':
        return '文件元数据: ${frame['name']} (${frame['size']} bytes)';
      case 'CHUNK':
        return '数据分片 #${frame['sequence']}: ${frame['size']} bytes';
      case 'FILE_END':
        return '文件传输结束: $fileName';
      case 'HASH_REQUEST':
        return '哈希请求: $fileName';
      case 'HASH_RESPONSE':
        return '哈希响应: $fileName - ${frame['hashMatches'] ? '匹配' : '不匹配'}';
      case 'TRANSFER_COMPLETE':
        return '传输完成: $fileName - ${frame['verificationSuccess'] ? '成功' : '失败'}';
      case 'TRANSFER_FAILED':
        return '传输失败: $fileName - ${frame['error']}';
      case 'CONNECTION_KEEP_ALIVE':
        return '连接保活';
      case 'STATE_UPDATE':
        return '状态更新: $fileName - ${frame['state']}';
      case 'VERIFICATION_RESULT':
        return '校验结果: $fileName - ${frame['success'] ? '成功' : '失败'}';
      case 'RETRY_REQUEST':
        return '重传请求: $fileName - 从偏移 ${frame['fromOffset']}';
      case 'CANCEL_TRANSFER':
        return '取消传输: $fileName';
      case 'ACK':
        return '确认: ${frame['for']}';
      case 'ERROR':
        return '错误: ${frame['message']}';
      default:
        return '未知控制帧: $typeString';
    }
  }
}

/// 协议常量
class ProtocolConstants {
  static const int defaultChunkSize = 64 * 1024; // 64KB
  static const int maxChunkSize = 1024 * 1024; // 1MB
  static const int keepAliveInterval = 30000; // 30秒
  static const int connectionTimeout = 60000; // 60秒
  static const int maxRetryCount = 3;
  static const int retryDelay = 2000; // 2秒
}
