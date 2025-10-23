import 'package:flutter/material.dart';

// 状态颜色
class AppStatusColors {
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
}

// 设备品牌颜色
class AppDeviceColors {
  static const Color windowsBlue = Color(0xFF0078D4);
  static const Color androidGreen = Color(0xFF3DDC84);
  static const Color harmonyRed = Color(0xFFFF0000);
  static const Color linuxYellow = Color(0xFFFCC624);
  static const Color macBlack = Color(0xFF000000);
}

// 明暗主题表面容器颜色
class AppSurfaceColors {
  // 浅色主题
  static const Color surfaceContainerLight = Color(0xFFF7F2FA);
  static const Color surfaceContainerHighLight = Color(0xFFF3EDF7);
  static const Color surfaceContainerHighestLight = Color(0xFFECE6F0);
  
  // 深色主题
  static const Color surfaceContainerDark = Color(0xFF211F26);
  static const Color surfaceContainerHighDark = Color(0xFF2B2930);
  static const Color surfaceContainerHighestDark = Color(0xFF36343B);
}

// Extension to add custom semantic colors to ColorScheme
extension CustomColorScheme on ColorScheme {
  Color get success => brightness == Brightness.light
      ? const Color(0xFF4CAF50)
      : const Color(0xFF66BB6A);

  Color get warning => brightness == Brightness.light
      ? const Color(0xFFFF9800)
      : const Color(0xFFFFB74D);

  Color get info => brightness == Brightness.light
      ? const Color(0xFF2196F3)
      : const Color(0xFF64B5F6);

  // Provide surfaceContainer tokens for older Flutter versions that may not have them
  Color get surfaceContainer => brightness == Brightness.light
      ? const Color(0xFFF7F2FA)
      : const Color(0xFF211F26);
  Color get surfaceContainerHigh => brightness == Brightness.light
      ? const Color(0xFFF3EDF7)
      : const Color(0xFF2B2930);
  Color get surfaceContainerHighest => brightness == Brightness.light
      ? const Color(0xFFECE6F0)
      : const Color(0xFF36343B);
}
