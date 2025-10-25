import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 跨平台下载目录服务
/// 获取各平台的标准下载目录，并在其中创建 YoLightTransfer 子目录
class DownloadPathService {
  static const String APP_DIR_NAME = 'YoLightTransfer';

  /// 获取下载目录路径
  /// 
  /// 返回值：
  /// - Windows: C:\Users\<username>\Downloads\YoLightTransfer
  /// - Android: /sdcard/Download/YoLightTransfer 或 /storage/emulated/0/Download/YoLightTransfer
  /// - Linux: ~/Downloads/YoLightTransfer 或 ~/下载/YoLightTransfer
  static Future<String> getDownloadDir() async {
    try {
      if (Platform.isWindows) {
        return _getWindowsDownloadDir();
      } else if (Platform.isAndroid) {
        return _getAndroidDownloadDir();
      } else if (Platform.isLinux) {
        return _getLinuxDownloadDir();
      } else {
        // 其他平台使用应用文档目录
        final dir = await getApplicationDocumentsDirectory();
        return '${dir.path}/$APP_DIR_NAME';
      }
    } catch (e) {
      print('❌ 获取下载目录失败: $e，使用应用文档目录');
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$APP_DIR_NAME';
    }
  }

  /// Windows 下载目录
  static String _getWindowsDownloadDir() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.isEmpty) {
      throw Exception('无法获取 USERPROFILE 环境变量');
    }
    return '$userProfile\\Downloads\\$APP_DIR_NAME';
  }

  /// Android 下载目录
  static Future<String> _getAndroidDownloadDir() async {
    try {
      // Android 标准下载目录路径
      // /storage/emulated/0/Download 是主用户的下载目录
      final downloadPath = '/storage/emulated/0/Download/$APP_DIR_NAME';
      print('📁 Android 下载目录: $downloadPath');
      return downloadPath;
    } catch (e) {
      print('⚠️ 获取 Android 下载目录失败: $e');
    }

    // 备选方案：使用应用文档目录
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fallbackPath = '${dir.path}/$APP_DIR_NAME';
      print('📁 使用备选目录: $fallbackPath');
      return fallbackPath;
    } catch (e) {
      print('❌ 获取备选目录失败: $e');
      return '/data/data/com.waveyo.yolighttransfer_flutter/files/$APP_DIR_NAME';
    }
  }

  /// Linux 下载目录
  static String _getLinuxDownloadDir() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw Exception('无法获取 HOME 环境变量');
    }

    // 优先使用 Downloads（英文），如果不存在则使用 下载（中文）
    final downloadDir = Directory('$home/Downloads');
    if (downloadDir.existsSync()) {
      return '$home/Downloads/$APP_DIR_NAME';
    }

    // 尝试中文下载目录
    final chineseDownloadDir = Directory('$home/下载');
    if (chineseDownloadDir.existsSync()) {
      return '$home/下载/$APP_DIR_NAME';
    }

    // 默认使用 Downloads
    return '$home/Downloads/$APP_DIR_NAME';
  }

  /// 确保下载目录存在
  static Future<void> ensureDownloadDirExists() async {
    final downloadDir = await getDownloadDir();
    final dir = Directory(downloadDir);
    
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
        print('✅ 下载目录已创建: $downloadDir');
      } catch (e) {
        print('❌ 创建下载目录失败: $e');
        rethrow;
      }
    }
  }

  /// 获取完整的文件保存路径
  static Future<String> getFileSavePath(String fileName) async {
    final downloadDir = await getDownloadDir();
    return '$downloadDir/$fileName';
  }
}
