// 热点管理服务
// 跨平台热点创建、连接管理
// 支持Android、Windows、iOS、macOS、Linux

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yolighttransfer/util/encoding_converter.dart';

/// 热点管理抽象基类
abstract class HotspotManager {
  /// 创建热点
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  });

  /// 停止热点
  Future<bool> stopHotspot();

  /// 连接到热点
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  });

  /// 获取当前连接的热点信息
  Future<({String ssid, double signalStrength})?> getCurrentConnection();

  /// 检查设备是否支持热点
  Future<bool> isHotspotSupported();

  /// 检查热点是否正在运行
  Future<bool> isHotspotRunning();

  /// 获取平台名称
  String get platformName;

  /// 获取实际热点信息（Android 系统自动生成时使用）
  Future<({String ssid, String password})?> getActualHotspotInfo();

  /// 关闭WiFi - 彻底断开所有连接
  Future<bool> disableWifi();
}

/// 热点管理工厂类
class HotspotManagerFactory {
  /// 根据平台创建对应的热点管理器
  static HotspotManager create() {
    if (Platform.isAndroid) {
      return HotspotManagerAndroid();
    } else if (Platform.isWindows) {
      return HotspotManagerWindows();
    } else if (Platform.isIOS) {
      return HotspotManagerIOS();
    } else if (Platform.isMacOS) {
      return HotspotManagerMacOS();
    } else if (Platform.isLinux) {
      return HotspotManagerLinux();
    } else {
      return HotspotManagerUnsupported();
    }
  }
}

/// Android热点管理器
class HotspotManagerAndroid extends HotspotManager {
  static const String _channel = 'com.yolighttransfer/hotspot';
  static const platform = MethodChannel(_channel);

  @override
  String get platformName => 'Android';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      print('=== Android创建热点 ===');
      print('SSID: $ssid');
      print('密码长度: ${password.length}');
      
      final result = await platform.invokeMethod<bool>(
        'startHotspot',
        {
          'ssid': ssid,
          'password': password,
        },
      );
      
