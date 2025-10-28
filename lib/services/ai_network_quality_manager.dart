// AI网络质量检测状态管理器
// 负责管理网络质量检测的全局状态、弹窗逻辑和用户交互

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/services/network_testing/lan_network_tester.dart';

/// 网络质量检测状态
enum NetworkQualityState {
  idle,           // 空闲状态
  detecting,      // 检测中
  noDevices,      // 无其他设备
  weakNetwork,    // 弱网推荐
  normalNetwork,  // 正常网络
  error,          // 检测错误
}

/// 网络质量检测结果
class NetworkQualityResult {
  final NetworkQualityState state;
  final String message;
  final AIRecommendation? recommendation;
  final DateTime timestamp;

  NetworkQualityResult({
    required this.state,
    required this.message,
    this.recommendation,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkQualityResult(state: $state, message: $message)';
  }
}

/// AI网络质量检测管理器
class AINetworkQualityManager extends ChangeNotifier {
  final AINetworkAdvisor _networkAdvisor;
  final NetworkQualityAnalyzer _networkAnalyzer; // 保留以兼容历史 API 或备用测量
  final LanNetworkTester _lanTester;
  
  NetworkQualityState _currentState = NetworkQualityState.idle;
  NetworkQualityResult? _lastResult;
  DateTime? _lastDetectionTime;
  bool _isDetectionEnabled = true;
  
  // 缓存与节流
  static const Duration _cacheTtl = Duration(seconds: 30);
  
  // 弹窗控制
  bool _shouldShowRecommendation = false;
  DateTime? _lastRecommendationTime;
  static const Duration _recommendationCooldown = Duration(minutes: 30);
  
  // 用户偏好
  DateTime? _lastUserRejection;
  static const Duration _userRejectionCooldown = Duration(minutes: 60);

  AINetworkQualityManager({
    required AINetworkAdvisor networkAdvisor,
    required NetworkQualityAnalyzer networkAnalyzer,
    required LanNetworkTester lanTester,
  })  : _networkAdvisor = networkAdvisor,
        _networkAnalyzer = networkAnalyzer,
        _lanTester = lanTester;

  /// 获取当前状态
  NetworkQualityState get currentState => _currentState;

  /// 获取最后检测结果
  NetworkQualityResult? get lastResult => _lastResult;

  /// 获取最后检测时间
  DateTime? get lastDetectionTime => _lastDetectionTime;

  /// 是否应该显示推荐弹窗
  bool get shouldShowRecommendation => _shouldShowRecommendation;

  /// 是否启用检测
  bool get isDetectionEnabled => _isDetectionEnabled;

  /// 设置检测启用状态
  set isDetectionEnabled(bool enabled) {
    if (_isDetectionEnabled != enabled) {
      _isDetectionEnabled = enabled;
      notifyListeners();
    }
  }

