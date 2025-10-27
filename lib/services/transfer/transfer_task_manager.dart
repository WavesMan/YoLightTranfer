import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/models/transfer.dart' as ui;
import 'package:yolighttransfer/models/file_info.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// 管理传输任务队列，支持等待状态和手动触发传输
class TransferTaskManager extends ChangeNotifier {
  final _tasks = <ui.TransferTask>[];
  final _waitingTasks = <ui.TransferTask>[];

  List<ui.TransferTask> get tasks => List.unmodifiable(_tasks);
  List<ui.TransferTask> get waitingTasks => List.unmodifiable(_waitingTasks);

  /// 添加等待传输的任务
  void addWaitingTask(FileInfo file, DiscoveredDevice targetDevice) {
    final task = ui.TransferTask(
      fileName: file.name,
      progress: 0,
      totalSize: file.formattedSize,
      transferredSize: '0 B',
      status: ui.TransferStatus.waiting,
      estimatedTime: '等待传输',
      targetDevice: targetDevice,
      fileInfo: file,
    );
    _waitingTasks.add(task);
    notifyListeners();
  }

  /// 开始传输等待队列中的任务
  void startTransfer(String fileName) {
    final taskIndex = _waitingTasks.indexWhere((t) => t.fileName == fileName);
    if (taskIndex == -1) return;
    
    final task = _waitingTasks[taskIndex];
    _waitingTasks.removeAt(taskIndex);
    
    // 更新任务状态为传输中
    final activeTask = ui.TransferTask(
      fileName: task.fileName,
      progress: 0,
      totalSize: task.totalSize,
      transferredSize: '0 B',
      status: ui.TransferStatus.transferring,
      estimatedTime: '计算中...',
      targetDevice: task.targetDevice,
      fileInfo: task.fileInfo,
    );
    
    _tasks.add(activeTask);
    notifyListeners();
  }

  /// 开始传输所有等待任务
  void startAllTransfers() {
    for (final task in List.from(_waitingTasks)) {
      startTransfer(task.fileName);
    }
  }

  /// 移除等待任务
  void removeWaitingTask(String fileName) {
    _waitingTasks.removeWhere((t) => t.fileName == fileName);
    notifyListeners();
  }

  /// 清空所有等待任务
  void clearWaitingTasks() {
    _waitingTasks.clear();
    notifyListeners();
  }

  void removeTask(ui.TransferTask task) {
    _tasks.remove(task);
    notifyListeners();
  }

  /// 根据文件名更新任务的进度
  void updateProgress({required String fileName, required int progress, String? transferredSize, String? eta}) {
    final idx = _tasks.indexWhere((t) => t.fileName == fileName);
    if (idx == -1) return;
    final t = _tasks[idx];
    
    // 计算剩余时间
    String estimatedTimeRemaining = '计算中...';
    if (eta != null && eta.contains('/s') && progress > 0 && progress < 100) {
      estimatedTimeRemaining = _calculateRemainingTime(t.totalSize, transferredSize ?? t.transferredSize, eta);
    }
    
    _tasks[idx] = ui.TransferTask(
      fileName: t.fileName,
      progress: progress,
      totalSize: t.totalSize,
      transferredSize: transferredSize ?? t.transferredSize,
      status: ui.TransferStatus.transferring,
      estimatedTime: '${ eta ?? t.estimatedTime}\n$estimatedTimeRemaining',
      targetDevice: t.targetDevice,
      fileInfo: t.fileInfo,
    );
    notifyListeners();
  }