      final success = result ?? false;
      if (success) {
        print('✅ 热点创建成功');
      } else {
        print('❌ 热点创建失败');
      }
      return success;
    } on PlatformException catch (e) {
      print('❌ Android创建热点异常: ${e.message}');
      print('错误码: ${e.code}');
      print('详情: ${e.details}');
      
      // 根据错误码提供更友好的错误信息
      switch (e.code) {
        case 'UNSUPPORTED_VERSION':
          print('⚠️ 当前 Android 版本不支持创建自定义热点');
          break;
        case 'INVALID_PARAMS':
          print('⚠️ 参数错误：SSID 或密码不能为空');
          break;
        case 'METHOD_ERROR':
          print('⚠️ 方法调用失败：${e.message}');
          break;
        default:
          print('⚠️ 未知错误：${e.message}');
      }
      
      return false;
    } catch (e) {
      print('❌ Android创建热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> stopHotspot() async {
    try {
      print('=== Android停止热点 ===');
      
      final result = await platform.invokeMethod<bool>('stopHotspot');
      
      final success = result ?? false;
      if (success) {
        print('✅ 热点停止成功');
      } else {
        print('❌ 热点停止失败');
      }
      return success;
    } on PlatformException catch (e) {
      print('❌ Android停止热点异常: ${e.message}');
      print('详情: ${e.details}');
      return false;
    } catch (e) {
      print('❌ Android停止热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      print('=== Android连接热点 ===');
      print('SSID: $ssid');
      print('密码长度: ${password.length}');
      
      final result = await platform.invokeMethod<bool>(
        'connectToWifi',
        {
          'ssid': ssid,
          'password': password,
          'encryptionType': 'WPA2', // 默认使用WPA2加密
        },
      );
      
      final success = result ?? false;
      if (success) {
        print('✅ 热点连接成功');
      } else {
        print('❌ 热点连接失败');
      }
      return success;
    } on PlatformException catch (e) {
      print('❌ Android连接热点异常: ${e.message}');
      print('详情: ${e.details}');
      return false;
    } catch (e) {
      print('❌ Android连接热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> isHotspotSupported() async {
    try {
      print('=== Android检查热点支持 ===');
      
      final result = await platform.invokeMethod<bool>('isHotspotSupported');
      
      final supported = result ?? false;
      print('热点支持: $supported');
      return supported;
    } on PlatformException catch (e) {
      print('❌ Android检查热点支持异常: ${e.message}');
      return true; // 默认支持
    } catch (e) {
      print('❌ Android检查热点支持失败: $e');
      return true; // 默认支持
    }
  }

  @override
  Future<bool> isHotspotRunning() async {
    try {
      print('=== Android检查热点状态 ===');
      
      final result = await platform.invokeMethod<bool>('isHotspotRunning');
      
      final running = result ?? false;
      print('热点运行状态: $running');
      return running;
    } on PlatformException catch (e) {
      print('❌ Android检查热点状态异常: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Android检查热点状态失败: $e');
      return false;
    }
  }


  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== Android获取当前连接信息 ===');
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentConnection',
      );
      
      if (result == null) {
        print('⚠️ 未获取到连接信息');
        return null;
      }
      
      final ssid = result['ssid'] as String?;
      final rawSignalStrength = (result['signalStrength'] as num?)?.toDouble();
      
      print('原始SSID: $ssid');
      print('原始信号强度: $rawSignalStrength dBm');
      
      // 验证连接信息的有效性
      final isValidConnection = _validateConnectionInfo(ssid, rawSignalStrength);
      
      if (isValidConnection && ssid != null && rawSignalStrength != null) {
        // 将信号强度从dBm转换为百分比 (0-1范围)
        // 正常WiFi信号范围：-30dBm (强) 到 -90dBm (弱)
        // 转换为百分比：-30dBm = 1.0, -90dBm = 0.0
        final signalStrength = _convertSignalToPercentage(rawSignalStrength);
        print('✅ 检测到有效的WiFi连接: $ssid, 信号强度: ${(signalStrength * 100).toStringAsFixed(0)}%');
        return (ssid: ssid, signalStrength: signalStrength);
      } else {
        print('⚠️ 未检测到有效的WiFi连接');
        return null;
      }
    } on PlatformException catch (e) {
      print('❌ Android获取连接信息异常: ${e.message}');
      print('详情: ${e.details}');
      return null;
    } catch (e) {
      print('❌ Android获取连接信息失败: $e');
      return null;
    }
  }

  /// 验证连接信息的有效性
  bool _validateConnectionInfo(String? ssid, double? signalStrength) {
    // 检查SSID是否有效
    if (ssid == null || ssid.isEmpty) {
      print('SSID为空或null');
      return false;
    }
    
    // 过滤无效的SSID值
    final invalidSsids = ['<unknown ssid>', 'null', 'unknown'];
    if (invalidSsids.any((invalid) => ssid.toLowerCase().contains(invalid))) {
      print('检测到无效SSID: $ssid');
      return false;
    }
    
    // 检查信号强度是否有效
    if (signalStrength == null) {
      print('信号强度为null');
      return false;
    }
    
    // 正常WiFi信号范围：-30dBm (强) 到 -90dBm (弱)
    // -127dBm 表示没有信号或未连接
    if (signalStrength <= -127 || signalStrength >= 0) {
      print('信号强度无效: $signalStrength dBm');
      return false;
    }
    
    return true;
  }

  /// 将信号强度从dBm转换为百分比 (0-1范围)
  double _convertSignalToPercentage(double signalStrength) {
    // 正常WiFi信号范围：-30dBm (强) 到 -90dBm (弱)
    // 转换为百分比：-30dBm = 1.0, -90dBm = 0.0
    const minSignal = -90.0; // 最弱信号
    const maxSignal = -30.0; // 最强信号
    
    // 确保信号强度在有效范围内
    var clampedSignal = signalStrength.clamp(minSignal, maxSignal);
    
    // 计算百分比
    var percentage = (clampedSignal - minSignal) / (maxSignal - minSignal);
    
    // 确保百分比在0-1范围内
    percentage = percentage.clamp(0.0, 1.0);
    
    print('信号强度转换: $signalStrength dBm -> ${(percentage * 100).toStringAsFixed(0)}%');
    
    return percentage;
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== Android获取实际热点信息 ===');
    try {
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'getActualHotspotInfo',
      );
      
      if (result == null) {
        print('⚠️ 未获取到实际热点信息');
        return null;
      }
      
      final ssid = result['ssid'] as String?;
      final password = result['password'] as String?;
      
      if (ssid != null && password != null) {
        print('✅ 实际热点信息: SSID=$ssid, 密码长度=${password.length}');
        return (ssid: ssid, password: password);
      } else {
        print('⚠️ 未获取到完整的实际热点信息');
        return null;
      }
    } on PlatformException catch (e) {
      print('❌ Android获取实际热点信息异常: ${e.message}');
      print('详情: ${e.details}');
      return null;
    } catch (e) {
      print('❌ Android获取实际热点信息失败: $e');
      return null;
    }
  }

  @override
  Future<bool> disableWifi() async {
    print('=== Android关闭WiFi ===');
    try {
      final result = await platform.invokeMethod<bool>('disableWifi');
      
      final success = result ?? false;
      if (success) {
        print('✅ WiFi关闭成功');
      } else {
        print('❌ WiFi关闭失败');
      }
      return success;
    } on PlatformException catch (e) {
      print('❌ Android关闭WiFi异常: ${e.message}');
      print('详情: ${e.details}');
      return false;
    } catch (e) {
      print('❌ Android关闭WiFi失败: $e');
      return false;
    }
  }
}