  /// 开始网络质量检测
  Future<NetworkQualityResult> startDetection() async {
    if (!_isDetectionEnabled) {
      return NetworkQualityResult(
        state: NetworkQualityState.idle,
        message: '网络质量检测已禁用',
        timestamp: DateTime.now(),
      );
    }

    // 缓存命中：30s 内直接返回上次结果，避免 UI 抖动
    if (_lastResult != null && _lastDetectionTime != null) {
      final since = DateTime.now().difference(_lastDetectionTime!);
      if (since < _cacheTtl) {
        return _lastResult!;
      }
    }

    _updateState(NetworkQualityState.detecting, '正在检测网络质量...');
    
    try {
      // 主动对等测速，最长 6s
      final metrics = await _lanTester.run().timeout(const Duration(seconds: 6));

      // 转换为统一网络质量结构
      final quality = NetworkQuality(
        bandwidthMbps: metrics.bandwidthMbps,
        packetLossRate: metrics.lossRate,
        avgDelayMs: metrics.avgDelayMs,
        timestamp: DateTime.now(),
      );

      // 基于测得质量做 AI 决策（重用顾问的规则/防抖/偏好逻辑）
      final recommendation = await _networkAdvisor.shouldRecommendHotspotWith(quality);

      // 判断检测结果
      NetworkQualityState state;
      String message;
      
      if (recommendation.shouldRecommendHotspot) {
        state = NetworkQualityState.weakNetwork;
        message = recommendation.reason;
        
        // 检查是否应该显示推荐弹窗
        if (_canShowRecommendation()) {
          _shouldShowRecommendation = true;
          _lastRecommendationTime = DateTime.now();
        }
      } else {
        state = NetworkQualityState.normalNetwork;
        message = '网络质量正常';
      }
      
      final result = NetworkQualityResult(
        state: state,
        message: message,
        recommendation: recommendation,
        timestamp: DateTime.now(),
      );
      
      _lastResult = result;
      _lastDetectionTime = DateTime.now();
      _updateState(state, message);
      
      return result;
    } on NoDevicesException {
      final result = NetworkQualityResult(
        state: NetworkQualityState.noDevices,
        message: '附近无其他开启设备等待检查网络质量中',
        timestamp: DateTime.now(),
      );
      _lastResult = result;
      _lastDetectionTime = DateTime.now();
      _updateState(NetworkQualityState.noDevices, result.message);
      return result;
    } on TimeoutException {
      final result = NetworkQualityResult(
        state: NetworkQualityState.error,
        message: '网络质量检测超时',
        timestamp: DateTime.now(),
      );
      _lastResult = result;
      _lastDetectionTime = DateTime.now();
      _updateState(NetworkQualityState.error, result.message);
      return result;
    } catch (e) {
      final result = NetworkQualityResult(
        state: NetworkQualityState.error,
        message: '网络质量检测失败: $e',
        timestamp: DateTime.now(),
      );
      
      _lastResult = result;
      _lastDetectionTime = DateTime.now();
      _updateState(NetworkQualityState.error, '网络质量检测失败');
      
      return result;
    }
  }

  /// 用户接受热点推荐
  void acceptRecommendation() {
    _shouldShowRecommendation = false;
    _lastUserRejection = null; // 清除用户拒绝记录
    notifyListeners();
  }

  /// 用户拒绝热点推荐
  void rejectRecommendation() {
    _shouldShowRecommendation = false;
    _lastUserRejection = DateTime.now();
    _networkAdvisor.recordUserRejection();
    notifyListeners();
  }

  /// 手动关闭推荐弹窗
  void dismissRecommendation() {
    _shouldShowRecommendation = false;
    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _currentState = NetworkQualityState.idle;
    _lastResult = null;
    _shouldShowRecommendation = false;
    _lastUserRejection = null;
    _lastRecommendationTime = null;
    notifyListeners();
  }

  /// 清空历史记录
  void clearHistory() {
    _networkAdvisor.clearHistory();
    _networkAnalyzer.clearHistory();
    reset();
  }

  /// 检查是否可以显示推荐弹窗
  bool _canShowRecommendation() {
    // 检查用户拒绝冷却期
    if (_lastUserRejection != null) {
      final timeSinceRejection = DateTime.now().difference(_lastUserRejection!);
      if (timeSinceRejection < _userRejectionCooldown) {
        return false;
      }
    }
    
    // 检查推荐冷却期
    if (_lastRecommendationTime != null) {
      final timeSinceLastRecommendation = DateTime.now().difference(_lastRecommendationTime!);
      if (timeSinceLastRecommendation < _recommendationCooldown) {
        return false;
      }
    }
    
    return true;
  }

  /// 更新状态
  void _updateState(NetworkQualityState state, String message) {
    _currentState = state;
    notifyListeners();
  }

  /// 获取用户拒绝冷却剩余时间（秒）
  int? get userRejectionCooldownRemaining {
    if (_lastUserRejection == null) return null;
    
    final now = DateTime.now();
    final timeSinceRejection = now.difference(_lastUserRejection!);
    final remaining = _userRejectionCooldown - timeSinceRejection;
    
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  /// 获取推荐冷却剩余时间（秒）
  int? get recommendationCooldownRemaining {
    if (_lastRecommendationTime == null) return null;
    
    final now = DateTime.now();
    final timeSinceLastRecommendation = now.difference(_lastRecommendationTime!);
    final remaining = _recommendationCooldown - timeSinceLastRecommendation;
    
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }
}
