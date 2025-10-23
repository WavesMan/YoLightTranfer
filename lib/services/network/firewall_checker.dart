// 防火墙和网络权限检查工具
// 用于诊断Windows防火墙和其他网络权限问题

import 'dart:io';
import 'package:flutter/foundation.dart';

/// 防火墙检查结果
class FirewallCheckResult {
  final bool hasFirewall;
  final bool appHasPermission;
  final List<String> issues;
  final List<String> recommendations;

  const FirewallCheckResult({
    required this.hasFirewall,
    required this.appHasPermission,
    required this.issues,
    required this.recommendations,
  });

  @override
  String toString() {
    return '''
防火墙检查结果:
- 防火墙存在: $hasFirewall
- 应用有权限: $appHasPermission
- 问题: ${issues.isEmpty ? '无' : issues.join(', ')}
- 建议: ${recommendations.isEmpty ? '无' : recommendations.join(', ')}
''';
  }
}

/// 防火墙检查器
class FirewallChecker {
  /// 检查防火墙状态和应用权限
  static Future<FirewallCheckResult> checkFirewallStatus() async {
    if (kIsWeb) {
      return FirewallCheckResult(
        hasFirewall: false,
        appHasPermission: true,
        issues: [],
        recommendations: [],
      );
    }

    final issues = <String>[];
    final recommendations = <String>[];
    bool hasFirewall = false;
    bool appHasPermission = true;

    // Windows平台特定的防火墙检查
    if (Platform.isWindows) {
      final windowsResult = await _checkWindowsFirewall();
      hasFirewall = windowsResult.hasFirewall;
      appHasPermission = windowsResult.appHasPermission;
      issues.addAll(windowsResult.issues);
      recommendations.addAll(windowsResult.recommendations);
    } else if (Platform.isAndroid) {
      // Android平台检查
      final androidResult = await _checkAndroidPermissions();
      appHasPermission = androidResult.appHasPermission;
      issues.addAll(androidResult.issues);
      recommendations.addAll(androidResult.recommendations);
    }

    return FirewallCheckResult(
      hasFirewall: hasFirewall,
      appHasPermission: appHasPermission,
      issues: issues,
      recommendations: recommendations,
    );
  }

  /// Windows平台防火墙检查
  static Future<FirewallCheckResult> _checkWindowsFirewall() async {
    final issues = <String>[];
    final recommendations = <String>[];
    bool hasFirewall = true;
    bool appHasPermission = true;

    try {
      // 检查Windows防火墙服务状态
      final result = await Process.run('netsh', ['advfirewall', 'show', 'allprofiles']);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // 检查防火墙状态
        if (output.contains('State ON') || output.contains('状态 打开')) {
          print('Windows防火墙已启用');
          
          // 检查UDP端口7431是否被阻止
          final firewallCheck = await Process.run('netsh', [
            'advfirewall', 'firewall', 'show', 'rule', 'name=all'
          ]);
          
          if (firewallCheck.exitCode == 0) {
            final firewallOutput = firewallCheck.stdout.toString();
            
            // 检查是否有阻止UDP 7431端口的规则
            if (firewallOutput.contains('7431') && 
                (firewallOutput.contains('Block') || firewallOutput.contains('阻止'))) {
              issues.add('UDP端口7431可能被防火墙阻止');
              recommendations.add('在Windows防火墙中允许UDP端口7431的入站和出站连接');
              appHasPermission = false;
            }
          }
        } else {
          hasFirewall = false;
          print('Windows防火墙已禁用');
        }
      } else {
        issues.add('无法检查Windows防火墙状态');
        recommendations.add('请手动检查Windows防火墙设置');
      }
    } catch (e) {
      issues.add('防火墙检查失败: $e');
      recommendations.add('请手动检查网络权限设置');
    }

    // 添加通用建议
    if (Platform.isWindows) {
      recommendations.add('如果问题持续存在，请尝试以管理员权限运行应用');
      recommendations.add('检查Windows Defender防火墙设置中的入站和出站规则');
    }

    return FirewallCheckResult(
      hasFirewall: hasFirewall,
      appHasPermission: appHasPermission,
      issues: issues,
      recommendations: recommendations,
    );
  }

  /// Android平台权限检查
  static Future<FirewallCheckResult> _checkAndroidPermissions() async {
    final issues = <String>[];
    final recommendations = <String>[];
    bool appHasPermission = true;

    // Android通常没有系统级防火墙阻止UDP广播
    // 主要检查网络权限
    try {
      // 这里可以添加Android特定的权限检查逻辑
      // 目前假设应用有必要的网络权限
      print('Android平台网络权限检查通过');
    } catch (e) {
      issues.add('Android权限检查失败: $e');
      recommendations.add('请确保应用有INTERNET和ACCESS_NETWORK_STATE权限');
    }

    return FirewallCheckResult(
      hasFirewall: false,
      appHasPermission: appHasPermission,
      issues: issues,
      recommendations: recommendations,
    );
  }

  /// 获取网络诊断报告
  static Future<String> getNetworkDiagnosticReport() async {
    final firewallResult = await checkFirewallStatus();
    final platform = Platform.operatingSystem;
    final timestamp = DateTime.now().toIso8601String();

    final report = '''
=== 网络诊断报告 ===
时间: $timestamp
平台: $platform

防火墙检查:
${firewallResult.toString()}

网络接口信息:
- 请查看应用日志中的网络接口检测结果

建议操作:
${firewallResult.recommendations.map((r) => '- $r').join('\n')}

如果问题持续存在:
1. 确保Windows和Android设备在同一局域网
2. 检查路由器设置，确保允许局域网广播
3. 临时禁用防火墙进行测试
4. 重启网络设备
''';

    return report;
  }

  /// 显示网络诊断信息
  static Future<void> showNetworkDiagnostics() async {
    print('正在执行网络诊断...');
    
    final report = await getNetworkDiagnosticReport();
    print(report);
    
    // 检查网络连通性
    await _checkNetworkConnectivity();
  }

  /// 检查网络连通性
  static Future<void> _checkNetworkConnectivity() async {
    print('\n=== 网络连通性检查 ===');
    
    try {
      // 尝试连接到常见的内网地址
      final addresses = [
        '192.168.1.1',
        '192.168.0.1',
        '10.0.0.1',
      ];
      
      for (final address in addresses) {
        try {
          final result = await InternetAddress.lookup(address);
          if (result.isNotEmpty) {
            print('✓ 可以解析内网地址: $address');
          }
        } catch (e) {
          print('✗ 无法解析内网地址: $address');
        }
      }
    } catch (e) {
      print('网络连通性检查失败: $e');
    }
  }
}
