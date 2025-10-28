import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 热点状态卡片组件
class HotspotStatusCard extends StatelessWidget {
  final bool isHotspotRunning;
  final bool isLoading;
  final String platformName;
  final ValueChanged<bool>? onToggleHotspot;

  const HotspotStatusCard({
    super.key,
    required this.isHotspotRunning,
    required this.isLoading,
    required this.platformName,
    this.onToggleHotspot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '热点状态',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isHotspotRunning ? '✅ 已开启' : '❌ 已关闭',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isHotspotRunning ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '平台: $platformName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Switch(
              value: isHotspotRunning,
              onChanged: isLoading ? null : onToggleHotspot,
            ),
          ],
        ),
      ),
    );
  }
}
