import '../base/hotspot_manager.dart';

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
  Future<bool> disconnectFromHotspot() async {
    print('=== iOS断开热点连接 ===');
    // iOS不允许第三方应用断开连接
    print('iOS: 无法断开连接，请跳转到系统设置');
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
}
