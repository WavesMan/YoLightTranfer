import 'package:flutter/material.dart';
import 'dart:io';

/// 操作按钮组件
class ActionButtons extends StatelessWidget {
  final bool isHotspotRunning;
  final bool isLoading;
  final VoidCallback? onToggleHotspot;

  const ActionButtons({
    super.key,
    required this.isHotspotRunning,
    required this.isLoading,
    this.onToggleHotspot,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Platform.isWindows ? Icons.open_in_new : (isHotspotRunning ? Icons.stop : Icons.play_arrow)),
            label: Text(Platform.isWindows ? '开启热点设置' : (isHotspotRunning ? '关闭热点' : '开启热点')),
            onPressed: isLoading ? null : onToggleHotspot,
          ),
        ),
        if (Platform.isWindows) ...[
          const SizedBox(height: 8),
          Text(
            '点击后将跳转到Windows系统设置',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
