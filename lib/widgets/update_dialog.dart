import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yolighttransfer/util/version_check_parser.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 应用更新对话框
class UpdateDialog extends StatelessWidget {
  /// 版本检查响应
  final VersionCheckResponse versionResponse;

  /// 当前版本号
  final String currentVersion;

  /// 下载按钮回调
  final VoidCallback? onDownload;

  /// 取消按钮回调
  final VoidCallback? onCancel;

  const UpdateDialog({
    required this.versionResponse,
    required this.currentVersion,
    this.onDownload,
    this.onCancel,
    super.key,
  });

  /// 打开浏览器下载
  Future<void> _openDownloadUrl() async {
    try {
      final url = Uri.parse(versionResponse.downloadUrl);
      
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        onDownload?.call();
      } else {
        print('❌ 无法打开下载链接: ${versionResponse.downloadUrl}');
        _showErrorSnackBar('无法打开下载链接');
      }
    } catch (e) {
      print('❌ 打开下载链接失败: $e');
      _showErrorSnackBar('打开下载链接失败: $e');
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message) {
    // 这里可以通过 ScaffoldMessenger 显示错误信息
    // 由于在对话框中，我们暂时只打印日志
    print('⚠️ $message');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForceUpdate = versionResponse.forceUpdate;

    return AlertDialog(
      title: const Text('发现新版本'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '当前版本',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  currentVersion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '新版本',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'v${versionResponse.version}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // 更新说明
            if (versionResponse.updateDescription != null) ...[
              Text(
                '更新说明',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppBorderRadius.s),
                ),
                child: Text(
                  versionResponse.updateDescription!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
            ],

            // 下载链接（高亮显示）
            Text(
              '下载地址',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: _openDownloadUrl,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.s),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        versionResponse.downloadUrl,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            // 强制更新提示
            if (isForceUpdate) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppBorderRadius.s),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        '此版本为强制更新，请立即更新以获得最佳体验',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 暂不更新按钮（强制更新时隐藏）
        if (!isForceUpdate)
          TextButton(
            onPressed: () {
              onCancel?.call();
              Navigator.of(context).pop();
            },
            child: const Text('暂不更新'),
          ),

        // 打开浏览器下载按钮
        ElevatedButton.icon(
          onPressed: _openDownloadUrl,
          icon: const Icon(Icons.download),
          label: const Text('打开浏览器下载'),
        ),
      ],
    );
  }
}

/// 显示更新对话框的便捷方法
Future<void> showUpdateDialog(
  BuildContext context, {
  required VersionCheckResponse versionResponse,
  required String currentVersion,
  VoidCallback? onDownload,
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !versionResponse.forceUpdate,
    builder: (context) => UpdateDialog(
      versionResponse: versionResponse,
      currentVersion: currentVersion,
      onDownload: onDownload,
      onCancel: onCancel,
    ),
  );
}
