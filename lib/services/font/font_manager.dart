import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 字体管理服务
class FontManager {
  static const String _miSansFontFamily = 'MiSans';
  static const String _miSansFontPath = 'assets/front/MiSans-Regular.ttf';
  
  static bool _isFontLoaded = false;
  static bool _fontLoadFailed = false;

  /// 预加载字体
  static Future<void> preloadFonts() async {
    if (_isFontLoaded) return;
    
    try {
      // 尝试加载 MiSans 字体
      final fontLoader = FontLoader(_miSansFontFamily);
      fontLoader.addFont(rootBundle.load(_miSansFontPath));
      await fontLoader.load();
      
      _isFontLoaded = true;
      _fontLoadFailed = false;
      print('✅ MiSans 字体加载成功');
    } catch (e) {
      _fontLoadFailed = true;
      print('⚠️ MiSans 字体加载失败: $e');
      print('📝 将使用系统默认字体作为回退');
    }
  }

  /// 获取当前可用的字体族
  static String getAvailableFontFamily() {
    if (_isFontLoaded && !_fontLoadFailed) {
      return _miSansFontFamily;
    }
    
    // 回退到系统默认字体
    // Windows 平台推荐的回退字体
    return _getSystemFallbackFont();
  }

  /// 获取系统回退字体
  static String _getSystemFallbackFont() {
    // 根据平台选择最佳回退字体
    return 'Segoe UI'; // Windows 默认字体
  }

  /// 检查字体是否可用
  static bool isMiSansAvailable() {
    return _isFontLoaded && !_fontLoadFailed;
  }

  /// 获取字体加载状态
  static String getFontStatus() {
    if (_isFontLoaded && !_fontLoadFailed) {
      return 'MiSans 字体已加载';
    } else if (_fontLoadFailed) {
      return 'MiSans 字体加载失败，使用系统字体: ${_getSystemFallbackFont()}';
    } else {
      return '字体未加载';
    }
  }
}
