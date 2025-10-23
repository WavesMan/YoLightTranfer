import 'package:flutter/material.dart';
import 'package:yolighttransfer/models/device.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/theme/app_colors.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key, 
    required this.device,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceColor = device.type.color;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 响应式设计：根据屏幕宽度调整布局
    final isSmallScreen = screenWidth < 400;
    final cardHeight = isSmallScreen ? 85.0 : 95.0; // 稍微增加高度避免溢出
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final bodyFontSize = isSmallScreen ? 11.0 : 12.0;

    return Card(
      // 根据选中状态调整颜色
      color: isSelected 
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.surfaceVariant,
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.cardBorderRadius,
        side: isSelected 
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.cardBorderRadius,
        child: Container(
          height: cardHeight,
          padding: isSmallScreen 
              ? const EdgeInsets.all(12) 
              : AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 设备图标区域
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: deviceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  device.type.icon,
                  size: iconSize,
                  color: deviceColor,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              
              // 设备信息区域 - 横向多列布局
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // 第一行：设备名称和选中状态
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: titleFontSize,
                                color: isSelected 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                    
                    // 第二行：IP地址和设备类型
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatIpAddress(device.ip, isSmallScreen),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected 
                                    ? theme.colorScheme.primary.withOpacity(0.8)
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: bodyFontSize,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: deviceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getDeviceTypeText(device.type),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: deviceColor,
                                fontSize: bodyFontSize - 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 第三行：在线状态和最后活跃时间
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: device.status == DeviceStatus.online
                                  ? AppStatusColors.success
                                  : theme.colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            device.status == DeviceStatus.online ? '在线' : '离线',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected 
                                  ? theme.colorScheme.primary.withOpacity(0.8)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: bodyFontSize,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Text(
                              device.lastSeen,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected 
                                    ? theme.colorScheme.primary.withOpacity(0.6)
                                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                fontSize: bodyFontSize,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化IP地址显示，在小屏设备上优化显示
  String _formatIpAddress(String ip, bool isSmallScreen) {
    if (!isSmallScreen) {
      return 'IP: $ip';
    }
    
    // 在小屏设备上，如果IP地址过长，进行简化处理
    if (ip.length > 20) {
      // 提取IP和端口号
      final parts = ip.split(':');
      if (parts.length == 2) {
        final ipAddress = parts[0];
        final port = parts[1];
        
        // 如果IP地址过长，截取显示
        if (ipAddress.length > 15) {
          return 'IP: ${ipAddress.substring(0, 12)}...:$port';
        }
      }
    }
    
    return 'IP: $ip';
  }

  /// 获取设备类型文本
  String _getDeviceTypeText(DeviceType type) {
    switch (type) {
      case DeviceType.windows:
        return 'Windows';
      case DeviceType.android:
        return 'Android';
      case DeviceType.harmonyos:
        return 'HarmonyOS';
      case DeviceType.linux:
        return 'Linux';
      case DeviceType.macos:
        return 'macOS';
    }
  }
}
