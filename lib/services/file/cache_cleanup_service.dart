import 'dart:io';

/// Cache 清理服务
/// 用于清理应用的临时文件和过期的 cache 文件
class CacheCleanupService {
  /// 删除指定的文件
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        print('✅ 已删除临时文件: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('⚠️ 删除文件失败: $filePath, 错误: $e');
      return false;
    }
  }

  /// 删除指定目录中的所有文件
  static Future<int> cleanDirectory(String dirPath) async {
    int deletedCount = 0;
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        print('⚠️ 目录不存在: $dirPath');
        return 0;
      }

      final files = dir.listSync(recursive: true);
      for (final entity in files) {
        if (entity is File) {
          try {
            await entity.delete();
            deletedCount++;
            print('✅ 已删除: ${entity.path}');
          } catch (e) {
            print('⚠️ 删除失败: ${entity.path}, 错误: $e');
          }
        }
      }

      // 尝试删除空目录
      try {
        await dir.delete(recursive: true);
        print('✅ 已删除目录: $dirPath');
      } catch (e) {
        print('⚠️ 删除目录失败: $dirPath, 错误: $e');
      }

      return deletedCount;
    } catch (e) {
      print('❌ 清理目录失败: $dirPath, 错误: $e');
      return deletedCount;
    }
  }

  /// 清理 file_picker 的 cache 目录
  /// Android: /data/data/com.waveyo.yolighttransfer_flutter/cache/file_picker/
  static Future<int> cleanFilePickerCache() async {
    try {
      if (Platform.isAndroid) {
        final cacheDir = Directory('/data/data/com.waveyo.yolighttransfer_flutter/cache/file_picker');
        if (cacheDir.existsSync()) {
          print('🧹 开始清理 file_picker cache...');
          final deletedCount = await cleanDirectory(cacheDir.path);
          print('✅ file_picker cache 清理完成，删除了 $deletedCount 个文件');
          return deletedCount;
        }
      }
      return 0;
    } catch (e) {
      print('❌ 清理 file_picker cache 失败: $e');
      return 0;
    }
  }

  /// 清理过期的 cache 文件（超过指定时间）
  static Future<int> cleanExpiredCache(
    String dirPath, {
    Duration expiredDuration = const Duration(days: 7),
  }) async {
    int deletedCount = 0;
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        return 0;
      }

      final now = DateTime.now();
      final files = dir.listSync(recursive: true);

      for (final entity in files) {
        if (entity is File) {
          try {
            final stat = entity.statSync();
            final modifiedTime = stat.modified;
            final age = now.difference(modifiedTime);

            if (age > expiredDuration) {
              await entity.delete();
              deletedCount++;
              print('✅ 已删除过期文件: ${entity.path}');
            }
          } catch (e) {
            print('⚠️ 处理文件失败: ${entity.path}, 错误: $e');
          }
        }
      }

      print('✅ 过期 cache 清理完成，删除了 $deletedCount 个文件');
      return deletedCount;
    } catch (e) {
      print('❌ 清理过期 cache 失败: $e');
      return deletedCount;
    }
  }

  /// 获取目录大小（字节）
  static Future<int> getDirectorySize(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        return 0;
      }

      int totalSize = 0;
      final files = dir.listSync(recursive: true);

      for (final entity in files) {
        if (entity is File) {
          try {
            final stat = entity.statSync();
            totalSize += stat.size;
          } catch (e) {
            print('⚠️ 获取文件大小失败: ${entity.path}');
          }
        }
      }

      return totalSize;
    } catch (e) {
      print('❌ 获取目录大小失败: $e');
      return 0;
    }
  }

  /// 格式化字节大小
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
