import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 生成并持久化伪唯一设备 ID 的工具类。
///
/// 设计动机：
/// - 出于隐私考虑，避免使用平台级硬件标识。
/// - 通过 SharedPreferences 持久化，在应用重启后保持稳定。
/// - 除 shared_preferences 外不依赖其他原生插件。
class DeviceIdUtil {
  static const _prefsKey = 'ylt_device_id_v1';

  /// 返回当前应用安装实例的持久唯一标识。
  static Future<String> getOrCreateId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = _generateUuidV4();
    await prefs.setString(_prefsKey, id);
    return id;
  }

  /// 生成随机的 UUID v4 字符串。
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));

    // 符合 RFC 4122：设置版本与变体位
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // 版本 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // 变体位

    String _hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(_hex).toList(growable: false);
    return '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  /// 与 dart:io 的 Platform.operatingSystem 对齐的人类可读平台名称
  static String deviceOs() {
    if (kIsWeb) return 'web';
    // 为保持本文件的 Web 兼容性，避免在顶层引入 dart:io。
    try {
      // 仅通过 foundation 常量获得近似平台名称。
      return defaultTargetPlatform.name;
    } catch (_) {
      return 'unknown';
    }
  }
}
