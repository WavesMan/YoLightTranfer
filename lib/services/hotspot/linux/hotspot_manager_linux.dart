import 'dart:io';
import '../base/hotspot_manager.dart';

/// Linux热点管理器
class HotspotManagerLinux extends HotspotManager {
  @override
  String get platformName => 'Linux';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      // 使用nmcli创建热点
      final result = await Process.run('nmcli', [
        'dev',
        'wifi',
        'hotspot',
        'ifname',
        'wlan0',
        'ssid',
        ssid,
        'password',
        password,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('Linux创建热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> stopHotspot() async {
    try {
      final result = await Process.run('nmcli', [
        'con',
        'down',
        'Hotspot',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('Linux停止热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      final result = await Process.run('nmcli', [
        'dev',
        'wifi',
        'connect',
        ssid,
        'password',
        password,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('Linux连接热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> isHotspotSupported() async {
    try {
      final result = await Process.run('nmcli', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      print('Linux检查热点支持失败: $e');
      return false;
    }
  }

  @override
  Future<bool> isHotspotRunning() async {
    try {
      final result = await Process.run('nmcli', [
        'con',
        'show',
        '--active',
      ]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return output.contains('Hotspot');
      }
      return false;
    } catch (e) {
      print('Linux检查热点状态失败: $e');
      return false;
    }
  }

  @override
  Future<bool> disconnectFromHotspot() async {
    print('=== Linux断开热点连接 ===');
    try {
      final result = await Process.run('nmcli', [
        'dev', 'disconnect', 'wlan0'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('Linux断开热点连接失败: $e');
      return false;
    }
  }

  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== Linux获取当前连接信息 ===');
    try {
      final result = await Process.run('nmcli', [
        'dev', 'wifi'
      ]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // 解析连接信息
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('*') && line.contains('Infra')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              final ssid = parts[1];
              final signal = parts[6];
              double signalStrength = 0.0;
              
              try {
                signalStrength = double.parse(signal) / 100.0;
              } catch (e) {
                print('信号强度解析失败: $e');
              }
              
              return (ssid: ssid, signalStrength: signalStrength);
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Linux获取连接信息失败: $e');
      return null;
    }
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== Linux获取实际热点信息 ===');
    // Linux 不支持获取实际热点信息
    print('⚠️ Linux平台不支持获取实际热点信息');
    return null;
  }
}
