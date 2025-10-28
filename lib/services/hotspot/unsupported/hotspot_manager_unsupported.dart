import '../base/hotspot_manager.dart';

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
}
