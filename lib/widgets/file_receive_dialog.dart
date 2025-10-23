import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';


class FileReceiveDialog extends StatelessWidget {
  final String senderDeviceName;
  final String fileName;
  final int fileSize;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDismiss;

  const FileReceiveDialog({
    super.key,
    required this.senderDeviceName,
    required this.fileName,
    required this.fileSize,
    required this.onAccept,
    required this.onReject,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      elevation: 12, // 增强阴影效果
      shadowColor: theme.colorScheme.shadow.withOpacity(0.4), // 使用主题阴影颜色
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.dialogBorderRadius,
      ),
      title: Text(
        '文件传输请求',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来自设备: $senderDeviceName'),
          const SizedBox(height: AppSpacing.s),
          Text('文件名: $fileName'),
          const SizedBox(height: AppSpacing.s),
          Text('文件大小: ${_formatBytes(fileSize)}'),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.buttonBorderRadius,
            ),
          ),
          child: const Text('拒绝'),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.buttonBorderRadius,
            ),
          ),
          child: const Text('接受'),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
