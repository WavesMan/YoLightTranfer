import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 热点权限处理器
class HotspotPermissionHandler {
  /// 检查并请求必要的权限
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    try {
      print('=== 检查权限 ===');
      
      // Android 13+ 需要 NEARBY_WIFI_DEVICES 权限
      final nearbyPermission = await Permission.nearbyWifiDevices.status;
      print('NEARBY_WIFI_DEVICES 权限状态: $nearbyPermission');
      
      if (!nearbyPermission.isGranted) {
        print('请求 NEARBY_WIFI_DEVICES 权限...');
        final result = await Permission.nearbyWifiDevices.request();
        print('权限请求结果: $result');
        
        if (!result.isGranted) {
          _showPermissionDialog(context);
          return false;
        }
      }
      
      // 检查其他必要的权限
      final locationPermission = await Permission.location.status;
      print('位置权限状态: $locationPermission');
      
      // 如果位置权限未授予，尝试请求
      if (!locationPermission.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          print('位置权限未授予，但继续尝试创建热点');
        }
      }
      
      // 申请WiFi状态权限（Android 10+ 需要）
      await _requestWifiPermissions();
      
      print('✅ 权限检查通过');
      return true;
    } catch (e) {
      print('❌ 权限检查异常: $e');
      return false;
    }
  }

  /// 请求WiFi相关权限
  static Future<void> _requestWifiPermissions() async {
    try {
      print('=== 请求WiFi权限 ===');
      
      // 在AndroidManifest.xml中声明权限，运行时权限由系统自动处理
      // 对于WiFi状态权限，通常只需要在AndroidManifest.xml中声明即可
      // 运行时权限主要针对位置权限和附近设备权限
      
      print('✅ WiFi权限检查完成（权限已在AndroidManifest.xml中声明）');
    } catch (e) {
      print('❌ WiFi权限请求异常: $e');
    }
  }

  /// 显示权限请求对话框
  static void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要权限'),
        content: const Text(
          '创建热点需要"附近WiFi设备"权限。\n\n'
          '请前往系统设置手动授予权限，然后重试。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
}
