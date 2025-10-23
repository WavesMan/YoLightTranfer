import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yolighttransfer/models/file_info.dart';
import 'file_picker_service.dart';

/// iOS/macOS平台文件选择服务实现
class IOSFilePickerService implements FilePickerService {
  @override
  Future<List<FileInfo>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      return result.files
          .where((file) => file.path != null)
          .map((file) => FileInfo.fromPlatformFile(file))
          .toList();
    } catch (e) {
      throw FilePickerException('文件选择失败', e);
    }
  }

  @override
  Future<FileInfo?> pickSingleFile({
    List<String>? allowedExtensions,
  }) async {
    final files = await pickFiles(
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );
    return files.isNotEmpty ? files.first : null;
  }

  @override
  Future<bool> hasPermission() async {
    if (Platform.isIOS) {
      // iOS需要照片库权限
      final status = await Permission.photos.status;
      return status.isGranted;
    } else if (Platform.isMacOS) {
      // macOS需要文件访问权限
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else if (Platform.isMacOS) {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  bool get requiresPermission => Platform.isIOS || Platform.isMacOS;

  @override
  Future<String?> pickSaveLocation({
    String? defaultFileName,
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    // iOS/macOS平台的文件选择器库不支持保存位置选择
    // 这里提供一个简单的实现，使用默认的文档目录
    try {
      // 检查权限
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          throw FilePickerException('文件访问权限被拒绝');
        }
      }

      // 使用应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      return '${appDocDir.path}/${defaultFileName ?? 'transfer_logs.json'}';
    } catch (e) {
      throw FilePickerException('保存位置选择失败', e);
    }
  }
}
