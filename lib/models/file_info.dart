import 'dart:io';

/// 文件信息模型
class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime? modifiedTime;
  final String? mimeType;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    this.modifiedTime,
    this.mimeType,
  });

  /// 从File对象创建FileInfo
  factory FileInfo.fromFile(File file) {
    return FileInfo(
      name: file.path.split(Platform.pathSeparator).last,
      path: file.path,
      size: file.lengthSync(),
      modifiedTime: file.lastModifiedSync(),
    );
  }

  /// 从PlatformFile对象创建FileInfo
  factory FileInfo.fromPlatformFile(dynamic platformFile) {
    // 兼容不同版本的 file_picker
    // 安全地访问属性，避免 NoSuchMethodError
    String name = '';
    String path = '';
    int size = 0;
    DateTime? modifiedTime;
    String? mimeType;

    try {
      // 安全访问 name 属性
      if (platformFile.name != null) {
        name = platformFile.name;
      }
    } catch (e) {
      // 如果 name 属性不存在，使用默认值
      name = 'unknown';
    }

    try {
      // 安全访问 path 属性
      if (platformFile.path != null) {
        path = platformFile.path;
      }
    } catch (e) {
      // 如果 path 属性不存在，使用默认值
      path = '';
    }

    try {
      // 安全访问 size 属性
      if (platformFile.size != null) {
        size = platformFile.size;
      }
    } catch (e) {
      // 如果 size 属性不存在，使用默认值
      size = 0;
    }

    try {
      // 安全访问 modifiedTime 属性
      if (platformFile.modifiedTime != null) {
        modifiedTime = platformFile.modifiedTime;
      }
    } catch (e) {
      // 如果 modifiedTime 属性不存在，设置为 null
      modifiedTime = null;
    }

    try {
      // 安全访问 mimeType 属性
      if (platformFile.mimeType != null) {
        mimeType = platformFile.mimeType;
      }
    } catch (e) {
      // 如果 mimeType 属性不存在，设置为 null
      mimeType = null;
    }

    return FileInfo(
      name: name,
      path: path,
      size: size,
      modifiedTime: modifiedTime,
      mimeType: mimeType,
    );
  }

  /// 获取文件扩展名
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// 获取文件大小的人类可读格式
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  String toString() {
    return 'FileInfo(name: $name, path: $path, size: $size, extension: $extension)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileInfo &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
