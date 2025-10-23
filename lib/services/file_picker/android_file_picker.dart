import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yolighttransfer/models/file_info.dart';
import 'file_picker_service.dart';

/// Android平台文件选择服务实现
class AndroidFilePickerService implements FilePickerService {
  @override
  Future<List<FileInfo>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    // 检查权限
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw FilePickerException('文件访问权限被拒绝');
      }
    }

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
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  bool get requiresPermission => Platform.isAndroid;

  @override
  Future<String?> pickSaveLocation({
    String? defaultFileName,
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    // Android平台的文件选择器库不支持保存位置选择
    // 这里提供一个简单的实现，使用默认的下载目录
    try {
      // 检查权限
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          throw FilePickerException('文件访问权限被拒绝');
        }
      }

      // 使用默认的下载目录
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        // 如果下载目录不存在，使用应用文档目录
        final appDocDir = await getApplicationDocumentsDirectory();
        return '${appDocDir.path}/${defaultFileName ?? 'transfer_logs.json'}';
      }

      return '${directory.path}/${defaultFileName ?? 'transfer_logs.json'}';
    } catch (e) {
      throw FilePickerException('保存位置选择失败', e);
    }
  }
}
