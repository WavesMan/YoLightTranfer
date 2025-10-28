// 网络质量推荐弹窗组件
// 在文件传输和热点分享页面显示热点推荐弹窗

import 'package:flutter/material.dart';
import 'package:yolighttransfer/services/ai_network_quality_manager.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 网络质量推荐弹窗
class NetworkQualityRecommendationDialog extends StatelessWidget {
  final AINetworkQualityManager qualityManager;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDismiss;

  const NetworkQualityRecommendationDialog({
    super.key,
    required this.qualityManager,
    this.onAccept,
    this.onReject,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = qualityManager.lastResult;
    final recommendation = result?.recommendation;
    final networkQuality = recommendation?.networkQuality;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.l),
      ),
      title: Row(
        children: [
          Icon(
            Icons.wifi_tethering,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '网络质量建议',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '检测到当前网络环境较差，建议开启热点进行文件传输：',
            style: theme.textTheme.bodyMedium,
          ),
          
          const SizedBox(height: 16),
          
          // 网络质量详情
          if (networkQuality != null) ...[
            _buildQualityDetail('带宽', '${networkQuality.bandwidthMbps.toStringAsFixed(2)} Mbps'),
            _buildQualityDetail('延迟', '${networkQuality.avgDelayMs.toStringAsFixed(0)} ms'),
            _buildQualityDetail('丢包率', '${networkQuality.packetLossRate.toStringAsFixed(2)}%'),
            
            const SizedBox(height: 12),
          ],
          
          // 推荐原因
          if (recommendation?.reason != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.s),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation!.reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // 温馨提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.s),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '开启热点可以建立更稳定的局域网连接，提高文件传输成功率',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 拒绝按钮
        TextButton(
          onPressed: () {
            qualityManager.rejectRecommendation();
            onReject?.call();
            Navigator.of(context).pop();
          },
          child: const Text('暂不开启'),
        ),
        
        // 接受按钮
        ElevatedButton(
          onPressed: () {
            qualityManager.acceptRecommendation();
            onAccept?.call();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('开启热点'),
        ),
      ],
    );
  }

  /// 构建网络质量详情行
  Widget _buildQualityDetail(String label, String value) {
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

  /// 显示推荐弹窗
  static Future<void> show({
    required BuildContext context,
    required AINetworkQualityManager qualityManager,
    VoidCallback? onAccept,
    VoidCallback? onReject,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 必须手动选择
      builder: (BuildContext context) {
        return NetworkQualityRecommendationDialog(
          qualityManager: qualityManager,
          onAccept: onAccept,
          onReject: onReject,
        );
      },
    );
  }
}
