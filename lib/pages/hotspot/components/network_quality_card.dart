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
        final networkQuality = result?.recommendation?.networkQuality ?? result?.gatewayQuality;

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
                ] else if (state == NetworkQualityState.gatewayTesting) ...[
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('正在测试网关网络质量...'),
                        SizedBox(height: 4),
                        Text(
                          '附近无其他设备，已切换到网关测速',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else if (networkQuality != null || state == NetworkQualityState.normalNetwork) ...[
                  if (networkQuality != null) ...[
                    _buildQualityRow('带宽', _formatBandwidth(networkQuality.bandwidthMbps)),
                    _buildQualityRow('延迟', _formatDelay(networkQuality.avgDelayMs)),
                    _buildQualityRow('丢包率', _formatPacketLoss(networkQuality.packetLossRate)),
                    const SizedBox(height: 8),
                  ],
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
                          '附近无其他设备',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '网关测速失败或不可用',
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
      case NetworkQualityState.gatewayTesting:
        return Colors.blue;
      case NetworkQualityState.error:
        return Colors.red;
      case NetworkQualityState.detecting:
        return Colors.blue;
      case NetworkQualityState.idle:
      default:
        return Colors.grey;
    }
  }

  /// 格式化带宽显示（符号化）
  String _formatBandwidth(double bandwidthMbps) {
    if (bandwidthMbps > 100) {
      return '>100 Mbps'; // 高速网络
    } else if (bandwidthMbps > 50) {
      return '≈${bandwidthMbps.toStringAsFixed(0)} Mbps'; // 约等于
    } else if (bandwidthMbps > 20) {
      return '≈${bandwidthMbps.toStringAsFixed(0)} Mbps'; // 约等于
    } else if (bandwidthMbps > 10) {
      return '≈${bandwidthMbps.toStringAsFixed(0)} Mbps'; // 约等于
    } else if (bandwidthMbps > 5) {
      return '≈${bandwidthMbps.toStringAsFixed(0)} Mbps'; // 约等于
    } else if (bandwidthMbps > 1) {
      return '≈${bandwidthMbps.toStringAsFixed(1)} Mbps'; // 约等于
    } else {
      return '<1 Mbps'; // 低速网络
    }
  }

  /// 格式化延迟显示（符号化）
  String _formatDelay(double delayMs) {
    if (delayMs < 10) {
      return '<10 ms'; // 极低延迟
    } else if (delayMs < 20) {
      return '≈${delayMs.toStringAsFixed(0)} ms'; // 约等于
    } else if (delayMs < 50) {
      return '≈${delayMs.toStringAsFixed(0)} ms'; // 约等于
    } else if (delayMs < 100) {
      return '≈${delayMs.toStringAsFixed(0)} ms'; // 约等于
    } else {
      return '>100 ms'; // 高延迟
    }
  }

  /// 格式化丢包率显示（符号化）
  String _formatPacketLoss(double packetLossRate) {
    if (packetLossRate < 0.1) {
      return '≈0%'; // 无丢包
    } else if (packetLossRate < 1) {
      return '≈${packetLossRate.toStringAsFixed(1)}%'; // 约等于
    } else if (packetLossRate < 5) {
      return '≈${packetLossRate.toStringAsFixed(1)}%'; // 约等于
    } else if (packetLossRate < 10) {
      return '≈${packetLossRate.toStringAsFixed(1)}%'; // 约等于
    } else {
      return '>10%'; // 严重丢包
    }
  }
}
