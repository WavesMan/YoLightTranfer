import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 跨平台文件路径服务
/// 确保文件下载到系统的公共Downloads目录下创建文件夹"YoLightTransfer"
class FilePathService {
  static const String _transferFolderName = 'YoLightTransfer';

  /// 获取YoLightTransfer传输文件夹路径
  static Future<String> getTransferDirectory() async {
    Directory downloadsDir;
    
    // 根据平台获取Downloads目录
    if (Platform.isAndroid) {
      // Android: 使用外部存储目录或应用文档目录
      try {
        // 首先尝试获取外部存储目录（需要权限）
        downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        print('Android文件路径 - 外部存储目录: ${downloadsDir.path}');
      } catch (e) {
        // 如果外部存储不可用，使用应用文档目录
        downloadsDir = await getApplicationDocumentsDirectory();
        print('Android文件路径 - 应用文档目录: ${downloadsDir.path}');
      }
    } else if (Platform.isIOS) {
      // iOS: Documents目录
      downloadsDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      // Windows: C:\Users\<username>\Downloads\YoLightTransfer
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\diwei';
      downloadsDir = Directory('$userProfile\\Downloads');
    } else if (Platform.isLinux) {
      // Linux: 尝试多个可能的Downloads目录路径
      final homeDir = Platform.environment['HOME'] ?? '/home/user';
      
      // 尝试英文Downloads目录
      downloadsDir = Directory('$homeDir/Downloads');
      if (await downloadsDir.exists()) {
        return '${downloadsDir.path}/$_transferFolderName';
      }
      
      // 尝试中文下载目录
      downloadsDir = Directory('$homeDir/下载');
      if (await downloadsDir.exists()) {
        return '${downloadsDir.path}/$_transferFolderName';
      }
      
      // 如果都不存在，使用home目录
      downloadsDir = Directory(homeDir);
    } else if (Platform.isMacOS) {
      // macOS: ~/Downloads/YoLightTransfer
      downloadsDir = await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
    } else {
      // 其他平台使用临时目录
      downloadsDir = await getTemporaryDirectory();
    }
    
    // 创建YoLightTransfer子目录
    final transferDir = Directory('${downloadsDir.path}/$_transferFolderName');
    if (!await transferDir.exists()) {
      await transferDir.create(recursive: true);
      print('创建传输目录: ${transferDir.path}');
    } else {
      print('传输目录已存在: ${transferDir.path}');
    }
    
    return transferDir.path;
  }

  /// 获取完整的文件保存路径
  static Future<String> getFileSavePath(String fileName) async {
    final transferDir = await getTransferDirectory();
    return '$transferDir/$fileName';
  }

  /// 检查文件是否已存在
  static Future<bool> fileExists(String fileName) async {
    final filePath = await getFileSavePath(fileName);
    return await File(filePath).exists();
  }

  /// 获取可用的文件名（避免重名）
  static Future<String> getAvailableFileName(String originalName) async {
    final baseName = originalName;
    final extension = '';
    
    // 分离文件名和扩展名
    final dotIndex = baseName.lastIndexOf('.');
    String nameWithoutExt;
    String ext;
    
    if (dotIndex != -1) {
      nameWithoutExt = baseName.substring(0, dotIndex);
      ext = baseName.substring(dotIndex);
    } else {
      nameWithoutExt = baseName;
      ext = '';
    }
    
    // 检查原始文件名是否可用
    if (!await fileExists(baseName)) {
      return baseName;
    }
    
    // 如果存在，添加数字后缀
    int counter = 1;
    while (true) {
      final newName = '$nameWithoutExt ($counter)$ext';
      if (!await fileExists(newName)) {
        return newName;
      }
      counter++;
    }
  }
}
