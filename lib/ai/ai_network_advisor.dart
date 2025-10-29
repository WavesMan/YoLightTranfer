// AI模块：网络智能顾问
// 基于规则引擎的微AI模型，负责弱网识别与热点推荐
// 支持场景切换、动态阈值、防抖机制

import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/ai/tflite_network_evaluator.dart';
import 'package:yolighttransfer/services/network_testing/gateway_bandwidth_tester.dart';

/// AI决策场景类型
enum AIScene {
  general,       // 通用场景
  manufacturing, // 制造车间场景
  education,     // 高校实验室场景
}

/// AI推荐结果
class AIRecommendation {
  final bool shouldRecommendHotspot; // 是否推荐开启热点
  final String reason;               // 推荐原因
  final NetworkQuality networkQuality; // 网络质量数据
  final DateTime timestamp;          // 决策时间

  AIRecommendation({
    required this.shouldRecommendHotspot,
    required this.reason,
    required this.networkQuality,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AIRecommendation(recommend: $shouldRecommendHotspot, reason: $reason)';
  }
}

/// 网络智能顾问
class AINetworkAdvisor extends ChangeNotifier {
  final NetworkQualityAnalyzer _networkAnalyzer;
  final AppConfigService _configService;
  final TFLiteNetworkEvaluator _tfliteEvaluator;
  
  AIScene _currentScene = AIScene.general;
  final List<bool> _weakNetworkHistory = []; // 弱网历史记录（防抖）
  static const int _debounceCount = 3;       // 连续3次弱网才推荐
  
  // 用户偏好记忆
  DateTime? _lastUserRejection;              // 上次用户拒绝时间
  static const Duration _rejectionCooldown = Duration(minutes: 30); // 30分钟冷却

  AINetworkAdvisor({
    required NetworkQualityAnalyzer networkAnalyzer,
    required AppConfigService configService,
    TFLiteNetworkEvaluator? tfliteEvaluator,
    AIScene initialScene = AIScene.general,
  })  : _networkAnalyzer = networkAnalyzer,
        _configService = configService,
        _tfliteEvaluator = tfliteEvaluator ?? TFLiteNetworkEvaluator(),
        _currentScene = initialScene {
    // 异步加载 TFLite 模型
    _initializeTFLiteModel();
  }

  /// 异步初始化 TFLite 模型
  void _initializeTFLiteModel() async {
    try {
      await _tfliteEvaluator.loadModel();
    } catch (e) {
      print('⚠️ TFLite 模型初始化失败: $e');
    }
  }

  /// 更新场景类型
  void updateScene(AIScene scene) {
    if (_currentScene != scene) {
      _currentScene = scene;
      notifyListeners();
    }
  }

  /// 获取当前场景
  AIScene get currentScene => _currentScene;

  /// 核心AI决策：是否推荐开启热点
  Future<AIRecommendation> shouldRecommendHotspot() async {
    // 1. 检查用户偏好冷却
    if (_isInRejectionCooldown()) {
      return AIRecommendation(
        shouldRecommendHotspot: false,
        reason: '用户近期已拒绝推荐，冷却中',
        networkQuality: NetworkQuality(
          bandwidthMbps: 0,
          packetLossRate: 0,
          avgDelayMs: 0,
          timestamp: DateTime.now(),
        ),
        timestamp: DateTime.now(),
      );
    }

    // 2. 获取最新网络质量指标
    final networkQuality = await _networkAnalyzer.measureNetworkQuality();

    // 3. 根据场景动态调整弱网阈值
    final bandwidthThreshold = _getBandwidthThresholdByScene();
    final isWeakNetwork = _isWeakNetwork(networkQuality, bandwidthThreshold);

    // 4. 更新弱网历史记录（防抖机制）
    _updateWeakNetworkHistory(isWeakNetwork);

    // 5. 综合决策
    final shouldRecommend = _shouldRecommendBasedOnHistory();

    // 6. 生成推荐原因
    final reason = _generateRecommendationReason(
      shouldRecommend,
      networkQuality,
      bandwidthThreshold,
    );

    return AIRecommendation(
      shouldRecommendHotspot: shouldRecommend,
      reason: reason,
      networkQuality: networkQuality,
      timestamp: DateTime.now(),
    );
  }