/// Windows热点管理器
class HotspotManagerWindows extends HotspotManager {
  @override
  String get platformName => 'Windows';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    print('=== Windows混合方案创建热点 ===');
    print('SSID: $ssid');
    
    // 步骤1：先尝试netsh命令（如果有管理员权限）
    final netshResult = await _tryNetshHotspot(ssid, password);
    if (netshResult) {
      print('✅ netsh方式创建热点成功');
      return true;
    }
    
    // 步骤2：如果netsh失败，跳转到系统设置
    print('⚠️ netsh方式失败，跳转到系统设置');
    final settingsResult = await _openHotspotSettings(ssid, password);
    return settingsResult;
  }

  /// 尝试使用netsh创建热点
  Future<bool> _tryNetshHotspot(String ssid, String password) async {
    try {
      print('尝试使用netsh创建热点...');
      
      // 检查是否支持hostednetwork
      final supportResult = await Process.run('netsh', [
        'wlan', 'show', 'drivers'
      ]);
      
      if (supportResult.exitCode != 0 || 
          !supportResult.stdout.toString().contains('Hosted network supported  : Yes')) {
        print('❌ 设备不支持hostednetwork');
        return false;
      }
      
      // 设置热点参数
      final setResult = await Process.run('netsh', [
        'wlan', 'set', 'hostednetwork',
        'mode=allow', 'ssid=$ssid', 'key=$password'
      ]);
      
      if (setResult.exitCode != 0) {
        print('❌ 设置热点参数失败: ${setResult.stderr}');
        return false;
      }
      
      // 启动热点
      final startResult = await Process.run('netsh', [
        'wlan', 'start', 'hostednetwork'
      ]);
      
      if (startResult.exitCode == 0) {
        print('✅ netsh热点启动成功');
        return true;
      } else {
        print('❌ netsh热点启动失败: ${startResult.stderr}');
        return false;
      }
    } catch (e, stack) {
      print('❌ netsh执行异常: $e');
      print('堆栈: $stack');
      return false;
    }
  }

  /// 跳转到系统热点设置
  Future<bool> _openHotspotSettings(String ssid, String password) async {
    try {
      print('跳转到Windows移动热点设置...');
      
      // 方法1：使用Windows正确的命令语法
      final result1 = await Process.run('cmd', [
        '/c', 'start', 'ms-settings:network-mobilehotspot'
      ]);
      
      // 方法2：备用方案 - 使用控制面板
      if (result1.exitCode != 0) {
        await Process.run('control', ['/name', 'Microsoft.NetworkAndSharingCenter']);
      }
      
      // 显示详细的指导信息
      _showManualHotspotGuide(ssid, password);
      
      return true;
    } catch (e) {
      print('❌ 跳转系统设置失败: $e');
      // 即使跳转失败，也显示手动设置指南
      _showManualHotspotGuide(ssid, password);
      return false;
    }
  }

  /// 显示手动设置指南
  void _showManualHotspotGuide(String ssid, String password) {
    print('''
📱 Windows移动热点手动设置指南：

由于您的设备不支持传统热点功能，请按以下步骤设置：

方法1：Windows设置
1. 按 Win + I 打开设置
2. 进入"网络和 Internet" → "移动热点"
3. 点击"编辑"设置以下信息：
   - 网络名称: $ssid
   - 网络密码: $password
4. 开启"移动热点"开关

方法2：第三方软件
如果以上方法都不行，建议使用：
- Connectify Hotspot
- MyPublicWiFi
- Virtual Router Plus

💡 提示：
- 确保无线网卡驱动程序是最新的
- 某些企业版Windows可能限制热点功能
- 检查防火墙设置是否阻止热点共享
''');
  }

  @override
  Future<bool> stopHotspot() async {
    try {
      final result = await Process.run('netsh', [
        'wlan',
        'stop',
        'hostednetwork',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      print('Windows停止热点失败: $e');
      return false;
    }
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    print('=== Windows连接热点 ===');
    print('SSID: $ssid');
    print('密码长度: ${password.length}');
    print('平台: $platformName');
    
    try {
      // 步骤1：检查网络配置文件是否存在
      print('步骤1：检查网络配置文件...');
      final profileResult = await Process.run('netsh', [
        'wlan', 'show', 'profiles', 'name=$ssid'
      ], runInShell: true);
      
      print('配置文件检查退出码: ${profileResult.exitCode}');
      final profileOutput = _decodeOutput(profileResult.stdout);
      final profileError = _decodeOutput(profileResult.stderr);
      print('配置文件检查输出: $profileOutput');
      print('配置文件检查错误: $profileError');
      
      // 步骤2：如果配置文件不存在，需要先添加
      if (profileResult.exitCode != 0 || !profileOutput.contains(ssid)) {
        print('步骤2：网络配置文件不存在，尝试添加配置文件...');
        
        // 创建XML配置文件
        final profileXml = '''
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$ssid</name>
  <SSIDConfig>
    <SSID>
      <name>$ssid</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>WPA2PSK</authentication>
        <encryption>AES</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>$password</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
''';
        
        // 将配置文件保存到临时文件
        final tempDir = Directory.systemTemp;
        final profileFile = File('${tempDir.path}\\$ssid.xml');
        await profileFile.writeAsString(profileXml);
        
        print('配置文件路径: ${profileFile.path}');
        
        // 添加配置文件
        final addResult = await Process.run('netsh', [
          'wlan', 'add', 'profile', 'filename="${profileFile.path}"'
        ], runInShell: true);
        
        print('添加配置文件退出码: ${addResult.exitCode}');
        final addOutput = _decodeOutput(addResult.stdout);
        final addError = _decodeOutput(addResult.stderr);
        print('添加配置文件输出: $addOutput');
        print('添加配置文件错误: $addError');
        
        // 清理临时文件
        try {
          await profileFile.delete();
        } catch (e) {
          print('清理临时文件失败: $e');
        }
        
        if (addResult.exitCode != 0) {
          print('❌ 添加配置文件失败');
          return false;
        }
        
        print('✅ 配置文件添加成功');
      } else {
        print('✅ 配置文件已存在');
      }
      
      // 步骤3：连接热点
      print('步骤3：连接热点...');
      final connectResult = await Process.run('netsh', [
        'wlan', 'connect', 'name=$ssid'
      ], runInShell: true);
      
      print('连接命令退出码: ${connectResult.exitCode}');
      final connectOutput = _decodeOutput(connectResult.stdout);
      final connectError = _decodeOutput(connectResult.stderr);
      print('连接命令输出: $connectOutput');
      print('连接命令错误: $connectError');
      
      if (connectResult.exitCode == 0) {
        print('✅ 连接命令执行成功');
        
        // 等待连接状态检查
        await Future.delayed(Duration(seconds: 2));
        
        // 检查连接状态
        final statusResult = await Process.run('netsh', [
          'wlan', 'show', 'interfaces'
        ], runInShell: true);
        
        final statusOutput = _decodeOutput(statusResult.stdout);
        print('连接状态检查: $statusOutput');
        
        if (statusResult.exitCode == 0 && 
            statusOutput.contains('SSID') && 
            statusOutput.contains(ssid)) {
          print('✅ 热点连接成功');
          return true;
        } else {
          print('⚠️ 连接命令成功但状态检查失败');
          return true; // 仍然返回true，因为连接命令执行成功
        }
      } else {
        print('❌ 连接命令执行失败');
        return false;
      }
    } catch (e, stack) {
      print('❌ 连接异常: $e');
      print('堆栈: $stack');
      return false;
    }
  }

  /// 解码Windows命令行输出（解决中文乱码问题）
  String _decodeOutput(dynamic output) {
    return EncodingConverter.convertOutput(output);
  }


  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== Windows获取当前连接信息 ===');
    
    try {
      final result = await Process.run('netsh', [
        'wlan', 'show', 'interfaces'
      ], runInShell: true);
      
      if (result.exitCode == 0) {
        final output = _decodeOutput(result.stdout);
        print('接口信息: $output');
        
        // 使用智能解析器解析连接状态
        final connectionStatus = EncodingConverter.parseConnectionStatus(output);
        
        if (connectionStatus.isConnected && connectionStatus.ssid != null) {
          print('✅ 当前连接: ${connectionStatus.ssid}, 信号强度: ${connectionStatus.signalStrength * 100}%');
          return (ssid: connectionStatus.ssid!, signalStrength: connectionStatus.signalStrength);
        } else {
          print('⚠️ 未检测到当前连接');
          return null;
        }
      } else {
        print('❌ 获取连接信息失败');
        return null;
      }
    } catch (e, stack) {
      print('❌ 获取连接信息异常: $e');
      print('堆栈: $stack');
      return null;
    }
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== Windows获取实际热点信息 ===');
    // Windows 不支持获取实际热点信息
    print('⚠️ Windows平台不支持获取实际热点信息');
    return null;
  }

  @override
  Future<bool> disableWifi() async {
    print('=== Windows关闭WiFi ===');
    // Windows 不支持关闭WiFi
    print('⚠️ Windows平台不支持关闭WiFi');
    return false;
  }

  @override
  Future<bool> isHotspotSupported() async {
    try {
      // 检查是否支持hostednetwork
      final result = await Process.run('netsh', [
        'wlan',
        'show',
        'drivers',
      ]);
      
      if (result.exitCode == 0) {
        final output = _decodeOutput(result.stdout);
        return output.contains('Hosted network supported  : Yes');
      }
      return false;
    } catch (e) {
      print('Windows检查热点支持失败: $e');
      return false;
    }
  }

  @override
  Future<bool> isHotspotRunning() async {
    try {
      final result = await Process.run('netsh', [
        'wlan',
        'show',
        'hostednetwork',
      ]);
      
      if (result.exitCode == 0) {
        final output = _decodeOutput(result.stdout);
        return output.contains('Status                 : Started');
      }
      return false;
    } catch (e) {
      print('Windows检查热点状态失败: $e');
      return false;
    }
  }
}

