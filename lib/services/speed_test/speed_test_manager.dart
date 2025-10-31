import 'dart:async';
import 'dart:collection';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/speed_test/speed_test_service.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';

/// 测速管理器状态
enum SpeedTestManagerState {
  idle,           // 空闲
  discovering,    // 设备发现中
  testing,        // 测速中
  analyzing,      // 分析中
  completed,      // 完成
  error,          // 错误
}

/// 测速历史记录
class SpeedTestHistory {
  final String testId;
  final DateTime timestamp;
  final SpeedTestResult result;
  final Map<String, dynamic> metadata;

  SpeedTestHistory({
    required this.testId,
    required this.timestamp,
    required this.result,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'timestamp': timestamp.toIso8601String(),
      'result': result.toJson(),
      'metadata': metadata,
    };
  }
}

/// 快速HTTP测速管理器
/// 负责协调测速流程、管理测速会话、存储历史记录
class SpeedTestManager {
  final TransferLogManager _logManager;
  final TransferTaskManager? _taskManager;
  final SpeedTestService _speedTestService;

  // 测速状态
  SpeedTestManagerState _state = SpeedTestManagerState.idle;
  
  // 活跃测速会话
  final Map<String, SpeedTestResult> _activeTests = {};
  
  // 测速历史记录
  final List<SpeedTestHistory> _history = [];
  
  // 最大历史记录数
  static const int _maxHistorySize = 100;

  // 回调函数
  void Function(SpeedTestManagerState state)? onStateChanged;
  void Function(String testId, SpeedTestResult result)? onTestStarted;
  void Function(String testId, SpeedTestResult result)? onTestCompleted;
  void Function(String testId, String error)? onTestError;
  void Function(SpeedTestHistory history)? onHistoryAdded;

  SpeedTestManager({
    required TransferLogManager logManager,
    TransferTaskManager? taskManager,
    SpeedTestService? speedTestService,
  })  : _logManager = logManager,
        _taskManager = taskManager,
        _speedTestService = speedTestService ?? SpeedTestService(
          logManager: logManager,
          taskManager: taskManager,
        ) {
    // 设置测速服务回调
    _setupServiceCallbacks();
  }

  /// 获取当前状态
  SpeedTestManagerState get state => _state;

  /// 获取活跃测速会话
  List<String> get activeTests => _activeTests.keys.toList();

  /// 获取测速历史记录
  List<SpeedTestHistory> get history => UnmodifiableListView(_history);

  /// 启动快速测速
  Future<SpeedTestResult?> startSpeedTest({
    required DiscoveredDevice targetDevice,
    String? testId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_state == SpeedTestManagerState.testing) {
      _log('⚠️ 测速管理器正忙，无法启动新测速');
      return null;
    }

    _setState(SpeedTestManagerState.testing);

    try {
      _log('🚀 启动测速: ${targetDevice.name}');

      // 启动测速服务
      final result = await _speedTestService.startSpeedTest(
        targetDevice: targetDevice,
        testId: testId,
      );

      if (result != null) {
        _activeTests[result.testId] = result;
        onTestStarted?.call(result.testId, result);
        _log('✅ 测速启动成功: ${result.testId}');
      } else {
        _setState(SpeedTestManagerState.error);
        _log('❌ 测速启动失败');
      }

      return result;

    } catch (e) {
      _setState(SpeedTestManagerState.error);
      _log('❌ 测速启动异常: $e');
      return null;
    }
  }

