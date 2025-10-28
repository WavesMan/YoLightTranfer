import '../base/hotspot_manager.dart';

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
}
