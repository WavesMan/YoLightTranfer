import 'dart:convert';

import 'package:yolighttransfer/util/transfer_protocol.dart';

/// HTTP 协议处理器
/// 负责请求/响应的序列化和反序列化
class HttpProtocolHandler {
  /// 构建上传请求头
  static Map<String, String> buildUploadHeaders({
    required String fileName,
    required int fileSize,
    required int chunkIndex,
    required int totalChunks,
    required String fileHash,
  }) {
    return {
      HttpTransferProtocol.HEADER_FILE_NAME: fileName,
      HttpTransferProtocol.HEADER_FILE_SIZE: fileSize.toString(),
      HttpTransferProtocol.HEADER_CHUNK_INDEX: chunkIndex.toString(),
      HttpTransferProtocol.HEADER_TOTAL_CHUNKS: totalChunks.toString(),
      HttpTransferProtocol.HEADER_FILE_HASH: fileHash,
      'Content-Type': 'application/octet-stream',
    };
  }

  /// 解析上传响应
  static Map<String, dynamic> parseUploadResponse(String responseBody) {
    try {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse upload response: $e');
    }
  }

  /// 解析状态查询响应
  static Map<String, dynamic> parseStatusResponse(String responseBody) {
    try {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse status response: $e');
    }
  }

  /// 构建错误响应
  static Map<String, dynamic> buildErrorResponse({
    required String message,
    required int statusCode,
  }) {
    return {
      'status': 'error',
      'message': message,
      'statusCode': statusCode,
    };
  }

  /// 验证上传响应
  static bool isValidUploadResponse(Map<String, dynamic> response) {
    return response['status'] == 'success' &&
        response.containsKey('fileName') &&
        response.containsKey('chunkIndex') &&
        response.containsKey('totalChunks');
  }

  /// 验证状态响应
  static bool isValidStatusResponse(Map<String, dynamic> response) {
    return response.containsKey('fileName') &&
        response.containsKey('uploadedBytes') &&
        response.containsKey('totalBytes') &&
        response.containsKey('uploadedChunks') &&
        response.containsKey('totalChunks');
  }

  /// 获取上传进度百分比
  static double getUploadProgress(Map<String, dynamic> response) {
    try {
      final uploadedBytes = response['uploadedBytes'] as int;
      final totalBytes = response['totalBytes'] as int;
      return (uploadedBytes / totalBytes * 100).clamp(0.0, 100.0);
    } catch (_) {
      return 0.0;
    }
  }

  /// 格式化错误消息
  static String formatErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}
