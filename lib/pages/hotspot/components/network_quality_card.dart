import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/services/ai_network_quality_manager.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:url_launcher/url_launcher.dart';

/// 网络质量卡片组件
class NetworkQualityCard extends StatelessWidget {
  final VoidCallback? onManualDetection;

  const NetworkQualityCard({
    super.key,
    this.onManualDetection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<AINetworkQualityManager>(
      builder: (context, qualityManager, _) {
        final result = qualityManager.lastResult;
        final state = qualityManager.currentState;
        final networkQuality = result?.recommendation?.networkQuality;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.m),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '网络质量',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // 手动检测按钮
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: onManualDetection,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (state == NetworkQualityState.detecting) ...[
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('正在检测网络质量...'),
                      ],
                    ),
                  ),
                ] else if (networkQuality != null) ...[
                  _buildQualityRow('带宽', '${networkQuality.bandwidthMbps.toStringAsFixed(2)} Mbps'),
                  _buildQualityRow('延迟', '${networkQuality.avgDelayMs.toStringAsFixed(0)} ms'),
                  _buildQualityRow('丢包率', '${networkQuality.packetLossRate.toStringAsFixed(2)}%'),
                  
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStateColor(state).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.s),
                    ),
                    child: Text(
                      result?.message ?? '检测中...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStateColor(state),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (state == NetworkQualityState.weakNetwork) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://yolighttransfer.app/faq/network');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: const Text('提升建议'),
                      ),
                    ),
                  ],
                ] else if (state == NetworkQualityState.noDevices) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '附近无其他开启设备',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '等待检查网络质量中',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: onManualDetection,
                          child: const Text('重新检测'),
                        ),
                      ],
                    ),
                  ),
                ] else if (state == NetworkQualityState.error) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '网络质量检测失败',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: onManualDetection,
                          child: const Text('重试检测'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 网络质量行
  Widget _buildQualityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 根据状态获取颜色
  Color _getStateColor(NetworkQualityState state) {
    switch (state) {
      case NetworkQualityState.weakNetwork:
        return Colors.orange;
      case NetworkQualityState.normalNetwork:
        return Colors.green;
      case NetworkQualityState.noDevices:
        return Colors.grey;
      case NetworkQualityState.error:
        return Colors.red;
      case NetworkQualityState.detecting:
        return Colors.blue;
      case NetworkQualityState.idle:
      default:
        return Colors.grey;
    }
  }
}