/// iOS热点管理器（功能受限）
class HotspotManagerIOS extends HotspotManager {
  @override
  String get platformName => 'iOS';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    // iOS不允许第三方应用创建热点
    // 只能跳转到系统设置
    print('iOS: 无法创建热点，请跳转到系统设置');
    return false;
  }

  @override
  Future<bool> stopHotspot() async {
    // iOS不允许第三方应用停止热点
    return false;
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    // iOS不允许第三方应用自动连接WiFi
    // 只能跳转到系统设置
    print('iOS: 无法自动连接热点，请跳转到系统设置');
    return false;
  }

  @override
  Future<bool> isHotspotSupported() async {
    // iOS设备都支持热点，但第三方应用无法管理
    return true;
  }

  @override
  Future<bool> isHotspotRunning() async {
    // iOS无法检测热点状态
    return false;
  }


  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== iOS获取当前连接信息 ===');
    // iOS无法获取连接信息
    return null;
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== iOS获取实际热点信息 ===');
    // iOS不支持获取实际热点信息
    print('⚠️ iOS平台不支持获取实际热点信息');
    return null;
  }

  @override
  Future<bool> disableWifi() async {
    print('=== iOS关闭WiFi ===');
    // iOS不允许第三方应用关闭WiFi
    print('⚠️ iOS平台不支持关闭WiFi');
    return false;
  }
}

