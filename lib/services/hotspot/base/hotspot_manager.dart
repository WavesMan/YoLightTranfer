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

  /// 断开当前连接的热点
  Future<bool> disconnectFromHotspot();

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
}
