import 'package:flutter/material.dart';
import 'dart:io';

/// 操作按钮组件
class ActionButtons extends StatelessWidget {
  final bool showScanner;
  final VoidCallback onToggleScanner;

  const ActionButtons({
    super.key,
    required this.showScanner,
    required this.onToggleScanner,
  });

  @override
  Widget build(BuildContext context) {
    // 只在Android平台显示扫码选项
    if (!Platform.isAndroid || showScanner) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('扫描QR码连接'),
            onPressed: onToggleScanner,
          ),
        ),
      ],
    );
  }
}