/// macOS热点管理器（功能受限）
class HotspotManagerMacOS extends HotspotManager {
  @override
  String get platformName => 'macOS';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    // macOS创建热点需要系统权限
    print('macOS: 创建热点需要系统权限');
    return false;
  }

  @override
  Future<bool> stopHotspot() async {
    return false;
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    // macOS连接热点需要系统权限
    print('macOS: 连接热点需要系统权限');
    return false;
  }

  @override
  Future<bool> isHotspotSupported() async {
    return true;
  }

  @override
  Future<bool> isHotspotRunning() async {
    return false;
  }

  @override
  Future<bool> disconnectFromHotspot() async {
    print('=== macOS断开热点连接 ===');
    // macOS不允许第三方应用断开连接
    print('macOS: 无法断开连接，请跳转到系统设置');
    return false;
  }

  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== macOS获取当前连接信息 ===');
    // macOS无法获取连接信息
    return null;
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== macOS获取实际热点信息 ===');
    // macOS不支持获取实际热点信息
    print('⚠️ macOS平台不支持获取实际热点信息');
    return null;
  }

  @override
  Future<bool> disableWifi() async {
    print('=== macOS关闭WiFi ===');
    // macOS不允许第三方应用关闭WiFi
    print('⚠️ macOS平台不支持关闭WiFi');
    return false;
  }
}

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

  @override
  Future<bool> disableWifi() async {
    print('=== Linux关闭WiFi ===');
    // Linux 不支持关闭WiFi
    print('⚠️ Linux平台不支持关闭WiFi');
    return false;
  }
}

