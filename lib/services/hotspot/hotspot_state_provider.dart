// 热点状态提供者 - 全局状态管理
// 解决热点分享页面状态丢失问题

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_manager.dart';

/// 热点状态提供者
/// 管理热点相关的全局状态，确保页面切换时状态不丢失
class HotspotStateProvider extends ChangeNotifier {
  bool _isHotspotRunning = false;
  String _ssid = '';
  String _password = '';
  String _actualSsid = '';
  String _actualPassword = '';
  bool _isSystemGenerated = false;
  bool _isLoading = false;

  /// 热点是否正在运行
  bool get isHotspotRunning => _isHotspotRunning;

  /// 显示的热点SSID（如果是系统生成的则显示实际SSID）
  String get ssid => _isSystemGenerated ? _actualSsid : _ssid;

  /// 显示的热点密码（如果是系统生成的则显示实际密码）
  String get password => _isSystemGenerated ? _actualPassword : _password;

  /// 实际SSID（系统生成的）
  String get actualSsid => _actualSsid;

  /// 实际密码（系统生成的）
  String get actualPassword => _actualPassword;

  /// 是否是系统生成的热点
  bool get isSystemGenerated => _isSystemGenerated;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 设置热点运行状态
  void setHotspotRunning(bool running) {
    if (_isHotspotRunning != running) {
      _isHotspotRunning = running;
      notifyListeners();
    }
  }

  /// 设置热点凭据
  void setHotspotCredentials({required String ssid, required String password}) {
    _ssid = ssid;
    _password = password;
    notifyListeners();
  }

  /// 设置系统生成的热点信息
  void setSystemGeneratedInfo({required String ssid, required String password}) {
    _actualSsid = ssid;
    _actualPassword = password;
    _isSystemGenerated = true;
    notifyListeners();
  }

  /// 清除系统生成的热点信息
  void clearSystemGeneratedInfo() {
    _actualSsid = '';
    _actualPassword = '';
    _isSystemGenerated = false;
    notifyListeners();
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 重新生成热点凭据
  void regenerateCredentials() {
    // 生成随机SSID和密码
    final random = _generateRandomCredentials();
    _ssid = random.ssid;
    _password = random.password;
    _isSystemGenerated = false;
    notifyListeners();
  }

  /// 恢复热点状态
  /// 查询系统实际热点状态并同步到应用状态
  Future<void> restoreState(HotspotManager hotspotManager) async {
    print('=== 恢复热点状态 ===');
    
    try {
      setLoading(true);
      
      // 查询系统热点状态
      final isRunning = await hotspotManager.isHotspotRunning();
      print('系统热点状态: $isRunning');
      
      if (isRunning) {
        // 如果系统热点正在运行，同步状态
        setHotspotRunning(true);
        
        // 尝试获取实际热点信息（Android平台）
        if (hotspotManager.platformName == 'Android') {
          final actualInfo = await hotspotManager.getActualHotspotInfo();
          if (actualInfo != null) {
            setSystemGeneratedInfo(
              ssid: actualInfo.ssid,
              password: actualInfo.password,
            );
            print('✅ 恢复系统生成的热点信息: SSID=${actualInfo.ssid}');
          }
        }
        
        print('✅ 热点状态恢复成功');
      } else {
        // 如果系统热点未运行，确保应用状态同步
        setHotspotRunning(false);
        clearSystemGeneratedInfo();
        print('✅ 热点状态已同步（未运行）');
      }
    } catch (e, stack) {
      print('❌ 恢复热点状态失败: $e');
      print('堆栈: $stack');
      
      // 恢复失败时，保守处理：假设热点未运行
      setHotspotRunning(false);
      clearSystemGeneratedInfo();
    } finally {
      setLoading(false);
    }
  }

  /// 重置所有状态
  void reset() {
    _isHotspotRunning = false;
    _ssid = '';
    _password = '';
    _actualSsid = '';
    _actualPassword = '';
    _isSystemGenerated = false;
    _isLoading = false;
    notifyListeners();
  }

  /// 生成随机热点凭据
  ({String ssid, String password}) _generateRandomCredentials() {
    final random = _RandomGenerator();
    final ssid = 'YoLight_${random.nextInt(9999)}';
    final password = random.generatePassword(12);
    return (ssid: ssid, password: password);
  }
}

/// 随机凭据生成器
class _RandomGenerator {
  final _random = _Random();

  int nextInt(int max) => _random.nextInt(max);

  String generatePassword(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[nextInt(chars.length)]).join();
  }
}

/// 随机数生成器（避免导入冲突）
class _Random {
  final _random = Random();

  int nextInt(int max) => _random.nextInt(max);
}
