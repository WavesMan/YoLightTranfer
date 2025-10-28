import 'dart:io';
import 'hotspot_manager.dart';
import '../android/hotspot_manager_android.dart';
import '../windows/hotspot_manager_windows.dart';
import '../ios/hotspot_manager_ios.dart';
import '../ios/hotspot_manager_macos.dart';
import '../linux/hotspot_manager_linux.dart';
import '../unsupported/hotspot_manager_unsupported.dart';

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
