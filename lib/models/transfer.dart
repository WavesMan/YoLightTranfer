import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/models/file_info.dart';

enum TransferStatus {
  transferring,
  completed,
  failed,
  waiting,
  cancelled,
}

extension TransferStatusExtension on TransferStatus {
  String get text {
    switch (this) {
      case TransferStatus.transferring:
        return '传输中';
      case TransferStatus.completed:
        return '已完成';
      case TransferStatus.failed:
        return '已失败';
      case TransferStatus.waiting:
        return '等待中';
      case TransferStatus.cancelled:
        return '已取消';
    }
  }
}

class TransferTask {
  final String fileName;
  final int progress;
  final String totalSize;
  final String transferredSize;
  final TransferStatus status;
  final String estimatedTime;
  final DiscoveredDevice? targetDevice;
  final FileInfo? fileInfo;

  TransferTask({
    required this.fileName,
    required this.progress,
    required this.totalSize,
    required this.transferredSize,
    required this.status,
    required this.estimatedTime,
    this.targetDevice,
    this.fileInfo,
  });
}
