import 'package:flutter/material.dart';
import 'package:yolighttransfer/models/transfer_state.dart';
import 'package:yolighttransfer/services/file/enhanced_file_hash_service.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 传输状态指示器组件
class TransferStatusIndicator extends StatelessWidget {
  final TransferState transferState;
  final ConnectionQuality connectionQuality;
  final FileVerificationResult verificationResult;
  final int progress;
  final String? transferSpeed;
  final String? estimatedTime;
  final String? fileName;
  final String? fileSize;
  final String? fileHash;
  final bool showDetails;
  final VoidCallback? onTap;

  const TransferStatusIndicator({
    super.key,
    required this.transferState,
    required this.connectionQuality,
    required this.verificationResult,
    this.progress = 0,
    this.transferSpeed,
    this.estimatedTime,
    this.fileName,
    this.fileSize,
    this.fileHash,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppBorderRadius.cardBorderRadius,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态标题行
            _buildStatusHeader(theme),
            
            const SizedBox(height: AppSpacing.m),
            
            // 进度条
            _buildProgressBar(theme),
            
            const SizedBox(height: AppSpacing.m),
            
            // 详细信息（可选）
            if (showDetails) ..._buildDetails(theme),
          ],
        ),
      ),
    );
  }

  /// 构建状态标题行
  Widget _buildStatusHeader(ThemeData theme) {
    return Row(
      children: [
        // 状态图标
        Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: _getStateColor(theme),
            borderRadius: BorderRadius.circular(AppBorderRadius.s),
          ),
          child: Text(
            transferState.icon,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        
        const SizedBox(width: AppSpacing.m),
        
        // 状态文本
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transferState.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getStateColor(theme),
                ),
              ),
              if (fileName != null) ...[
                const SizedBox(height: 2),
                Text(
                  fileName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        
        // 连接质量指示器
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppBorderRadius.s),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                connectionQuality.icon,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                connectionQuality.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(ThemeData theme) {
    return Column(
      children: [
        // 进度文本
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度: $progress%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (transferSpeed != null)
              Text(
                '速度: $transferSpeed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (estimatedTime != null)
              Text(
                '预计: $estimatedTime',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.s),
        
        // 进度条
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: theme.colorScheme.surfaceVariant,
          color: _getStateColor(theme),
          minHeight: 6,
          borderRadius: BorderRadius.circular(AppBorderRadius.s),
        ),
      ],
    );
  }

  /// 构建详细信息
  List<Widget> _buildDetails(ThemeData theme) {
    return [
      const SizedBox(height: AppSpacing.m),
      
      // 文件信息
      if (fileSize != null)
        _buildDetailItem(
          theme,
          icon: Icons.description,
          label: '文件大小',
          value: fileSize!,
        ),
      
      // 校验状态
      _buildDetailItem(
        theme,
        icon: _getVerificationIcon(),
        label: '完整性校验',
        value: verificationResult.text,
        valueColor: _getVerificationColor(theme),
      ),
      
      // 文件哈希（如果可用）
      if (fileHash != null && verificationResult != FileVerificationResult.pending)
        _buildDetailItem(
          theme,
          icon: Icons.fingerprint,
          label: '文件哈希',
          value: EnhancedFileHashService.formatHashForDisplay(fileHash!),
        ),
      
      // 状态描述
      _buildDetailItem(
        theme,
        icon: Icons.info,
        label: '状态描述',
        value: _getStatusDescription(),
      ),
    ];
  }

  /// 构建详细信息项
  Widget _buildDetailItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取状态颜色
  Color _getStateColor(ThemeData theme) {
    switch (transferState) {
      case TransferState.pending:
        return theme.colorScheme.onSurfaceVariant;
      case TransferState.accepted:
        return theme.colorScheme.primary;
      case TransferState.transferring:
        return theme.colorScheme.primary;
      case TransferState.verifying:
        return Colors.orange;
      case TransferState.completed:
        return theme.colorScheme.primary;
      case TransferState.failed:
        return theme.colorScheme.error;
      case TransferState.cancelled:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// 获取校验图标
  IconData _getVerificationIcon() {
    switch (verificationResult) {
      case FileVerificationResult.pending:
        return Icons.hourglass_empty;
      case FileVerificationResult.success:
        return Icons.verified;
      case FileVerificationResult.failed:
        return Icons.error;
      case FileVerificationResult.skipped:
        return Icons.skip_next;
    }
  }

  /// 获取校验颜色
  Color _getVerificationColor(ThemeData theme) {
    switch (verificationResult) {
      case FileVerificationResult.pending:
        return theme.colorScheme.onSurfaceVariant;
      case FileVerificationResult.success:
        return theme.colorScheme.primary;
      case FileVerificationResult.failed:
        return theme.colorScheme.error;
      case FileVerificationResult.skipped:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// 获取状态描述
  String _getStatusDescription() {
    switch (transferState) {
      case TransferState.pending:
        return '等待对方确认接收文件';
      case TransferState.accepted:
        return '对方已接受文件，准备开始传输';
      case TransferState.transferring:
        return '正在传输文件数据';
      case TransferState.verifying:
        return '正在验证文件完整性';
      case TransferState.completed:
        return verificationResult == FileVerificationResult.success
            ? '文件传输完成且完整性验证通过'
            : '文件传输完成';
      case TransferState.failed:
        return '文件传输失败，请检查网络连接';
      case TransferState.cancelled:
        return '文件传输已取消';
    }
  }
}

/// 传输状态卡片组件
class TransferStatusCard extends StatelessWidget {
  final String title;
  final TransferState transferState;
  final ConnectionQuality connectionQuality;
  final FileVerificationResult verificationResult;
  final int progress;
  final String? fileName;
  final String? fileSize;
  final String? transferSpeed;
  final String? estimatedTime;
  final Widget? trailing;
  final VoidCallback? onTap;

  const TransferStatusCard({
    super.key,
    required this.title,
    required this.transferState,
    required this.connectionQuality,
    required this.verificationResult,
    this.progress = 0,
    this.fileName,
    this.fileSize,
    this.transferSpeed,
    this.estimatedTime,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.cardBorderRadius,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              
              const SizedBox(height: AppSpacing.m),
              
              // 状态指示器
              TransferStatusIndicator(
                transferState: transferState,
                connectionQuality: connectionQuality,
                verificationResult: verificationResult,
                progress: progress,
                fileName: fileName,
                fileSize: fileSize,
                transferSpeed: transferSpeed,
                estimatedTime: estimatedTime,
                showDetails: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简化的传输状态指示器（用于列表项）
class CompactTransferStatus extends StatelessWidget {
  final TransferState transferState;
  final FileVerificationResult verificationResult;
  final int progress;

  const CompactTransferStatus({
    super.key,
    required this.transferState,
    required this.verificationResult,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态图标
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _getStateColor(theme),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            transferState.icon,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        
        const SizedBox(width: 4),
        
        // 进度文本
        Text(
          '$progress%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(width: 4),
        
        // 校验状态
        if (verificationResult != FileVerificationResult.pending)
          Text(
            verificationResult.icon,
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  /// 获取状态颜色
  Color _getStateColor(ThemeData theme) {
    switch (transferState) {
      case TransferState.pending:
        return theme.colorScheme.onSurfaceVariant;
      case TransferState.accepted:
        return theme.colorScheme.primary;
      case TransferState.transferring:
        return theme.colorScheme.primary;
      case TransferState.verifying:
        return Colors.orange;
      case TransferState.completed:
        return theme.colorScheme.primary;
      case TransferState.failed:
        return theme.colorScheme.error;
      case TransferState.cancelled:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
