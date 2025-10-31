// 网关检测服务
// 跨平台默认网关IP检测

import 'dart:io';
import 'dart:async';

/// 网关检测结果
class GatewayDetectionResult {
  final String? gatewayIp;
  final List<String> possibleGateways;
  final bool isReachable;
  final String platform;
  final String? error;

  const GatewayDetectionResult({
    this.gatewayIp,
    this.possibleGateways = const [],
    this.isReachable = false,
    required this.platform,
    this.error,
  });

  @override
  String toString() {
    return 'GatewayDetectionResult(gatewayIp: $gatewayIp, possibleGateways: $possibleGateways, isReachable: $isReachable, platform: $platform, error: $error)';
  }
}

/// 网关检测器
class GatewayDetector {
  static const List<String> _commonGateways = [
    '192.168.1.1',
    '192.168.0.1',
    '192.168.1.254',
    '192.168.0.254',
    '10.0.0.1',
    '10.0.1.1',
    '172.16.0.1',
    '172.16.1.1',
  ];

  /// 检测默认网关
  Future<GatewayDetectionResult> detectDefaultGateway() async {
    try {
      if (Platform.isAndroid) {
        return await _detectAndroidGateway();
      } else if (Platform.isWindows) {
        return await _detectWindowsGateway();
      } else if (Platform.isIOS || Platform.isMacOS) {
        return await _detectAppleGateway();
      } else {
        // 其他平台使用通用检测方法
        return await _detectGenericGateway();
      }
    } catch (e) {
      return GatewayDetectionResult(
        platform: Platform.operatingSystem,
        error: '网关检测异常: $e',
      );
    }
  }

  /// 检测可能的网关列表
  Future<List<String>> detectPossibleGateways() async {
    final result = await detectDefaultGateway();
    final gateways = <String>[];
    
    if (result.gatewayIp != null) {
      gateways.add(result.gatewayIp!);
    }
    
    gateways.addAll(result.possibleGateways);
    gateways.addAll(_commonGateways);
    
    // 去重
    return gateways.toSet().toList();
  }

  /// 检查网关是否可达
  Future<bool> isGatewayReachable(String ip, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Android平台网关检测
  Future<GatewayDetectionResult> _detectAndroidGateway() async {
    try {
      // Android: 使用NetworkInterface获取网络信息
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            // 简单的网关推断：基于常见子网
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final possibleGateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
              if (await isGatewayReachable(possibleGateway)) {
                return GatewayDetectionResult(
                  gatewayIp: possibleGateway,
                  possibleGateways: [possibleGateway],
                  isReachable: true,
                  platform: 'Android',
                );
              }
            }
          }
        }
      }
      
      // 如果推断失败，尝试常见网关
      return await _tryCommonGateways('Android');
    } catch (e) {
      return GatewayDetectionResult(
        platform: 'Android',
        error: 'Android网关检测失败: $e',
      );
    }
  }

  /// Windows平台网关检测
  Future<GatewayDetectionResult> _detectWindowsGateway() async {
    try {
      // Windows: 解析route print命令输出
      final result = await Process.run('route', ['print']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');
        
        // 查找默认路由行
        for (final line in lines) {
          if (line.contains('0.0.0.0') && line.contains('0.0.0.0')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              final gateway = parts[2];
              if (_isValidIp(gateway) && await isGatewayReachable(gateway)) {
                return GatewayDetectionResult(
                  gatewayIp: gateway,
                  possibleGateways: [gateway],
                  isReachable: true,
                  platform: 'Windows',
                );
              }
            }
          }
        }
      }
      
      // 如果route命令失败，尝试ipconfig
      final ipconfigResult = await Process.run('ipconfig', []);
      if (ipconfigResult.exitCode == 0) {
        final output = ipconfigResult.stdout as String;
        final lines = output.split('\n');
        
        String? currentInterface;
        for (final line in lines) {
          if (line.contains('适配器')) {
            currentInterface = line.trim();
          } else if (line.contains('默认网关') && currentInterface != null) {
            final gatewayMatch = RegExp(r'[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+').firstMatch(line);
            if (gatewayMatch != null) {
              final gateway = gatewayMatch.group(0)!;
              if (await isGatewayReachable(gateway)) {
                return GatewayDetectionResult(
                  gatewayIp: gateway,
                  possibleGateways: [gateway],
                  isReachable: true,
                  platform: 'Windows',
                );
              }
            }
          }
        }
      }
      
      return await _tryCommonGateways('Windows');
    } catch (e) {
      return GatewayDetectionResult(
        platform: 'Windows',
        error: 'Windows网关检测失败: $e',
      );
    }
  }

  /// Apple平台网关检测 (iOS/macOS)
  Future<GatewayDetectionResult> _detectAppleGateway() async {
    try {
      // macOS/iOS: 使用netstat命令
      final result = await Process.run('netstat', ['-rn']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');
        
        for (final line in lines) {
          if (line.contains('default') || line.contains('0.0.0.0')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            for (final part in parts) {
              if (_isValidIp(part) && await isGatewayReachable(part)) {
                return GatewayDetectionResult(
                  gatewayIp: part,
                  possibleGateways: [part],
                  isReachable: true,
                  platform: Platform.isIOS ? 'iOS' : 'macOS',
                );
              }
            }
          }
        }
      }
      
      return await _tryCommonGateways(Platform.isIOS ? 'iOS' : 'macOS');
    } catch (e) {
      return GatewayDetectionResult(
        platform: Platform.isIOS ? 'iOS' : 'macOS',
        error: 'Apple平台网关检测失败: $e',
      );
    }
  }

  /// 通用网关检测方法
  Future<GatewayDetectionResult> _detectGenericGateway() async {
    return await _tryCommonGateways(Platform.operatingSystem);
  }

  /// 尝试常见网关地址
  Future<GatewayDetectionResult> _tryCommonGateways(String platform) async {
    final reachableGateways = <String>[];
    
    for (final gateway in _commonGateways) {
      if (await isGatewayReachable(gateway)) {
        reachableGateways.add(gateway);
      }
    }
    
    if (reachableGateways.isNotEmpty) {
      return GatewayDetectionResult(
        gatewayIp: reachableGateways.first,
        possibleGateways: reachableGateways,
        isReachable: true,
        platform: platform,
      );
    }
    
    return GatewayDetectionResult(
      platform: platform,
      error: '未找到可达的网关',
    );
  }

  /// 验证IP地址格式
  bool _isValidIp(String ip) {
    final ipRegex = RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    return ipRegex.hasMatch(ip);
  }

  /// 获取网络接口信息（用于调试）
  Future<List<NetworkInterface>> getNetworkInterfaces() async {
    return await NetworkInterface.list();
  }
}