/// 不支持平台的热点管理器
class HotspotManagerUnsupported extends HotspotManager {
  @override
  String get platformName => 'Unsupported';

  @override
  Future<bool> createHotspot({
    required String ssid,
    required String password,
  }) async {
    print('当前平台不支持热点创建');
    return false;
  }

  @override
  Future<bool> stopHotspot() async {
    return false;
  }

  @override
  Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    print('当前平台不支持热点连接');
    return false;
  }

  @override
  Future<bool> isHotspotSupported() async {
    return false;
  }

  @override
  Future<bool> isHotspotRunning() async {
    return false;
  }

  @override
  Future<bool> disconnectFromHotspot() async {
    print('=== Unsupported断开热点连接 ===');
    print('当前平台不支持断开连接');
    return false;
  }

  @override
  Future<({String ssid, double signalStrength})?> getCurrentConnection() async {
    print('=== Unsupported获取当前连接信息 ===');
    print('当前平台不支持获取连接信息');
    return null;
  }

  @override
  Future<({String ssid, String password})?> getActualHotspotInfo() async {
    print('=== Unsupported获取实际热点信息 ===');
    print('当前平台不支持获取实际热点信息');
    return null;
  }

  @override
  Future<bool> disableWifi() async {
    print('=== Unsupported关闭WiFi ===');
    print('当前平台不支持关闭WiFi');
    return false;
  }
}
