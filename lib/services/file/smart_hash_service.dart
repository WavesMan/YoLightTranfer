import 'dart:io';
import 'package:yolighttransfer/services/file/enhanced_file_hash_service.dart';
import 'package:yolighttransfer/services/file/multi_thread_hash_service.dart';

/// 智能哈希计算服务：根据文件大小自动选择最优计算方式
class SmartHashService {
  static const int _smallFileThreshold = 10 * 1024 * 1024; // 10MB
  static const int _mediumFileThreshold = 100 * 1024 * 1024; // 100MB
  static const int _largeFileThreshold = 500 * 1024 * 1024; // 500MB

  /// 智能计算文件哈希
  static Future<String> calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      final fileSize = await file.length();
      
      // 根据文件大小选择最优计算方式
      if (fileSize < _smallFileThreshold) {
        // 小文件：使用单线程计算
        return await _calculateSingleThread(filePath);
      } else if (fileSize < _mediumFileThreshold) {
        // 中等文件：使用2线程计算
        return await _calculateMultiThread(filePath, maxConcurrent: 2);
      } else if (fileSize < _largeFileThreshold) {
        // 大文件：使用4线程计算
        return await _calculateMultiThread(filePath, maxConcurrent: 4);
      } else {
        // 超大文件：使用更多线程
        return await _calculateMultiThread(filePath, maxConcurrent: 8);
      }
    } catch (e) {
      print('智能哈希计算失败: $e');
      rethrow;
    }
  }

  /// 单线程哈希计算
  static Future<String> _calculateSingleThread(String filePath) async {
    return await EnhancedFileHashService.calculateFileHash(filePath);
  }

  /// 多线程哈希计算
  static Future<String> _calculateMultiThread(
    String filePath, {
    required int maxConcurrent,
  }) async {
    return await MultiThreadHashService.calculateFileHash(
      filePath,
      maxConcurrent: maxConcurrent,
    );
  }

  /// 获取哈希计算策略描述
  static String getHashStrategyDescription(int fileSize) {
    if (fileSize < _smallFileThreshold) {
      return '单线程计算 (文件大小: ${_formatBytes(fileSize)})';
    } else if (fileSize < _mediumFileThreshold) {
      return '2线程并行计算 (文件大小: ${_formatBytes(fileSize)})';
    } else if (fileSize < _largeFileThreshold) {
      return '4线程并行计算 (文件大小: ${_formatBytes(fileSize)})';
    } else {
      return '8线程并行计算 (文件大小: ${_formatBytes(fileSize)})';
    }
  }

  /// 格式化字节大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
