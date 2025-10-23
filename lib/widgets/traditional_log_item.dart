import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';

/// 传统日志格式组件 - 显示 time | models | logs 格式
class TraditionalLogItem extends StatelessWidget {
  final TransferLog log;
  final bool showFullTimestamp;
  final VoidCallback? onTap;

  const TraditionalLogItem({
    super.key,
    required this.log,
    this.showFullTimestamp = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _copyLogToClipboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间列
            _buildTimeColumn(theme),
            
            const SizedBox(width: AppSpacing.m),
            
            // 类型/模型列
            _buildModelColumn(theme),
            
            const SizedBox(width: AppSpacing.m),
            
            // 日志内容列
            Expanded(
              child: _buildLogContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建时间列
  Widget _buildTimeColumn(ThemeData theme) {
    final timeText = showFullTimestamp 
        ? _formatFullTimestamp(log.timestamp)
        : log.timeText;

    return SizedBox(
      width: showFullTimestamp ? 160 : 80,
      child: Text(
        timeText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'Monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建类型/模型列
  Widget _buildModelColumn(ThemeData theme) {
    final typeColor = _getTypeColor(theme);
    final typeText = _getTypeText();

    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      child: Text(
        typeText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: typeColor,
          fontWeight: FontWeight.w600,
          fontFamily: 'Monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建日志内容列
  Widget _buildLogContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主要消息
        Text(
          log.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'Monospace',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 额外信息（文件名、设备等）
        if (log.fileName.isNotEmpty && log.fileName != log.message)
          _buildAdditionalInfo(theme),
        
        // 错误信息
        if (log.error != null)
          _buildErrorInfo(theme),
        
        // 进度信息
        if (log.progress != null)
          _buildProgressInfo(theme),
      ],
    );
  }

  /// 构建额外信息
  Widget _buildAdditionalInfo(ThemeData theme) {
    final additionalInfo = <String>[];
    
    if (log.fileName.isNotEmpty) {
      additionalInfo.add('文件: ${log.fileName}');
    }
    
    if (log.deviceName != '未知设备') {
      additionalInfo.add('设备: ${log.deviceName}');
    }
    
    if (log.fileSize > 0) {
      additionalInfo.add('大小: ${log.fileSizeText}');
    }
    
    if (additionalInfo.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        additionalInfo.join(' | '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'Monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建错误信息
  Widget _buildErrorInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '错误: ${log.error!}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontFamily: 'Monospace',
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建进度信息
  Widget _buildProgressInfo(ThemeData theme) {
    final progressInfo = <String>[];
    
    if (log.progress != null) {
      progressInfo.add('进度: ${log.progress}%');
    }
    
    if (log.transferSpeed != null) {
      progressInfo.add('速度: ${log.transferSpeed}');
    }
    
    if (log.estimatedTime != null) {
      progressInfo.add('预计: ${log.estimatedTime}');
    }
    
    if (progressInfo.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        progressInfo.join(' | '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontFamily: 'Monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 格式化完整时间戳
  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 获取类型颜色
  Color _getTypeColor(ThemeData theme) {
    switch (log.type) {
      case TransferLogType.send:
        return Colors.blue;
      case TransferLogType.receive:
        return Colors.green;
      case TransferLogType.error:
        return Colors.red;
      case TransferLogType.info:
        return Colors.grey;
      case TransferLogType.tcp:
        return Colors.orange;
      case TransferLogType.hash:
        return Colors.purple;
      case TransferLogType.network:
        return Colors.teal;
    }
  }

  /// 获取类型文本
  String _getTypeText() {
    switch (log.type) {
      case TransferLogType.send:
        return 'SEND';
      case TransferLogType.receive:
        return 'RECV';
      case TransferLogType.error:
        return 'ERROR';
      case TransferLogType.info:
        return 'INFO';
      case TransferLogType.tcp:
        return 'TCP';
      case TransferLogType.hash:
        return 'HASH';
      case TransferLogType.network:
        return 'NET';
    }
  }

  /// 复制日志到剪贴板
  void _copyLogToClipboard(BuildContext context) {
    final timeText = showFullTimestamp 
        ? _formatFullTimestamp(log.timestamp)
        : log.timeText;
    final typeText = _getTypeText();
    
    final logText = '$timeText | $typeText | ${log.message}';
    
    // 添加额外信息
    final additionalInfo = <String>[];
    if (log.fileName.isNotEmpty && log.fileName != log.message) {
      additionalInfo.add('文件: ${log.fileName}');
    }
    if (log.deviceName != '未知设备') {
      additionalInfo.add('设备: ${log.deviceName}');
    }
    if (log.fileSize > 0) {
      additionalInfo.add('大小: ${log.fileSizeText}');
    }
    if (log.error != null) {
      additionalInfo.add('错误: ${log.error}');
    }
    if (log.progress != null) {
      additionalInfo.add('进度: ${log.progress}%');
    }
    if (log.transferSpeed != null) {
      additionalInfo.add('速度: ${log.transferSpeed}');
    }
    if (log.estimatedTime != null) {
      additionalInfo.add('预计: ${log.estimatedTime}');
    }
    
    final fullLogText = additionalInfo.isNotEmpty 
        ? '$logText (${additionalInfo.join(', ')})'
        : logText;
    
    // 复制到剪贴板
    _copyToClipboard(context, fullLogText);
  }

  /// 复制文本到剪贴板
  void _copyToClipboard(BuildContext context, String text) {
    try {
      // 使用 Clipboard 类复制文本
      Clipboard.setData(ClipboardData(text: text));
      
      // 显示复制成功的提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('日志已复制到剪贴板'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // 复制失败时显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('复制失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// 传统日志列表组件
class TraditionalLogList extends StatelessWidget {
  final List<TransferLog> logs;
  final bool showFullTimestamp;
  final Function(TransferLog)? onLogTap;

  const TraditionalLogList({
    super.key,
    required this.logs,
    this.showFullTimestamp = false,
    this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return TraditionalLogItem(
          log: log,
          showFullTimestamp: showFullTimestamp,
          onTap: onLogTap != null ? () => onLogTap!(log) : null,
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            '暂无传输日志',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            '开始文件传输后，日志将显示在这里',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 传统日志头部组件
class TraditionalLogHeader extends StatelessWidget {
  final bool showFullTimestamp;

  const TraditionalLogHeader({
    super.key,
    this.showFullTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // 时间标题
          SizedBox(
            width: showFullTimestamp ? 160 : 80,
            child: Text(
              '时间',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Monospace',
              ),
            ),
          ),
          
          const SizedBox(width: AppSpacing.m),
          
          // 类型标题
          SizedBox(
            width: 60,
            child: Text(
              '类型',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Monospace',
              ),
            ),
          ),
          
          const SizedBox(width: AppSpacing.m),
          
          // 日志标题
          Expanded(
            child: Text(
              '日志内容',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
