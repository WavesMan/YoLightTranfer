import 'package:flutter/material.dart';
import 'dart:io';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 平台信息卡片组件
class PlatformInfoCard extends StatelessWidget {
  const PlatformInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getPlatformIcon(),
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '连接方式',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getConnectionMethod(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取平台图标
  IconData _getPlatformIcon() {
    if (Platform.isAndroid) return Icons.android;
    if (Platform.isWindows) return Icons.computer;
    if (Platform.isIOS) return Icons.phone_iphone;
    if (Platform.isMacOS) return Icons.desktop_mac;
    return Icons.device_unknown;
  }

  /// 获取连接方式描述
  String _getConnectionMethod() {
    if (Platform.isAndroid) {
      return '支持扫码连接和手动输入';
    } else if (Platform.isWindows) {
      return '支持手动输入连接';
    } else if (Platform.isIOS || Platform.isMacOS) {
      return '请跳转到系统设置连接';
    } else {
      return '请使用系统设置连接';
    }
  }
}
