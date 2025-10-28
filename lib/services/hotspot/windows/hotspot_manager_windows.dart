import 'dart:io';
import 'dart:convert';
import 'package:yolighttransfer/util/encoding_converter.dart';
import '../base/hotspot_manager.dart';

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
  Future<bool> disconnectFromHotspot() async {
    print('=== Windows断开热点连接 ===');
    
    try {
      final result = await Process.run('netsh', [
        'wlan', 'disconnect'
      ], runInShell: true);
      
      print('断开连接退出码: ${result.exitCode}');
      final disconnectOutput = _decodeOutput(result.stdout);
      final disconnectError = _decodeOutput(result.stderr);
      print('断开连接输出: $disconnectOutput');
      print('断开连接错误: $disconnectError');
      
      if (result.exitCode == 0) {
        print('✅ 断开连接成功');
        return true;
      } else {
        print('❌ 断开连接失败');
        return false;
      }
    } catch (e, stack) {
      print('❌ 断开连接异常: $e');
      print('堆栈: $stack');
      return false;
    }
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
