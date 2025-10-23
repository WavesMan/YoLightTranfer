import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:yolighttransfer/models/file_info.dart';
import 'file_picker_service.dart';

/// Windows平台文件选择服务实现
class WindowsFilePickerService implements FilePickerService {
  @override
  Future<List<FileInfo>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final typeGroup = XTypeGroup(
        label: '文件',
        extensions: allowedExtensions,
      );

      final files = await openFiles(acceptedTypeGroups: [typeGroup]);

      return await Future.wait(files.map((file) async {
        try {
          // 使用 File 对象获取实际文件大小
          final fileObj = File(file.path);
          final fileSize = await fileObj.length();
          final modifiedTime = await fileObj.lastModified();
          
          return FileInfo(
            name: file.name,
            path: file.path,
            size: fileSize,
            modifiedTime: modifiedTime,
            mimeType: file.mimeType,
          );
        } catch (e) {
          // 如果获取文件大小失败，使用默认值但记录警告
          print('警告: 无法获取文件大小 ${file.path}: $e');
          return FileInfo(
            name: file.name,
            path: file.path,
            size: 0, // 使用0作为默认值
            mimeType: file.mimeType,
          );
        }
      }));
    } catch (e) {
      throw FilePickerException('文件选择失败', e);
    }
  }

  @override
  Future<FileInfo?> pickSingleFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final typeGroup = XTypeGroup(
        label: '文件',
        extensions: allowedExtensions,
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        return null;
      }

      try {
        // 使用 File 对象获取实际文件大小
        final fileObj = File(file.path);
        final fileSize = await fileObj.length();
        final modifiedTime = await fileObj.lastModified();
        
        return FileInfo(
          name: file.name,
          path: file.path,
          size: fileSize,
          modifiedTime: modifiedTime,
          mimeType: file.mimeType,
        );
      } catch (e) {
        // 如果获取文件大小失败，使用默认值但记录警告
        print('警告: 无法获取文件大小 ${file.path}: $e');
        return FileInfo(
          name: file.name,
          path: file.path,
          size: 0, // 使用0作为默认值
          mimeType: file.mimeType,
        );
      }
    } catch (e) {
      throw FilePickerException('文件选择失败', e);
    }
  }

  @override
  Future<bool> hasPermission() async {
    // Windows平台不需要文件访问权限
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    // Windows平台不需要文件访问权限
    return true;
  }

  @override
  bool get requiresPermission => false;

  @override
  Future<String?> pickSaveLocation({
    String? defaultFileName,
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      final typeGroup = XTypeGroup(
        label: 'JSON文件',
        extensions: allowedExtensions ?? ['json'],
      );

      final file = await getSaveLocation(
        acceptedTypeGroups: [typeGroup],
        suggestedName: defaultFileName,
      );

      if (file == null) {
        return null;
      }

      return file.path;
    } catch (e) {
      throw FilePickerException('保存位置选择失败', e);
    }
  }
}
