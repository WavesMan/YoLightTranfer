// // 网络连通性测试工具
// // 用于验证Windows和Android设备之间的网络连接
//
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
//
// /// 网络连通性测试结果
// class ConnectivityTestResult {
//   final bool canPing;
//   final bool canResolve;
//   final List<String> reachableAddresses;
//   final List<String> unreachableAddresses;
//   final String? error;
//
//   const ConnectivityTestResult({
//     required this.canPing,
//     required this.canResolve,
//     required this.reachableAddresses,
//     required this.unreachableAddresses,
//     this.error,
//   });
//
//   @override
//   String toString() {
//     return '''
// 网络连通性测试结果:
// - 可以Ping: $canPing
// - 可以解析: $canResolve
// - 可达地址: ${reachableAddresses.isEmpty ? '无' : reachableAddresses.join(', ')}
// - 不可达地址: ${unreachableAddresses.isEmpty ? '无' : unreachableAddresses.join(', ')}
// ${error != null ? '错误: $error' : ''}
// ''';
//   }
// }
//
// /// 网络连通性测试器
// class ConnectivityTester {
//   /// 测试设备间的网络连通性
//   static Future<ConnectivityTestResult> testConnectivity({
//     required String targetIp,
//     int timeoutSeconds = 3,
//   }) async {
//     if (kIsWeb) {
//       return ConnectivityTestResult(
//         canPing: false,
//         canResolve: false,
//         reachableAddresses: [],
//         unreachableAddresses: [],
//         error: 'Web平台不支持网络连通性测试',
//       );
//     }
//
//     final reachableAddresses = <String>[];
//     final unreachableAddresses = <String>[];
//     bool canPing = false;
//     bool canResolve = false;
//
//     try {
//       // 测试DNS解析
//       print('正在测试DNS解析: $targetIp');
//       try {
//         final addresses = await InternetAddress.lookup(targetIp);
//         if (addresses.isNotEmpty) {
//           canResolve = true;
//           print('✓ 可以解析地址: $targetIp -> ${addresses.first.address}');
//         }
//       } catch (e) {
//         print('✗ 无法解析地址: $targetIp - $e');
//       }
//
//       // 测试网络连通性（ping模拟）
//       print('正在测试网络连通性: $targetIp');
//       final result = await _testPing(targetIp, timeoutSeconds);
//       if (result) {
//         canPing = true;
//         reachableAddresses.add(targetIp);
//         print('✓ 可以连接到: $targetIp');
//       } else {
//         unreachableAddresses.add(targetIp);
//         print('✗ 无法连接到: $targetIp');
//       }
//
//       // 测试常见局域网地址
//       await _testCommonLocalAddresses(reachableAddresses, unreachableAddresses);
//
//     } catch (e) {
//       return ConnectivityTestResult(
//         canPing: false,
//         canResolve: false,
//         reachableAddresses: [],
//         unreachableAddresses: [],
//         error: '连通性测试失败: $e',
//       );
//     }
//
//     return ConnectivityTestResult(
//       canPing: canPing,
//       canResolve: canResolve,
//       reachableAddresses: reachableAddresses,
//       unreachableAddresses: unreachableAddresses,
//     );
//   }
//
//   /// 模拟ping测试
//   static Future<bool> _testPing(String targetIp, int timeoutSeconds) async {
//     try {
//       // 尝试建立TCP连接来模拟ping
//       final socket = await Socket.connect(
//         targetIp,
//         7431, // 使用UDP发现端口
//         timeout: Duration(seconds: timeoutSeconds),
//       );
//       socket.destroy();
//       return true;
//     } catch (e) {
//       // 如果TCP连接失败，尝试UDP
//       try {
//         final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
//         socket.close();
//         return true; // 如果能绑定套接字，说明网络基本正常
//       } catch (_) {
//         return false;
//       }
//     }
//   }
//
//   /// 测试常见局域网地址
//   static Future<void> _testCommonLocalAddresses(
//     List<String> reachableAddresses,
//     List<String> unreachableAddresses,
//   ) async {
//     final commonAddresses = [
//       '192.168.1.1',  // 常见路由器地址
//       '192.168.0.1',  // 常见路由器地址
//       '10.0.0.1',     // 常见路由器地址
//       '192.168.1.255', // 广播地址
//       '192.168.0.255', // 广播地址
//     ];
//
//     print('正在测试常见局域网地址...');
//
//     for (final address in commonAddresses) {
//       try {
//         final result = await InternetAddress.lookup(address);
//         if (result.isNotEmpty) {
//           reachableAddresses.add(address);
//           print('✓ 可以解析: $address');
//         }
//       } catch (e) {
//         unreachableAddresses.add(address);
//         print('✗ 无法解析: $address');
//       }
//     }
//   }
//
//   /// 获取网络诊断报告
//   static Future<String> getConnectivityReport(String targetIp) async {
//     final result = await testConnectivity(targetIp: targetIp);
//     final platform = Platform.operatingSystem;
//     final timestamp = DateTime.now().toIso8601String();
//
//     final report = '''
// === 网络连通性诊断报告 ===
// 时间: $timestamp
// 平台: $platform
// 目标IP: $targetIp
//
// ${result.toString()}
//
// 网络状态分析:
// ${_analyzeConnectivity(result)}
//
// 建议操作:
// ${_getConnectivityRecommendations(result)}
// ''';
//
//     return report;
//   }
//
//   /// 分析网络连通性
//   static String _analyzeConnectivity(ConnectivityTestResult result) {
//     if (result.canPing && result.canResolve) {
//       return '- 网络连通性良好，设备间可以正常通信';
//     } else if (result.canResolve && !result.canPing) {
//       return '- DNS解析正常，但网络连接可能被防火墙阻止';
//     } else if (!result.canResolve && result.canPing) {
//       return '- 网络连接正常，但DNS解析有问题';
//     } else {
//       return '- 网络连通性较差，可能存在网络配置问题';
//     }
//   }
//
//   /// 获取连通性建议
//   static String _getConnectivityRecommendations(ConnectivityTestResult result) {
//     final recommendations = <String>[];
//
//     if (!result.canResolve) {
//       recommendations.add('- 检查DNS设置或使用IP地址直接连接');
//     }
//
//     if (!result.canPing) {
//       recommendations.add('- 检查防火墙设置，确保允许UDP端口7431');
//       recommendations.add('- 确认设备在同一局域网段');
//       recommendations.add('- 重启网络设备（路由器/交换机）');
//     }
//
//     if (result.reachableAddresses.isEmpty) {
//       recommendations.add('- 检查网络连接和IP地址配置');
//       recommendations.add('- 尝试使用不同的网络接口');
//     }
//
//     if (recommendations.isEmpty) {
//       return '- 网络连通性正常，无需特殊操作';
//     }
//
//     return recommendations.join('\n');
//   }
//
//   /// 执行完整的网络诊断
//   static Future<void> runFullDiagnostics(String targetIp) async {
//     print('正在执行完整网络诊断...');
//
//     // 测试连通性
//     final connectivityResult = await testConnectivity(targetIp: targetIp);
//     print(connectivityResult.toString());
//
//     // 测试UDP广播
//     await _testUdpBroadcast();
//
//     // 测试网络接口
//     await _testNetworkInterfaces();
//   }
//
//   /// 测试UDP广播功能
//   static Future<void> _testUdpBroadcast() async {
//     print('\n--- UDP广播功能测试 ---');
//
//     try {
//       // 测试监听套接字
//       final listener = await RawDatagramSocket.bind(
//         InternetAddress.anyIPv4,
//         7431,
//         reuseAddress: true,
//         reusePort: !Platform.isWindows,
//       );
//       print('✓ UDP监听套接字绑定成功');
//
//       // 测试广播套接字
//       final broadcaster = await RawDatagramSocket.bind(
//         InternetAddress.anyIPv4,
//         0,
//       );
//       broadcaster.broadcastEnabled = true;
//       print('✓ UDP广播套接字绑定成功');
//
//       // 发送测试广播
//       final testData = utf8.encode('TEST_BROADCAST');
//       final broadcastAddr = InternetAddress('255.255.255.255');
//       final result = broadcaster.send(testData, broadcastAddr, 7431);
//
//       if (result > 0) {
//         print('✓ UDP广播发送成功');
//       } else {
//         print('✗ UDP广播发送失败');
//       }
//
//       broadcaster.close();
//       listener.close();
//
//     } catch (e) {
//       print('✗ UDP广播测试失败: $e');
//     }
//   }
//
//   /// 测试网络接口
//   static Future<void> _testNetworkInterfaces() async {
//     print('\n--- 网络接口测试 ---');
//
//     try {
//       final interfaces = await NetworkInterface.list(
//         includeLoopback: false,
//         includeLinkLocal: false,
//       );
//
//       print('检测到 ${interfaces.length} 个网络接口:');
//       for (final iface in interfaces) {
//         final ipv4Addrs = iface.addresses.where((addr) => addr.type == InternetAddressType.IPv4).toList();
//         if (ipv4Addrs.isNotEmpty) {
//           print('  - ${iface.name}: ${ipv4Addrs.map((a) => a.address).join(', ')}');
//         }
//       }
//
//     } catch (e) {
//       print('✗ 网络接口测试失败: $e');
//     }
//   }
// }
