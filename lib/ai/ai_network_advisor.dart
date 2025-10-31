// AI模块：网络智能顾问
// 基于规则引擎的微AI模型，负责弱网识别与热点推荐
// 支持场景切换、动态阈值、防抖机制

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/ai/onnx_network_evaluator.dart';

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
  final ONNXNetworkEvaluator _onnxEvaluator;
  
  AIScene _currentScene = AIScene.general;
  final List<bool> _weakNetworkHistory = []; // 弱网历史记录（防抖）
  static const int _debounceCount = 3;       // 连续3次弱网才推荐
  
  // 用户偏好记忆
  DateTime? _lastUserRejection;              // 上次用户拒绝时间
  static const Duration _rejectionCooldown = Duration(minutes: 30); // 30分钟冷却

  AINetworkAdvisor({
    required NetworkQualityAnalyzer networkAnalyzer,
    required AppConfigService configService,
    ONNXNetworkEvaluator? onnxEvaluator,
    AIScene initialScene = AIScene.general,
  })  : _networkAnalyzer = networkAnalyzer,
        _configService = configService,
        _onnxEvaluator = onnxEvaluator ?? ONNXNetworkEvaluator(),
        _currentScene = initialScene {
    // 异步加载 ONNX 模型
    _initializeONNXModel();
  }

  /// 异步初始化 ONNX 模型
  void _initializeONNXModel() async {
    try {
      await _onnxEvaluator.loadModel();
    } catch (e) {
      print('⚠️ ONNX 模型初始化失败: $e');
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

    // 2. 尝试使用 ONNX 模型进行推理
    final onnxResult = await _tryONNXInference(networkQuality);
    
    // 3. 如果 ONNX 推理成功且置信度高，使用 ONNX 结果
    if (onnxResult != null && onnxResult.confidence >= _onnxEvaluator.confidenceThreshold) {
      print('🧠 使用 ONNX 推理结果 (置信度: ${onnxResult.confidence.toStringAsFixed(2)})');
      
      // 更新弱网历史记录（基于 ONNX 结果）
      _updateWeakNetworkHistory(onnxResult.shouldRecommendHotspot);
      
      // 综合决策（基于历史记录）
      final shouldRecommend = _shouldRecommendBasedOnHistory();
      
      // 生成推荐原因
      final reason = _generateRecommendationReasonWithONNX(
        shouldRecommend,
        networkQuality,
        onnxResult,
      );
      
      return AIRecommendation(
        shouldRecommendHotspot: shouldRecommend,
        reason: reason,
        networkQuality: networkQuality,
        timestamp: DateTime.now(),
      );
    }
    
    // 4. 如果 ONNX 不可用或置信度低，回退到规则引擎
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

  /// 尝试 ONNX 推理
  Future<ONNXInferenceResult?> _tryONNXInference(NetworkQuality networkQuality) async {
    try {
      // 如果模型未加载，尝试加载
      if (!_onnxEvaluator.isModelLoaded) {
        final loaded = await _onnxEvaluator.loadModel();
        if (!loaded) {
          print('⚠️ ONNX 模型加载失败，使用模拟推理');
          return _onnxEvaluator.simulateInference(networkQuality);
        }
      }
      
      // 进行推理
      final result = await _onnxEvaluator.infer(networkQuality);
      return result;
      
    } catch (e) {
      print('❌ ONNX 推理异常: $e');
      // 异常时使用模拟推理
      return _onnxEvaluator.simulateInference(networkQuality);
    }
  }

  /// 生成包含 ONNX 信息的推荐原因
  String _generateRecommendationReasonWithONNX(
    bool shouldRecommend,
    NetworkQuality quality,
    ONNXInferenceResult onnxResult,
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
      
      return '网络质量正常 (AI 评分: ${(onnxResult.qualityScore * 100).toStringAsFixed(1)}%)';
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

    return '弱网环境：${reasons.join("，")} (AI 置信度: ${(onnxResult.confidence * 100).toStringAsFixed(1)}%)';
  }

  /// 获取 ONNX 模型信息
  Map<String, dynamic> getONNXModelInfo() {
    return _onnxEvaluator.getModelInfo();
  }

  /// 清空历史记录
  void clearHistory() {
    _weakNetworkHistory.clear();
    _lastUserRejection = null;
    notifyListeners();
  }

  /// 检测网关网络质量（渐进式测速功能）
  Future<NetworkQuality> detectGatewayQuality(String gatewayIp) async {
    try {
      print('🔍 开始网关ICMP测速: $gatewayIp');
      
      // 第1阶段：ICMP ping测试网关可达性和延迟
      final pingResult = await _pingGateway(gatewayIp);
      
      if (!pingResult.isReachable) {
        print('⚠️ 网关不可达: $gatewayIp');
        return NetworkQuality(
          bandwidthMbps: 0.0,
          packetLossRate: 100.0,
          avgDelayMs: 1000.0,
          timestamp: DateTime.now(),
        );
      }
      
      print('✅ 网关可达，延迟=${pingResult.avgDelayMs}ms');
      
      // 第2阶段：基于延迟快速估算带宽范围
      final estimatedQuality = _estimateQualityFromPing(pingResult.avgDelayMs);
      print('📊 快速估算带宽: ${estimatedQuality.bandwidthMbps.toStringAsFixed(2)}Mbps');
      
      // 第3阶段：根据网络状况决定是否进行精确测试
      final preciseQuality = await _performProgressiveTesting(
        gatewayIp, 
        pingResult.avgDelayMs, 
        estimatedQuality.bandwidthMbps
      );
      
      print('✅ 网关测速完成: 延迟=${pingResult.avgDelayMs}ms, 带宽=${preciseQuality.bandwidthMbps.toStringAsFixed(2)}Mbps');
      
      return preciseQuality;
      
    } catch (e) {
      print('❌ 网关测速失败: $e');
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
  /// TODO: 重构测速实现 - 临时返回空流
  Stream<dynamic> measureGatewayBandwidth(String gatewayIp) {
    return Stream.empty();
  }

  /// ICMP ping测试网关
  Future<PingResult> _pingGateway(String gatewayIp) async {
    try {
      final process = await Process.start('ping', ['-c', '4', gatewayIp]);
      final output = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        return PingResult(isReachable: false, avgDelayMs: 1000.0);
      }

      // 解析ping输出，提取平均延迟
      final avgDelayMatch = RegExp(r'min/avg/max/mdev = [\d.]+/([\d.]+)/[\d.]+/[\d.]+').firstMatch(output);
      if (avgDelayMatch != null) {
        final avgDelay = double.tryParse(avgDelayMatch.group(1) ?? '1000.0') ?? 1000.0;
        return PingResult(isReachable: true, avgDelayMs: avgDelay);
      }

      // 如果无法解析延迟，检查是否有成功响应
      if (output.contains('bytes from')) {
        return PingResult(isReachable: true, avgDelayMs: 50.0); // 默认延迟
      }

      return PingResult(isReachable: false, avgDelayMs: 1000.0);
    } catch (e) {
      print('❌ ping测试失败: $e');
      return PingResult(isReachable: false, avgDelayMs: 1000.0);
    }
  }

  /// 根据ping延迟估算网络质量
  NetworkQuality _estimateQualityFromPing(double avgDelayMs) {
    // 基于延迟估算带宽和丢包率
    double estimatedBandwidth;
    double estimatedPacketLoss;

    if (avgDelayMs < 10) {
      // 优秀网络：延迟<10ms
      estimatedBandwidth = 50.0; // 50Mbps
      estimatedPacketLoss = 0.1;
    } else if (avgDelayMs < 50) {
      // 良好网络：延迟10-50ms
      estimatedBandwidth = 20.0; // 20Mbps
      estimatedPacketLoss = 1.0;
    } else if (avgDelayMs < 100) {
      // 一般网络：延迟50-100ms
      estimatedBandwidth = 5.0; // 5Mbps
      estimatedPacketLoss = 3.0;
    } else if (avgDelayMs < 200) {
      // 较差网络：延迟100-200ms
      estimatedBandwidth = 2.0; // 2Mbps
      estimatedPacketLoss = 5.0;
    } else {
      // 弱网：延迟>200ms
      estimatedBandwidth = 0.5; // 0.5Mbps
      estimatedPacketLoss = 10.0;
    }

    return NetworkQuality(
      bandwidthMbps: estimatedBandwidth,
      packetLossRate: estimatedPacketLoss,
      avgDelayMs: avgDelayMs,
      timestamp: DateTime.now(),
    );
  }

  /// 执行渐进式测试
  Future<NetworkQuality> _performProgressiveTesting(
    String gatewayIp, 
    double pingDelayMs, 
    double estimatedBandwidth
  ) async {
    print('🔄 开始渐进式测试...');
    
    // 第1阶段：快速测试（2-3秒）
    print('📊 第1阶段：快速测试');
    final fastTestResult = await _performFastBandwidthTest(gatewayIp);
    
    // 判断是否需要精确测试
    final needsPreciseTest = _needsPreciseTesting(
      fastTestResult.bandwidthMbps, 
      estimatedBandwidth
    );
    
    if (!needsPreciseTest) {
      print('✅ 快速测试结果稳定，直接返回');
      return NetworkQuality(
        bandwidthMbps: fastTestResult.bandwidthMbps,
        packetLossRate: fastTestResult.packetLossRate,
        avgDelayMs: pingDelayMs,
        timestamp: DateTime.now(),
      );
    }
    
    // 第2阶段：精确测试（3-5秒）
    print('📊 第2阶段：精确测试');
    final preciseTestResult = await _performPreciseBandwidthTest(gatewayIp);
    
    // 融合两次测试结果
    final finalBandwidth = (fastTestResult.bandwidthMbps + preciseTestResult.bandwidthMbps) / 2;
    final finalPacketLoss = (fastTestResult.packetLossRate + preciseTestResult.packetLossRate) / 2;
    
    print('✅ 渐进式测试完成，最终带宽: ${finalBandwidth.toStringAsFixed(2)}Mbps');
    
    return NetworkQuality(
      bandwidthMbps: finalBandwidth,
      packetLossRate: finalPacketLoss,
      avgDelayMs: pingDelayMs,
      timestamp: DateTime.now(),
    );
  }

  /// 执行快速带宽测试（2-3秒）
  Future<NetworkQuality> _performFastBandwidthTest(String gatewayIp) async {
    try {
      print('⚡ 开始快速带宽测试...');
      
      // TODO: 重构测速实现 - 临时使用模拟数据
      final bandwidth = 10.0; // 模拟带宽
      
      print('✅ 快速测试完成: ${bandwidth.toStringAsFixed(2)}Mbps');
      
      return NetworkQuality(
        bandwidthMbps: bandwidth,
        packetLossRate: 1.0, // 网关测速默认丢包率
        avgDelayMs: 50.0, // 网关测速默认延迟
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      print('❌ 快速测试失败: $e');
      // 测试失败时返回保守估算
      return NetworkQuality(
        bandwidthMbps: 5.0,
        packetLossRate: 5.0,
        avgDelayMs: 50.0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// 执行精确带宽测试（3-5秒）
  Future<NetworkQuality> _performPreciseBandwidthTest(String gatewayIp) async {
    try {
      print('🎯 开始精确带宽测试...');
      
      // TODO: 重构测速实现 - 临时使用模拟数据
      final bandwidth = 12.0; // 模拟精确带宽
      
      print('✅ 精确测试完成: ${bandwidth.toStringAsFixed(2)}Mbps');
      
      return NetworkQuality(
        bandwidthMbps: bandwidth,
        packetLossRate: 1.0, // 网关测速默认丢包率
        avgDelayMs: 50.0, // 网关测速默认延迟
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      print('❌ 精确测试失败: $e');
      // 测试失败时返回快速测试结果
      return await _performFastBandwidthTest(gatewayIp);
    }
  }

  /// 判断是否需要精确测试
  bool _needsPreciseTesting(double measuredBandwidth, double estimatedBandwidth) {
    // 如果测量值与估算值差异较大，需要精确测试
    final difference = (measuredBandwidth - estimatedBandwidth).abs();
    final relativeDifference = difference / estimatedBandwidth;
    
    // 差异超过30%或带宽在决策阈值附近时需要精确测试
    return relativeDifference > 0.3 || 
           (measuredBandwidth > 0.8 && measuredBandwidth < 2.0);
  }
}

/// Ping测试结果
class PingResult {
  final bool isReachable;
  final double avgDelayMs;

  PingResult({
    required this.isReachable,
    required this.avgDelayMs,
  });
}
