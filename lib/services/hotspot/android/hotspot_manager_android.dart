import 'dart:async';
import 'package:flutter/services.dart';
import '../base/hotspot_manager.dart';

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
  Future<bool> disconnectFromHotspot() async {
    print('=== Android断开热点连接 ===');
    try {
      final result = await platform.invokeMethod<bool>('disconnectWifi');
      
      final success = result ?? false;
      if (success) {
        print('✅ 断开连接成功');
      } else {
        print('❌ 断开连接失败');
      }
      return success;
    } on PlatformException catch (e) {
      print('❌ Android断开连接异常: ${e.message}');
      print('详情: ${e.details}');
      return false;
    } catch (e) {
      print('❌ Android断开连接失败: $e');
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
      final signalStrength = (result['signalStrength'] as num?)?.toDouble() ?? 0.0;
      
      if (ssid != null) {
        print('✅ 当前连接: $ssid, 信号强度: ${signalStrength * 100}%');
        return (ssid: ssid, signalStrength: signalStrength);
      } else {
        print('⚠️ 未获取到SSID');
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
}
