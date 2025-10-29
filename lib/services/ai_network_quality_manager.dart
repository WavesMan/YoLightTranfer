// AI网络质量检测状态管理器
// 负责管理网络质量检测的全局状态、弹窗逻辑和用户交互

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/services/network_testing/lan_network_tester.dart';
import 'package:yolighttransfer/services/network_data_collector.dart';
import 'package:yolighttransfer/services/data_upload_service.dart';

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

  // 数据收集相关
  NetworkDataCollector? _dataCollector;
  DataUploadService? _uploadService;
  bool _isDataCollectionEnabled = false;

  AINetworkQualityManager({
    required AINetworkAdvisor networkAdvisor,
    required NetworkQualityAnalyzer networkAnalyzer,
    required LanNetworkTester lanTester,
    NetworkDataCollector? dataCollector,
    DataUploadService? uploadService,
  })  : _networkAdvisor = networkAdvisor,
        _networkAnalyzer = networkAnalyzer,
        _lanTester = lanTester,
        _dataCollector = dataCollector,
        _uploadService = uploadService;

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
      
      // 收集数据样本（异步执行，不阻塞检测流程）
      _collectNetworkDataSample(
        quality: quality,
        recommendation: recommendation,
        userAccepted: false, // 此时用户尚未做出选择
      );
      
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
    
    // 收集用户接受推荐的数据样本
    if (_lastResult?.recommendation != null) {
      _collectNetworkDataSample(
        quality: _lastResult!.recommendation!.networkQuality,
        recommendation: _lastResult!.recommendation,
        userAccepted: true,
      );
    }
  }

  /// 用户拒绝热点推荐
  void rejectRecommendation() {
    _shouldShowRecommendation = false;
    _lastUserRejection = DateTime.now();
    _networkAdvisor.recordUserRejection();
    notifyListeners();
    
    // 收集用户拒绝推荐的数据样本
    if (_lastResult?.recommendation != null) {
      _collectNetworkDataSample(
        quality: _lastResult!.recommendation!.networkQuality,
        recommendation: _lastResult!.recommendation,
        userAccepted: false,
      );
    }
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

  // ==================== 数据收集相关方法 ====================

  /// 是否启用数据收集
  bool get isDataCollectionEnabled => _isDataCollectionEnabled;

  /// 设置数据收集启用状态
  set isDataCollectionEnabled(bool enabled) {
    if (_isDataCollectionEnabled != enabled) {
      _isDataCollectionEnabled = enabled;
      
      if (_dataCollector != null) {
        final currentConfig = _dataCollector!.config;
        final newConfig = DataCollectionConfig(
          enabled: enabled,
          apiEndpoint: currentConfig.apiEndpoint,
          batchSize: currentConfig.batchSize,
          uploadInterval: currentConfig.uploadInterval,
          includeLocation: currentConfig.includeLocation,
          anonymizeData: currentConfig.anonymizeData,
        );
        _dataCollector!.updateConfig(newConfig);
      }
      
      notifyListeners();
    }
  }

  /// 初始化数据收集会话
  void startDataCollectionSession() {
    if (_dataCollector != null && _isDataCollectionEnabled) {
      _dataCollector!.startSession();
      print('📊 数据收集会话已启动');
    }
  }

  /// 收集网络数据样本（在检测过程中调用）
  Future<void> _collectNetworkDataSample({
    required NetworkQuality quality,
    required AIRecommendation? recommendation,
    required bool userAccepted,
  }) async {
    if (_dataCollector == null || !_isDataCollectionEnabled) {
      return;
    }

    try {
      await _dataCollector!.collectSample(
        includeAIDecision: recommendation != null,
        userAccepted: userAccepted,
      );
    } catch (e) {
      print('❌ 数据收集失败: $e');
    }
  }

  /// 手动触发数据上传
  Future<bool> triggerDataUpload() async {
    if (_uploadService != null && _isDataCollectionEnabled) {
      return await _uploadService!.triggerUpload();
    }
    return false;
  }

  /// 获取数据收集统计信息
  Map<String, dynamic> getDataCollectionStats() {
    if (_dataCollector == null) {
      return {
        'enabled': false,
        'pending_samples': 0,
        'failed_samples': 0,
        'total_collected': 0,
      };
    }

    return _dataCollector!.getStats();
  }

  /// 获取数据上传统计信息
  Map<String, dynamic> getDataUploadStats() {
    if (_uploadService == null) {
      return {
        'enabled': false,
        'current_status': 'idle',
        'total_uploads': 0,
        'successful_uploads': 0,
        'failed_uploads': 0,
        'total_samples': 0,
      };
    }

    final stats = _uploadService!.getCurrentStats();
    return {
      'enabled': _isDataCollectionEnabled,
      'current_status': _uploadService!.currentStatus.toString(),
      'total_uploads': stats.totalUploads,
      'successful_uploads': stats.successfulUploads,
      'failed_uploads': stats.failedUploads,
      'total_samples': stats.totalSamples,
      'last_upload_time': stats.lastUploadTime.toIso8601String(),
    };
  }

  /// 更新数据收集配置
  void updateDataCollectionConfig(DataCollectionConfig config) {
    if (_dataCollector != null) {
      _dataCollector!.updateConfig(config);
      _isDataCollectionEnabled = config.enabled;
      notifyListeners();
    }
  }

  /// 获取当前数据收集配置
  DataCollectionConfig? getDataCollectionConfig() {
    return _dataCollector?.config;
  }

  /// 清空所有收集的数据
  void clearCollectedData() {
    _dataCollector?.clearAllData();
    print('🗑️ 已清空所有收集的数据');
  }

  /// 结束数据收集会话
  void endDataCollectionSession() {
    _dataCollector?.endSession();
    print('📊 数据收集会话已结束');
  }

  /// 重试失败的数据上传
  Future<void> retryFailedDataUploads() async {
    if (_dataCollector != null && _isDataCollectionEnabled) {
      await _dataCollector!.retryFailedUploads();
    }
  }

  /// 设置数据收集器
  void setDataCollector(NetworkDataCollector collector) {
    _dataCollector = collector;
    _isDataCollectionEnabled = collector.config.enabled;
    notifyListeners();
  }

  /// 设置数据上传服务
  void setUploadService(DataUploadService service) {
    _uploadService = service;
    notifyListeners();
  }

  /// 获取数据上传进度流
  Stream<UploadProgress>? getDataUploadProgress() {
    return _uploadService?.uploadProgress;
  }
}