  /// 批量测速
  Future<List<SpeedTestResult>> batchSpeedTest({
    required List<DiscoveredDevice> targetDevices,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final results = <SpeedTestResult>[];
    
    for (int i = 0; i < targetDevices.length; i++) {
      final device = targetDevices[i];
      
      _log('📊 批量测速进度: ${i + 1}/${targetDevices.length} - ${device.name}');
      
      final result = await startSpeedTest(targetDevice: device);
      if (result != null) {
        results.add(result);
      }
      
      // 等待间隔，避免网络拥塞
      if (i < targetDevices.length - 1) {
        await Future.delayed(interval);
      }
    }
    
    return results;
  }

  /// 取消测速
  void cancelSpeedTest(String testId) {
    _speedTestService.cancelSpeedTest(testId);
    _activeTests.remove(testId);
    
    if (_activeTests.isEmpty) {
      _setState(SpeedTestManagerState.idle);
    }
    
    _log('⏹️ 测速已取消: $testId');
  }

  /// 取消所有测速
  void cancelAllTests() {
    for (final testId in _activeTests.keys.toList()) {
      cancelSpeedTest(testId);
    }
    
    _setState(SpeedTestManagerState.idle);
    _log('⏹️ 所有测速已取消');
  }

  /// 获取测速结果
  SpeedTestResult? getTestResult(String testId) {
    return _activeTests[testId];
  }

  /// 获取设备测速历史
  List<SpeedTestHistory> getDeviceHistory(String deviceId) {
    return _history
        .where((history) => history.result.targetDevice.id == deviceId)
        .toList();
  }

  /// 获取最近测速结果
  SpeedTestHistory? getLatestTest() {
    if (_history.isEmpty) return null;
    
    // 按时间戳降序排序，返回最新的
    _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _history.first;
  }

  /// 获取设备平均性能
  Map<String, double> getDeviceAveragePerformance(String deviceId) {
    final deviceHistory = getDeviceHistory(deviceId);
    
    if (deviceHistory.isEmpty) {
      return {
        'bandwidth': 0.0,
        'delay': 0.0,
        'loss': 0.0,
        'quality': 0.0,
      };
    }

    final bandwidthSum = deviceHistory.map((h) => h.result.bandwidthMbps).reduce((a, b) => a + b);
    final delaySum = deviceHistory.map((h) => h.result.avgDelayMs).reduce((a, b) => a + b);
    final lossSum = deviceHistory.map((h) => h.result.packetLossRate).reduce((a, b) => a + b);
    final qualitySum = deviceHistory.map((h) => h.result.qualityScore).reduce((a, b) => a + b);

    return {
      'bandwidth': bandwidthSum / deviceHistory.length,
      'delay': delaySum / deviceHistory.length,
      'loss': lossSum / deviceHistory.length,
      'quality': qualitySum / deviceHistory.length,
    };
  }

  /// 清理历史记录
  void clearHistory() {
    _history.clear();
    _log('🗑️ 测速历史已清理');
  }

  /// 导出测速报告
  Map<String, dynamic> exportReport() {
    return {
      'exportTime': DateTime.now().toIso8601String(),
      'totalTests': _history.length,
      'activeTests': _activeTests.length,
      'history': _history.map((h) => h.toJson()).toList(),
      'summary': _generateSummary(),
    };
  }

  /// 设置测速服务回调
  void _setupServiceCallbacks() {
    _speedTestService.onProgress = (testId, phase, progress, status, metrics) {
      _log('📊 测速进度: $testId - $phase - ${(progress * 100).toStringAsFixed(1)}%');
      
      // 更新状态
      if (phase == '数据分析') {
        _setState(SpeedTestManagerState.analyzing);
      }
    };

    _speedTestService.onComplete = (result) {
      _handleTestComplete(result);
    };

    _speedTestService.onError = (testId, error) {
      _handleTestError(testId, error);
    };
  }

  /// 处理测速完成
  void _handleTestComplete(SpeedTestResult result) {
    _activeTests.remove(result.testId);
    
    // 添加到历史记录
    final history = SpeedTestHistory(
      testId: result.testId,
      timestamp: result.timestamp,
      result: result,
      metadata: {
        'deviceName': result.targetDevice.name,
        'deviceIp': result.targetDevice.ip,
        'testDuration': DateTime.now().difference(result.timestamp).inSeconds,
      },
    );
    
    _addToHistory(history);
    
    // 更新状态
    if (_activeTests.isEmpty) {
      _setState(SpeedTestManagerState.completed);
      
      // 短暂延迟后回到空闲状态
      Future.delayed(Duration(seconds: 2), () {
        if (_activeTests.isEmpty) {
          _setState(SpeedTestManagerState.idle);
        }
      });
    }
    
    onTestCompleted?.call(result.testId, result);
    _log('✅ 测速完成: ${result.testId} - ${SpeedTestService.formatBandwidth(result.bandwidthMbps)}');
  }

  /// 处理测速错误
  void _handleTestError(String testId, String error) {
    _activeTests.remove(testId);
    
    // 更新状态
    if (_activeTests.isEmpty) {
      _setState(SpeedTestManagerState.error);
      
      // 短暂延迟后回到空闲状态
      Future.delayed(Duration(seconds: 2), () {
        if (_activeTests.isEmpty) {
          _setState(SpeedTestManagerState.idle);
        }
      });
    }
    
    onTestError?.call(testId, error);
    _log('❌ 测速错误: $testId - $error');
  }

  /// 添加到历史记录
  void _addToHistory(SpeedTestHistory history) {
    _history.add(history);
    
    // 限制历史记录大小
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
    
    onHistoryAdded?.call(history);
  }

  /// 生成摘要报告
  Map<String, dynamic> _generateSummary() {
    if (_history.isEmpty) {
      return {
        'averageBandwidth': 0.0,
        'averageDelay': 0.0,
        'averageLoss': 0.0,
        'averageQuality': 0.0,
        'totalTests': 0,
        'successRate': 0.0,
      };
    }

    final bandwidthSum = _history.map((h) => h.result.bandwidthMbps).reduce((a, b) => a + b);
    final delaySum = _history.map((h) => h.result.avgDelayMs).reduce((a, b) => a + b);
    final lossSum = _history.map((h) => h.result.packetLossRate).reduce((a, b) => a + b);
    final qualitySum = _history.map((h) => h.result.qualityScore).reduce((a, b) => a + b);

    // 计算成功率（基于置信度）
    final successfulTests = _history.where((h) => h.result.confidence > 0.6).length;
    final successRate = (successfulTests / _history.length) * 100;

    return {
      'averageBandwidth': bandwidthSum / _history.length,
      'averageDelay': delaySum / _history.length,
      'averageLoss': lossSum / _history.length,
      'averageQuality': qualitySum / _history.length,
      'totalTests': _history.length,
      'successRate': successRate,
    };
  }

  /// 设置状态
  void _setState(SpeedTestManagerState newState) {
    if (_state != newState) {
      _state = newState;
      _log('🔄 状态变更: ${_state.name}');
      onStateChanged?.call(_state);
    }
  }

  /// 记录日志
  void _log(String message) {
    print('📡 [SpeedTestManager] $message');
  }

  /// 释放资源
  Future<void> dispose() async {
    cancelAllTests();
    await _speedTestService.dispose();
    _log('🗑️ 测速管理器已释放');
  }
}