  /// 计算剩余时间
  String _calculateRemainingTime(String totalSize, String transferredSize, String speed) {
    try {
      // 解析总大小
      final totalBytes = _parseBytes(totalSize);
      // 解析已传输大小
      final transferredBytes = _parseBytes(transferredSize);
      // 解析网速
      final speedBytesPerSecond = _parseSpeed(speed);
      
      if (totalBytes <= 0 || speedBytesPerSecond <= 0) {
        return '计算中...';
      }
      
      final remainingBytes = totalBytes - transferredBytes;
      if (remainingBytes <= 0) {
        return '即将完成';
      }
      
      final remainingSeconds = remainingBytes / speedBytesPerSecond;
      return '剩余: ${_formatDuration(remainingSeconds.toInt())}';
    } catch (e) {
      return '计算中...';
    }
  }

  /// 解析字节大小字符串
  int _parseBytes(String sizeStr) {
    try {
      final parts = sizeStr.trim().split(' ');
      if (parts.length < 2) return 0;
      
      final value = double.parse(parts[0]);
      final unit = parts[1].toUpperCase();
      
      switch (unit) {
        case 'B':
          return value.toInt();
        case 'KB':
          return (value * 1024).toInt();
        case 'MB':
          return (value * 1024 * 1024).toInt();
        case 'GB':
          return (value * 1024 * 1024 * 1024).toInt();
        default:
          return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// 解析网速字符串
  int _parseSpeed(String speedStr) {
    try {
      final parts = speedStr.trim().split(' ');
      if (parts.length < 2) return 0;
      
      final value = double.parse(parts[0]);
      final unit = parts[1].toUpperCase();
      
      switch (unit) {
        case 'B/S':
          return value.toInt();
        case 'KB/S':
          return (value * 1024).toInt();
        case 'MB/S':
          return (value * 1024 * 1024).toInt();
        case 'GB/S':
          return (value * 1024 * 1024 * 1024).toInt();
        default:
          return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// 格式化时间
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}秒';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}分${secs}秒';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}小时${minutes}分';
    }
  }

  void markCompleted(String fileName) {
    final idx = _tasks.indexWhere((t) => t.fileName == fileName);
    if (idx == -1) return;
    final t = _tasks[idx];
    _tasks[idx] = ui.TransferTask(
      fileName: t.fileName,
      progress: 100,
      totalSize: t.totalSize,
      transferredSize: t.totalSize,
      status: ui.TransferStatus.completed,
      estimatedTime: '0s',
      targetDevice: t.targetDevice,
      fileInfo: t.fileInfo,
    );
    notifyListeners();
  }

  void markFailed(String fileName, String error) {
    final idx = _tasks.indexWhere((t) => t.fileName == fileName);
    if (idx == -1) return;
    final t = _tasks[idx];
    _tasks[idx] = ui.TransferTask(
      fileName: t.fileName,
      progress: 0,
      totalSize: t.totalSize,
      transferredSize: '0 B',
      status: ui.TransferStatus.failed,
      estimatedTime: '失败: $error',
      targetDevice: t.targetDevice,
      fileInfo: t.fileInfo,
    );
    notifyListeners();
  }

  /// 添加接收任务（接收端）
  void addReceivingTask(String fileName, int fileSize, DiscoveredDevice? sourceDevice) {
    final task = ui.TransferTask(
      fileName: fileName,
      progress: 0,
      totalSize: _formatBytes(fileSize),
      transferredSize: '0 B',
      status: ui.TransferStatus.transferring,
      estimatedTime: '接收中...',
      targetDevice: sourceDevice,
      fileInfo: null,
    );
    _tasks.add(task);
    notifyListeners();
  }

  /// 标记接收完成
  void markReceiveCompleted(String fileName) {
    final idx = _tasks.indexWhere((t) => t.fileName == fileName);
    if (idx == -1) return;
    final t = _tasks[idx];
    _tasks[idx] = ui.TransferTask(
      fileName: t.fileName,
      progress: 100,
      totalSize: t.totalSize,
      transferredSize: t.totalSize,
      status: ui.TransferStatus.completed,
      estimatedTime: '0s',
      targetDevice: t.targetDevice,
      fileInfo: t.fileInfo,
    );
    notifyListeners();
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