  /// 使用外部测得的网络质量进行决策（不再触发新一轮测量）
  Future<AIRecommendation> shouldRecommendHotspotWith(NetworkQuality networkQuality) async {
    // 1. 检查用户偏好冷却
    if (_isInRejectionCooldown()) {
      return AIRecommendation(
        shouldRecommendHotspot: false,
        reason: '用户近期已拒绝推荐，冷却中',
        networkQuality: networkQuality,
        timestamp: DateTime.now(),
      );
    }

    // 2. 尝试使用 TFLite 模型进行推理
    final tfliteResult = await _tryTFLiteInference(networkQuality);
    
    // 3. 如果 TFLite 推理成功且置信度高，使用 TFLite 结果
    if (tfliteResult != null && tfliteResult.confidence >= _tfliteEvaluator.confidenceThreshold) {
      print('🧠 使用 TFLite 推理结果 (置信度: ${tfliteResult.confidence.toStringAsFixed(2)})');
      
      // 更新弱网历史记录（基于 TFLite 结果）
      _updateWeakNetworkHistory(tfliteResult.shouldRecommendHotspot);
      
      // 综合决策（基于历史记录）
      final shouldRecommend = _shouldRecommendBasedOnHistory();
      
      // 生成推荐原因
      final reason = _generateRecommendationReasonWithTFLite(
        shouldRecommend,
        networkQuality,
        tfliteResult,
      );
      
      return AIRecommendation(
        shouldRecommendHotspot: shouldRecommend,
        reason: reason,
        networkQuality: networkQuality,
        timestamp: DateTime.now(),
      );
    }
    
    // 4. 如果 TFLite 不可用或置信度低，回退到规则引擎
    print('🔬 回退到规则引擎决策');
    
    // 根据场景动态调整弱网阈值
    final bandwidthThreshold = _getBandwidthThresholdByScene();
    final isWeakNetwork = _isWeakNetwork(networkQuality, bandwidthThreshold);

    // 更新弱网历史记录（防抖机制）
    _updateWeakNetworkHistory(isWeakNetwork);

    // 综合决策
    final shouldRecommend = _shouldRecommendBasedOnHistory();

    // 生成推荐原因
    final reason = _generateRecommendationReason(
      shouldRecommend,
      networkQuality,
      bandwidthThreshold,
    );

    return AIRecommendation(
      shouldRecommendHotspot: shouldRecommend,
      reason: reason,
      networkQuality: networkQuality,
      timestamp: DateTime.now(),
    );
  }

  /// 记录用户拒绝推荐
  void recordUserRejection() {
    _lastUserRejection = DateTime.now();
    notifyListeners();
  }

  /// 清除用户拒绝记录
  void clearUserRejection() {
    _lastUserRejection = null;
    notifyListeners();
  }

  /// 检查是否在用户拒绝冷却期内
  bool _isInRejectionCooldown() {
    if (_lastUserRejection == null) return false;
    
    final now = DateTime.now();
    final timeSinceRejection = now.difference(_lastUserRejection!);
    return timeSinceRejection < _rejectionCooldown;
  }

  /// 判断是否为弱网
  bool _isWeakNetwork(NetworkQuality quality, double bandwidthThreshold) {
    return quality.bandwidthMbps < bandwidthThreshold &&
           quality.packetLossRate > 5.0 &&
           quality.avgDelayMs > 100.0;
  }

  /// 根据场景获取带宽阈值（Mbps）
  double _getBandwidthThresholdByScene() {
    // 优先从配置文件中读取，否则使用默认值
    final configKey = 'ai_${_currentScene.name}_bandwidth_threshold';
    final configValue = _configService.get<double>(configKey);
    
    if (configValue != null) {
      return configValue;
    }

    // 默认阈值
    switch (_currentScene) {
      case AIScene.manufacturing: // 制造车间场景（阈值更低，更早触发推荐）
        return 0.8;
      case AIScene.education:     // 高校实验室场景（阈值稍高）
        return 1.2;
      case AIScene.general:       // 通用场景
      default:
        return 1.0;
    }
  }

  /// 更新弱网历史记录（防抖机制）
  void _updateWeakNetworkHistory(bool isWeakNetwork) {
    _weakNetworkHistory.add(isWeakNetwork);
    
    // 保持历史记录大小
    if (_weakNetworkHistory.length > _debounceCount) {
      _weakNetworkHistory.removeAt(0);
    }
  }

  /// 基于历史记录判断是否推荐（防抖）
  bool _shouldRecommendBasedOnHistory() {
    if (_weakNetworkHistory.length < _debounceCount) {
      return false; // 历史记录不足，不推荐
    }

    // 检查是否连续多次检测到弱网
    final recentWeakNetworks = _weakNetworkHistory.take(_debounceCount);
    return recentWeakNetworks.every((isWeak) => isWeak);
  }

  /// 生成推荐原因
  String _generateRecommendationReason(
    bool shouldRecommend,
    NetworkQuality quality,
    double bandwidthThreshold,
  ) {
    if (!shouldRecommend) {
      if (_isInRejectionCooldown()) {
        return '用户近期已拒绝推荐';
      }
      
      if (_weakNetworkHistory.length < _debounceCount) {
        return '网络质量检测中...';
      }
      
      final weakCount = _weakNetworkHistory.where((isWeak) => isWeak).length;
      if (weakCount < _debounceCount) {
        return '网络质量不稳定，需连续检测';
      }
      
      return '网络质量正常';
    }

    // 推荐原因
    final reasons = <String>[];
    
    if (quality.bandwidthMbps < bandwidthThreshold) {
      reasons.add('带宽过低(${quality.bandwidthMbps.toStringAsFixed(2)}Mbps < ${bandwidthThreshold}Mbps)');
    }
    
    if (quality.packetLossRate > 5.0) {
      reasons.add('丢包率过高(${quality.packetLossRate.toStringAsFixed(2)}% > 5%)');
    }
    
    if (quality.avgDelayMs > 100.0) {
      reasons.add('延迟过高(${quality.avgDelayMs.toStringAsFixed(0)}ms > 100ms)');
    }

    return '弱网环境：${reasons.join("，")}';
  }

