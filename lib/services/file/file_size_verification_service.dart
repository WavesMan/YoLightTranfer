import 'dart:io';

/// 文件大小校验服务：提供快速的文件一致性验证
class FileSizeVerificationService {
  
  /// 验证文件大小是否匹配
  static Future<bool> verifyFileSize(String filePath, int expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ 文件不存在: $filePath');
        return false;
      }
      
      final actualSize = await file.length();
      final match = actualSize == expectedSize;
      
      if (match) {
        print('✅ 文件大小校验通过: $filePath (${_formatBytes(actualSize)})');
      } else {
        print('❌ 文件大小不匹配: $filePath (期望: ${_formatBytes(expectedSize)}, 实际: ${_formatBytes(actualSize)})');
      }
      
      return match;
    } catch (e) {
      print('❌ 文件大小校验失败: $e');
      return false;
    }
  }

  /// 获取文件大小
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      return await file.length();
    } catch (e) {
      print('❌ 获取文件大小失败: $e');
      rethrow;
    }
  }

  /// 格式化字节大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取文件大小校验描述
  static String getVerificationDescription(int fileSize) {
    return '文件大小校验 (${_formatBytes(fileSize)})';
  }

  /// 比较两个文件大小是否相同
  static bool compareFileSizes(int size1, int size2) {
    return size1 == size2;
  }

  /// 检查文件大小是否在合理范围内
  static bool isFileSizeReasonable(int fileSize, {int maxSize = 10 * 1024 * 1024 * 1024}) {
    return fileSize > 0 && fileSize <= maxSize;
  }
}
