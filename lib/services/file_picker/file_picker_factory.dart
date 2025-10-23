import 'dart:io';
import 'file_picker_service.dart';
import 'android_file_picker.dart';
import 'windows_file_picker.dart';
import 'ios_file_picker.dart';

/// 文件选择服务工厂
class FilePickerFactory {
  /// 根据当前平台创建对应的文件选择服务
  static FilePickerService create() {
    if (Platform.isAndroid) {
      return AndroidFilePickerService();
    } else if (Platform.isWindows) {
      return WindowsFilePickerService();
    } else if (Platform.isIOS || Platform.isMacOS) {
      return IOSFilePickerService();
    } else {
      // 默认使用Android实现作为备用
      return AndroidFilePickerService();
    }
  }

  /// 获取当前平台名称
  static String get platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