  /// 获取弱网历史记录（用于调试）
  List<bool> get weakNetworkHistory => List.unmodifiable(_weakNetworkHistory);

  /// 获取用户拒绝信息
  DateTime? get lastUserRejection => _lastUserRejection;

  /// 获取冷却剩余时间（秒）
  int? get rejectionCooldownRemaining {
    if (_lastUserRejection == null) return null;
    
    final now = DateTime.now();
    final timeSinceRejection = now.difference(_lastUserRejection!);
    final remaining = _rejectionCooldown - timeSinceRejection;
    
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  /// 尝试 TFLite 推理
  Future<TFLiteInferenceResult?> _tryTFLiteInference(NetworkQuality networkQuality) async {
    try {
      // 如果模型未加载，尝试加载
      if (!_tfliteEvaluator.isModelLoaded) {
        final loaded = await _tfliteEvaluator.loadModel();
        if (!loaded) {
          print('⚠️ TFLite 模型加载失败，使用模拟推理');
          return _tfliteEvaluator.simulateInference(networkQuality);
        }
      }
      
      // 进行推理
      final result = await _tfliteEvaluator.infer(networkQuality);
      return result;
      
    } catch (e) {
      print('❌ TFLite 推理异常: $e');
      // 异常时使用模拟推理
      return _tfliteEvaluator.simulateInference(networkQuality);
    }
  }

  /// 生成包含 TFLite 信息的推荐原因
  String _generateRecommendationReasonWithTFLite(
    bool shouldRecommend,
    NetworkQuality quality,
    TFLiteInferenceResult tfliteResult,
  ) {
    if (!shouldRecommend) {
      if (_isInRejectionCooldown()) {
        return '用户近期已拒绝推荐';
      }
      
      if (_weakNetworkHistory.length < _debounceCount) {
        return '网络质量检测中...';
      }
      
      final weakCount = _weakNetworkHistory.where((isWeak) => isWeak).length;
      if (weakCount < _debounceCount) {
        return '网络质量不稳定，需连续检测';
      }
      
      return '网络质量正常 (AI 评分: ${(tfliteResult.qualityScore * 100).toStringAsFixed(1)}%)';
    }

    // 推荐原因（包含 AI 信息）
    final reasons = <String>[];
    
    if (quality.bandwidthMbps < 1.0) {
      reasons.add('带宽过低(${quality.bandwidthMbps.toStringAsFixed(2)}Mbps)');
    }
    
    if (quality.packetLossRate > 5.0) {
      reasons.add('丢包率过高(${quality.packetLossRate.toStringAsFixed(2)}%)');
    }
    
    if (quality.avgDelayMs > 100.0) {
      reasons.add('延迟过高(${quality.avgDelayMs.toStringAsFixed(0)}ms)');
    }

    return '弱网环境：${reasons.join("，")} (AI 置信度: ${(tfliteResult.confidence * 100).toStringAsFixed(1)}%)';
  }

  /// 获取 TFLite 模型信息
  Map<String, dynamic> getTFLiteModelInfo() {
    return _tfliteEvaluator.getModelInfo();
  }

  /// 清空历史记录
  void clearHistory() {
    _weakNetworkHistory.clear();
    _lastUserRejection = null;
    notifyListeners();
  }

  /// 检测网关网络质量（新增网关测速功能）
  Future<NetworkQuality> detectGatewayQuality(String gatewayIp) async {
    try {
      // 获取场景化阈值
      final threshold = _getBandwidthThresholdByScene();
      
      // 创建网关测速器
      final tester = GatewayBandwidthTester(
        gatewayIp,
        weakThresholdMbps: threshold,
        port: 80,
      );

      // 执行测速并获取最终带宽
      final bandwidth = await tester.measureBandwidth();

      // 复用现有的LAN网络质量数据（延迟和丢包率）
      final lanQuality = await _networkAnalyzer.measureNetworkQuality();

      return NetworkQuality(
        bandwidthMbps: bandwidth,
        packetLossRate: lanQuality.packetLossRate,
        avgDelayMs: lanQuality.avgDelayMs,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('网关测速失败: $e');
      // 测速失败时返回默认弱网质量
      return NetworkQuality(
        bandwidthMbps: 0.0,
        packetLossRate: 100.0,
        avgDelayMs: 1000.0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// 获取网关测速进度流（用于UI进度显示）
  Stream<BandwidthProgress> measureGatewayBandwidth(String gatewayIp) {
    final threshold = _getBandwidthThresholdByScene();
    final tester = GatewayBandwidthTester(
      gatewayIp,
      weakThresholdMbps: threshold,
      port: 80,
    );
    return tester.measure();
  }
}
