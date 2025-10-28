import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 扫码视图组件
class ScannerView extends StatelessWidget {
  final MobileScannerController? scannerController;
  final bool showScanner;
  final Function(BarcodeCapture) onBarcodeDetected;
  final VoidCallback onToggleScanner;
  final VoidCallback onToggleFlash;

  const ScannerView({
    super.key,
    required this.scannerController,
    required this.showScanner,
    required this.onBarcodeDetected,
    required this.onToggleScanner,
    required this.onToggleFlash,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!showScanner) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        // 扫码区域
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: scannerController,
                onDetect: onBarcodeDetected,
                fit: BoxFit.cover,
              ),
              // 扫码框
              _buildScannerOverlay(theme),
            ],
          ),
        ),
        
        // 操作区域
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '将QR码对准扫描框',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.keyboard),
                      label: const Text('手动输入'),
                      onPressed: onToggleScanner,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.flash_on),
                      label: const Text('打开闪光灯'),
                      onPressed: onToggleFlash,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 扫码框覆盖层
  Widget _buildScannerOverlay(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        // 计算扫码框尺寸，取屏幕宽高的较小值的70%
        final scannerSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.7;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Container(
              width: scannerSize,
              height: scannerSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.m),
              ),
              child: Center(
                child: Container(
                  width: scannerSize - 10,
                  height: scannerSize - 10,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.s),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
