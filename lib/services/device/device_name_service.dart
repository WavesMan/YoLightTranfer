import 'dart:io';
import 'package:flutter/foundation.dart';

/// 设备名称服务 - 获取系统可识别的设备名称
class DeviceNameService {
  static Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        return _getWebDeviceName();
      }
      
      if (Platform.isAndroid) {
        return await _getAndroidDeviceName();
      } else if (Platform.isIOS) {
        return await _getIOSDeviceName();
      } else if (Platform.isWindows) {
        return await _getWindowsDeviceName();
      } else if (Platform.isMacOS) {
        return await _getMacOSDeviceName();
      } else if (Platform.isLinux) {
        return await _getLinuxDeviceName();
      } else {
        return _getDefaultDeviceName();
      }
    } catch (e) {
      // 如果获取失败，使用默认名称
      return _getDefaultDeviceName();
    }
  }

  /// Web 平台设备名称
  static String _getWebDeviceName() {
    return 'Web设备';
  }

  /// Android 平台设备名称
  static Future<String> _getAndroidDeviceName() async {
    try {
      // 尝试获取设备型号
      final model = await _getAndroidModel();
      if (model.isNotEmpty && model != 'unknown') {
        return 'Android-$model';
      }
      return 'Android设备';
    } catch (e) {
      return 'Android设备';
    }
  }

  /// iOS 平台设备名称
  static Future<String> _getIOSDeviceName() async {
    try {
      // 在iOS上，我们可以使用设备名称
      return 'iOS设备';
    } catch (e) {
      return 'iOS设备';
    }
  }

  /// Windows 平台设备名称
  static Future<String> _getWindowsDeviceName() async {
    try {
      // 获取计算机名
      final computerName = Platform.environment['COMPUTERNAME'] ?? 
                          Platform.environment['USERNAME'] ?? '';
      if (computerName.isNotEmpty) {
        return 'PC-$computerName';
      }
      return 'Windows设备';
    } catch (e) {
      return 'Windows设备';
    }
  }

  /// macOS 平台设备名称
  static Future<String> _getMacOSDeviceName() async {
    try {
      // 在macOS上，可以获取主机名
      final hostName = await _getHostName();
      if (hostName.isNotEmpty) {
        return 'Mac-$hostName';
      }
      return 'Mac设备';
    } catch (e) {
      return 'Mac设备';
    }
  }

  /// Linux 平台设备名称
  static Future<String> _getLinuxDeviceName() async {
    try {
      // 获取主机名
      final hostName = await _getHostName();
      if (hostName.isNotEmpty) {
        return 'Linux-$hostName';
      }
      return 'Linux设备';
    } catch (e) {
      return 'Linux设备';
    }
  }

  /// 默认设备名称
  static String _getDefaultDeviceName() {
    return 'YoLight设备';
  }

  /// 获取Android设备型号
  static Future<String> _getAndroidModel() async {
    try {
      // 这里可以使用 platform 包来获取更详细的设备信息
      // 目前先返回一个简单的标识
      return '设备';
    } catch (e) {
      return '设备';
    }
  }

  /// 获取主机名
  static Future<String> _getHostName() async {
    try {
      // 在支持 dart:io 的平台获取主机名
      if (!kIsWeb) {
        return Platform.localHostname;
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
