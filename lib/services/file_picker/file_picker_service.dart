import 'package:yolighttransfer/models/file_info.dart';

/// 文件选择服务抽象接口
abstract class FilePickerService {
  /// 选择多个文件
  /// 返回选择的文件列表，如果用户取消选择则返回空列表
  Future<List<FileInfo>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  });

  /// 选择单个文件
  /// 返回选择的文件，如果用户取消选择则返回null
  Future<FileInfo?> pickSingleFile({
    List<String>? allowedExtensions,
  });

  /// 检查文件访问权限
  /// 返回true表示有权限，false表示无权限
  Future<bool> hasPermission();

  /// 请求文件访问权限
  /// 返回true表示权限已授予，false表示权限被拒绝
  Future<bool> requestPermission();

  /// 检查是否需要权限
  /// 某些平台（如Windows）可能不需要权限
  bool get requiresPermission;

  /// 选择保存位置
  /// 返回选择的保存路径，如果用户取消选择则返回null
  Future<String?> pickSaveLocation({
    String? defaultFileName,
    List<String>? allowedExtensions,
    String? dialogTitle,
  });
}

/// 文件选择异常
class FilePickerException implements Exception {
  final String message;
  final dynamic error;

  FilePickerException(this.message, [this.error]);

  @override
  String toString() => 'FilePickerException: $message${error != null ? ' ($error)' : ''}';
}
