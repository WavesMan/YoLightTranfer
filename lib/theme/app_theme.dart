import 'package:flutter/material.dart';
import 'app_spacing.dart';
import 'app_border_radius.dart';
import 'app_colors.dart';
import '../services/font/font_manager.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6750A4),
      secondary: Color(0xFF625B71),
      tertiary: Color(0xFF7D5260),
      background: Color(0xE7FFFFFF),
      surface: Color(0xE7FFFFFF),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onBackground: Color(0xFF050404),
      onSurface: Color(0xFF050404),
      error: Color(0xFFF44336),
      onError: Colors.white,
      outline: Color(0xFF79747E),
      surfaceVariant: Color(0xFFF7F2FA),
      onSurfaceVariant: Color(0xFF49454F),
    ),
    fontFamily: FontManager.getAvailableFontFamily(),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6750A4), // 明确的主色调
        foregroundColor: Colors.white, // 白色文字确保对比度
        elevation: 15, // 增强阴影效果
        shadowColor: const Color(0x66000000), // 自定义阴影颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.m),
        ),
        padding: AppSpacing.buttonPadding,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600, // 加粗字体增强可读性
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6750A4), // 使用主色调
        side: const BorderSide(color: Color(0xFF6750A4), width: 1.5), // 明确边框
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.m),
        ),
        padding: AppSpacing.buttonPadding,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD0BCFF),
      secondary: Color(0xFFCCC2DC),
      tertiary: Color(0xFFEFB8C8),
      background: Color(0xFF2C2C35),
      surface: Color(0xFF2C2C35),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onBackground: Color(0xFFE6E1E5),
      onSurface: Color(0xFFE6E1E5),
      error: Color(0xFFF2B8B5),
      onError: Colors.white,
      outline: Color(0xFF938F99),
      surfaceVariant: Color(0xFF211F26),
      onSurfaceVariant: Color(0xFFCAC4D0),
    ),
    fontFamily: FontManager.getAvailableFontFamily(),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD0BCFF), // 深色主题主色调
        foregroundColor: const Color(0xFF141218), // 深色背景上的文字
        elevation: 6,
        shadowColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.m),
        ),
        padding: AppSpacing.buttonPadding,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD0BCFF), // 深色主题主色调
        side: const BorderSide(color: Color(0xFFD0BCFF), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.m),
        ),
        padding: AppSpacing.buttonPadding,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    ),
  );
}
