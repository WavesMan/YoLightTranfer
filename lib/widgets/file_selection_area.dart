import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/models/file_info.dart';
import 'package:yolighttransfer/models/transfer.dart' as ui;
import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/file_picker/file_picker_factory.dart';
import 'package:yolighttransfer/services/file_picker/file_picker_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/services/tcp/enhanced_tcp_transfer_client.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/models/transfer_log.dart';

class FileSelectionArea extends StatefulWidget {
  const FileSelectionArea({super.key});

  @override
  State<FileSelectionArea> createState() => _FileSelectionAreaState();
}

class _FileSelectionAreaState extends State<FileSelectionArea> {
  final List<FileInfo> _selectedFiles = [];
  bool _isSelecting = false;
  late FilePickerService _filePickerService;

  @override
  void initState() {
    super.initState();
    _filePickerService = FilePickerFactory.create();
  }

  /// 选择多个文件
  Future<void> _selectMultipleFiles() async {
    if (_isSelecting) return;

    // 检查是否已选择目标设备
    final deviceManager = context.read<DeviceManager>();
    final selectedDevice = deviceManager.selectedDevice;
    
    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先选择一个目标设备'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSelecting = true;
    });

    try {
      final files = await _filePickerService.pickFiles(
        allowMultiple: true,
      );

      if (files.isNotEmpty) {
        // 验证文件大小
        final validFiles = <FileInfo>[];
        final invalidFiles = <FileInfo>[];
        
        for (final file in files) {
          if (file.size > 0) {
            validFiles.add(file);
          } else {
            invalidFiles.add(file);
          }
        }

        if (invalidFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${invalidFiles.length} 个文件大小获取失败，可能无法正常传输'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
          });

          // 将文件添加到等待传输队列
          final taskManager = context.read<TransferTaskManager>();
          for (final file in validFiles) {
            taskManager.addWaitingTask(file, selectedDevice);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已选择 ${validFiles.length} 个文件，已添加到传输队列'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件选择失败: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSelecting = false;
      });
    }
  }

  /// 移除文件
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  /// 清空所有文件
  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  /// 开始所有等待传输
  Future<void> _startAllTransfers() async {
    final taskManager = context.read<TransferTaskManager>();
    final deviceManager = context.read<DeviceManager>();
    final selectedDevice = deviceManager.selectedDevice;

    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先选择一个目标设备'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 获取等待任务列表的副本
    final waitingTasks = List<ui.TransferTask>.from(taskManager.waitingTasks);

    // 开始所有等待传输
    taskManager.startAllTransfers();

    // 开始实际的文件传输
    for (final task in waitingTasks) {
      if (task.fileInfo != null && task.targetDevice != null) {
        await _startFileTransfer([task.fileInfo!], task.targetDevice!);
      }
    }

    // 清空本地选择的文件列表
    setState(() {
      _selectedFiles.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始传输 ${waitingTasks.length} 个文件到 ${selectedDevice.name}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceManager = context.watch<DeviceManager>();
    final selectedDevice = deviceManager.selectedDevice;
    final taskManager = context.watch<TransferTaskManager>();
    final hasWaitingTasks = taskManager.waitingTasks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择文件按钮 - 与KT UI对齐
        ElevatedButton(
          onPressed: _isSelecting ? null : _selectMultipleFiles,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.buttonBorderRadius,
            ),
            padding: AppSpacing.buttonPadding,
          ),
          child: _isSelecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('选择文件'),
        ),
        const SizedBox(height: AppSpacing.s),
        
        // 提示文字 - 与KT UI对齐
        Text(
          '或拖拽文件到此区域',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        
        // 上传到设备按钮
        if (selectedDevice != null && hasWaitingTasks)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: ElevatedButton(
              onPressed: () => _startAllTransfers(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.buttonBorderRadius,
                ),
                padding: AppSpacing.buttonPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upload, size: 16),
                  const SizedBox(width: AppSpacing.s),
                  Text('上传到 ${selectedDevice.name}'),
                ],
              ),
            ),
          ),
        
        // 已选择文件信息和操作
        Row(
          children: [
            Text(
              '已选择: ${_selectedFiles.length}个文件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (_selectedFiles.isNotEmpty)
              TextButton(
                onPressed: _clearAllFiles,
                child: Text(
                  '清空',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        
        // 已选择文件列表
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          ..._selectedFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s),
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppBorderRadius.s),
              ),
              child: Row(
                children: [
                  // 文件图标
                  Icon(
                    _getFileIcon(file.extension),
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  
                  // 文件信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          file.formattedSize,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeFile(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  /// 开始文件传输到目标设备
  Future<void> _startFileTransfer(List<FileInfo> files, DiscoveredDevice targetDevice) async {
    final taskManager = context.read<TransferTaskManager>();
    final logManager = context.read<TransferLogManager>();
    
    for (final file in files) {
      try {
        // 更新任务状态为传输中
        taskManager.updateProgress(
          fileName: file.name,
          progress: 10,
          transferredSize: '准备中...',
          eta: '计算中...',
        );

        // 使用设备对象中的IP和端口
        final host = targetDevice.ip;
        final port = targetDevice.tcpPort;

        print('=== 文件传输调试信息 ===');
        print('目标设备: ${targetDevice.name}');
        print('设备ID: ${targetDevice.id}');
        print('设备IP: $host');
        print('设备TCP端口: $port');
        print('设备系统: ${targetDevice.os}');
        print('文件名: ${file.name}');
        print('文件大小: ${file.size} bytes');
        print('开始连接到设备: $host:$port');
        print('====================');

        // 创建增强的TCP客户端并连接
        final client = EnhancedTcpTransferClient();
        client.setLogManager(logManager);
        
        print('正在创建TCP客户端连接...');
        print('连接参数 - 主机: $host, 端口: $port');
        
        try {
          await client.connect(host: host, port: port);
          print('✓ TCP连接成功，发送文件传输请求...');
        } catch (e) {
          print('✗ TCP连接失败: $e');
          print('连接详情: 尝试连接到 $host:$port');
          
          // 记录连接失败日志
          client.logTransferError(
            fileName: file.name,
            error: 'TCP连接失败: $e',
            targetDevice: targetDevice,
          );
          rethrow;
        }

        // 发送文件传输请求并等待确认
        final accepted = await client.sendFileTransferRequest(
          senderDeviceName: '本地设备', // 这里应该使用实际的设备名称
          fileName: file.name,
          fileSize: file.size,
          filePath: file.path,
          targetDevice: targetDevice,
        );

        if (!accepted) {
          throw Exception('对方拒绝了文件传输请求');
        }

        print('文件传输请求已接受，开始传输...');

        // 创建文件对象并开始实际文件传输
        final fileObj = File(file.path);
        await client.sendFile(
          file: fileObj,
          remotePath: file.name,
          targetDevice: targetDevice,
          onProgress: (sentBytes, totalBytes) {
            final progress = (sentBytes / totalBytes * 100).round();
            taskManager.updateProgress(
              fileName: file.name,
              progress: progress,
              transferredSize: '$sentBytes B',
              eta: '计算中...',
            );
          },
        );

        // 传输完成
        taskManager.markCompleted(file.name);
        
        // 记录传输完成日志
        logManager.addCompleteLog(
          logId: '${DateTime.now().millisecondsSinceEpoch}_send_${file.name.hashCode}',
          type: TransferLogType.send,
          fileName: file.name,
          fileSize: file.size,
          filePath: file.path,
          targetDevice: targetDevice,
        );
        
        // 关闭客户端连接
        await client.close();

        print('文件传输完成: ${file.name}');

      } catch (e) {
        // 传输失败
        final errorMsg = '文件传输失败: ${file.name} - ${e.toString()}';
        print(errorMsg);
        
        // 记录错误日志
        final logManager = context.read<TransferLogManager>();
        logManager.addErrorLog(
          type: TransferLogType.send,
          fileName: file.name,
          error: errorMsg,
          targetDevice: targetDevice,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 更新任务状态为失败
        taskManager.markFailed(file.name, e.toString());
      }
    }
  }

  /// 根据文件扩展名获取对应的图标
  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
