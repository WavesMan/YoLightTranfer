import 'package:flutter/material.dart';
import 'package:yolighttransfer/models/transfer.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/theme/app_colors.dart';

class TransferTaskItem extends StatelessWidget {
  final TransferTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TransferTaskItem({
    super.key,
    required this.task,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 获取状态文本和颜色
    final (statusText, statusColor) = _getStatusInfo(task.status, theme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件图标
          Icon(
            Icons.insert_drive_file,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.m),
          // 文件信息和进度
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件名
                Text(
                  task.fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                // 进度文本
                Text(
                  '${task.progress}% · ${task.transferredSize}/${task.totalSize}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 进度条
                LinearProgressIndicator(
                  value: task.progress / 100,
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  color: statusColor,
                  borderRadius: BorderRadius.circular(AppBorderRadius.s),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 状态文本和网速信息
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：状态文本
                    Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    // 第二行：网速和剩余时间
                    if (task.estimatedTime != null && task.estimatedTime!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.estimatedTime!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          // 操作按钮
          if (task.status == TransferStatus.transferring || 
              task.status == TransferStatus.waiting)
            IconButton(
              icon: const Icon(Icons.cancel, size: 18),
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (task.status == TransferStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  (String, Color) _getStatusInfo(TransferStatus status, ThemeData theme) {
    switch (status) {
      case TransferStatus.transferring:
        return ('传输中', theme.colorScheme.primary);
      case TransferStatus.completed:
        return ('已完成', AppStatusColors.success);
      case TransferStatus.failed:
        return ('失败', AppStatusColors.error);
      case TransferStatus.waiting:
        return ('等待中', theme.colorScheme.onSurfaceVariant);
      default:
        return ('未知', theme.colorScheme.onSurfaceVariant);
    }
  }
}
