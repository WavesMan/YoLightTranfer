import 'package:flutter/material.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_manager.dart';
import 'qr_code_parser.dart';

/// 连接管理工具类
class ConnectionManager {
  final HotspotManager hotspotManager;
  final Function(String) showSuccess;
  final Function(String) showError;

  ConnectionManager({
    required this.hotspotManager,
    required this.showSuccess,
    required this.showError,
  });

  /// 连接到热点
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
    required VoidCallback onConnecting,
    required VoidCallback onConnected,
  }) async {
    print('=== 尝试连接热点 ===');
    print('SSID: $ssid');
    print('密码长度: ${password.length}');

    // 验证凭据
    final validation = QRCodeParser.validateCredentials(ssid, password);
    if (!validation.success) {
      showError(validation.error!);
      return false;
    }

    onConnecting();

    try {
      print('开始连接热点...');
      final success = await hotspotManager.connectToHotspot(
        ssid: ssid,
        password: password,
      );

      print('连接结果: $success');

      if (success) {
        print('✅ 热点连接成功');
        showSuccess('连接成功');
        onConnected();
        return true;
      } else {
        print('❌ 热点连接失败');
        showError('连接失败，请检查SSID和密码');
        return false;
      }
    } catch (e, stack) {
      print('❌ 连接异常: $e');
      print('堆栈: $stack');
      showError('连接异常: $e');
      return false;
    }
  }


  /// 检查连接状态
  Future<ConnectionStatus?> checkConnectionStatus() async {
    try {
      print('检查连接状态...');
      final connection = await hotspotManager.getCurrentConnection();

      if (connection != null) {
        print('✅ 检测到连接: ${connection.ssid}, 信号强度: ${(connection.signalStrength * 100).toStringAsFixed(0)}%');
        return ConnectionStatus(
          isConnected: true,
          ssid: connection.ssid,
          signalStrength: connection.signalStrength,
        );
      } else {
        print('⚠️ 未检测到连接');
        return ConnectionStatus(
          isConnected: false,
          ssid: '',
          signalStrength: 0.0,
        );
      }
    } catch (e, stack) {
      print('❌ 检查连接状态异常: $e');
      print('堆栈: $stack');
      return null;
    }
  }
}

/// 连接状态
class ConnectionStatus {
  final bool isConnected;
  final String ssid;
  final double signalStrength;

  ConnectionStatus({
    required this.isConnected,
    required this.ssid,
    required this.signalStrength,
  });
}
