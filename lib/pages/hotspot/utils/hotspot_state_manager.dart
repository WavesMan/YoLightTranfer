import 'package:flutter/material.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_manager.dart';

/// 热点状态管理器
class HotspotStateManager {
  final HotspotManager hotspotManager;
  final VoidCallback onStateChanged;

  HotspotStateManager({
    required this.hotspotManager,
    required this.onStateChanged,
  });

  /// 显示实际热点信息对话框
  static void showActualHotspotInfoDialog(
    BuildContext context, {
    required String actualSsid,
    required String actualPassword,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('系统生成的热点信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android 系统自动生成了热点凭据，请使用以下信息连接：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildInfoRowDialog('SSID', actualSsid),
            _buildInfoRowDialog('密码', actualPassword),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '请使用系统生成的凭据连接热点',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示 SnackBar
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 对话框中的信息行
  static Widget _buildInfoRowDialog(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
