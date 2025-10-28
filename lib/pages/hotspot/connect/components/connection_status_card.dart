import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 连接状态卡片组件
class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final String connectedSsid;
  final double signalStrength;

  const ConnectionStatusCard({
    super.key,
    required this.isConnected,
    required this.connectedSsid,
    required this.signalStrength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!isConnected) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      color: Colors.green.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.m),
        side: BorderSide(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.wifi,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已连接',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '热点: $connectedSsid',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '信号强度: ${(signalStrength * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 信号强度指示器
            _buildSignalIndicator(),
          ],
        ),
      ),
    );
  }

  /// 信号强度指示器
  Widget _buildSignalIndicator() {
    final signalBars = (signalStrength * 4).ceil(); // 0-4格信号
    return Row(
      children: List.generate(4, (index) {
        final isActive = index < signalBars;
        return Container(
          width: 4,
          height: (index + 1) * 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
