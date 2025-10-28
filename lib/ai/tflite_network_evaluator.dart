// TFLite 网络质量评估器
// 负责加载和运行 TFLite 模型进行网络质量推理
// 支持模型加载失败时的降级方案

import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';

/// TFLite 推理结果
class TFLiteInferenceResult {
  final double confidence; // 置信度 (0.0 - 1.0)
  final double qualityScore; // 质量评分 (0.0 - 1.0)
  final bool shouldRecommendHotspot; // 是否推荐热点
  final String modelVersion; // 模型版本

  const TFLiteInferenceResult({
    required this.confidence,
    required this.qualityScore,
    required this.shouldRecommendHotspot,
    required this.modelVersion,
  });

  @override
  String toString() {
    return 'TFLiteInferenceResult(confidence: $confidence, qualityScore: $qualityScore, shouldRecommendHotspot: $shouldRecommendHotspot, modelVersion: $modelVersion)';
  }
}

/// TFLite 网络质量评估器
class TFLiteNetworkEvaluator {
  static const String _modelPath = 'assets/models/network_quality_model.tflite';
  static const double _confidenceThreshold = 0.6; // 置信度阈值，低于此值回退到规则引擎
  
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isLoading = false;
  String _modelVersion = '1.0.0';
  
  // 输入输出张量信息
  static const List<int> _inputShape = [1, 3]; // [batch_size, features]
  static const List<int> _outputShape = [1, 3]; // [batch_size, outputs]
  
  // 特征归一化参数（基于训练数据统计）
  static const Map<String, double> _featureStats = {
    'bandwidth_mean': 50.0,
    'bandwidth_std': 25.0,
    'delay_mean': 50.0,
    'delay_std': 30.0,
    'loss_mean': 10.0,
    'loss_std': 15.0,
  };

  /// 加载 TFLite 模型
  Future<bool> loadModel() async {
    if (_isLoading) return false;
    if (_isModelLoaded) return true;
    
    _isLoading = true;
    
    try {
      print('🔄 正在加载 TFLite 模型: $_modelPath');
      
      // 创建解释器选项
      final options = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = true;
      
      // 加载模型
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      
      // 验证输入输出形状
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      if (inputTensors.isEmpty || outputTensors.isEmpty) {
        throw Exception('模型输入输出张量为空');
      }
      
      print('✅ TFLite 模型加载成功');
      print('   输入张量: ${inputTensors.map((t) => '${t.shape} (${t.type})')}');
      print('   输出张量: ${outputTensors.map((t) => '${t.shape} (${t.type})')}');
      
      _isModelLoaded = true;
      return true;
      
    } catch (e, stackTrace) {
      print('❌ TFLite 模型加载失败: $e');
      print('堆栈跟踪: $stackTrace');
      _interpreter?.close();
      _interpreter = null;
      _isModelLoaded = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 卸载模型
  void unloadModel() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('🗑️ TFLite 模型已卸载');
  }

  /// 使用 TFLite 模型进行推理
  Future<TFLiteInferenceResult?> infer(NetworkQuality networkQuality) async {
    if (!_isModelLoaded) {
      print('⚠️ TFLite 模型未加载，无法进行推理');
      return null;
    }

    try {
      // 1. 特征预处理
      final inputFeatures = _preprocessFeatures(networkQuality);
      
      // 2. 准备输入输出缓冲区
      final input = [inputFeatures];
      final output = List.filled(1, List.filled(3, 0.0));
      
      // 3. 运行推理
      _interpreter!.run(input, output);
      
      // 4. 后处理输出
      final rawOutput = output[0];
      final result = _postprocessOutput(rawOutput);
      
      print('🧠 TFLite 推理完成: $result');
      return result;
      
    } catch (e, stackTrace) {
      print('❌ TFLite 推理失败: $e');
      print('堆栈跟踪: $stackTrace');
      return null;
    }
  }

  /// 特征预处理：归一化网络质量指标
  List<double> _preprocessFeatures(NetworkQuality quality) {
    // 归一化带宽 (0-100 Mbps → 0-1)
    final normalizedBandwidth = (quality.bandwidthMbps - _featureStats['bandwidth_mean']!) / 
                               _featureStats['bandwidth_std']!;
    
    // 归一化延迟 (0-200 ms → 0-1，超过200ms视为1)
    final normalizedDelay = (quality.avgDelayMs.clamp(0, 200) - _featureStats['delay_mean']!) / 
                           _featureStats['delay_std']!;
    
    // 归一化丢包率 (0-100% → 0-1)
    final normalizedLoss = (quality.packetLossRate.clamp(0, 100) - _featureStats['loss_mean']!) / 
                          _featureStats['loss_std']!;
    
    // 裁剪到合理范围
    return [
      normalizedBandwidth.clamp(-3.0, 3.0),
      normalizedDelay.clamp(-3.0, 3.0),
      normalizedLoss.clamp(-3.0, 3.0),
    ];
  }

  /// 输出后处理：解析模型输出
  TFLiteInferenceResult _postprocessOutput(List<double> rawOutput) {
    // 假设模型输出格式: [confidence, quality_score, hotspot_recommendation]
    final confidence = rawOutput[0].clamp(0.0, 1.0);
    final qualityScore = rawOutput[1].clamp(0.0, 1.0);
    final hotspotRecommendation = rawOutput[2] > 0.5;
    
    return TFLiteInferenceResult(
      confidence: confidence,
      qualityScore: qualityScore,
      shouldRecommendHotspot: hotspotRecommendation,
      modelVersion: _modelVersion,
    );
  }

  /// 检查模型是否已加载
  bool get isModelLoaded => _isModelLoaded;

  /// 获取模型版本
  String get modelVersion => _modelVersion;

  /// 获取置信度阈值
  double get confidenceThreshold => _confidenceThreshold;

  /// 模拟推理（用于测试或模型缺失时）
  TFLiteInferenceResult simulateInference(NetworkQuality quality) {
    print('🔬 使用模拟推理（模型未加载或置信度低）');
    
    // 基于规则的模拟推理
    final isWeakNetwork = quality.bandwidthMbps < 1.0 && 
                         quality.packetLossRate > 5.0 && 
                         quality.avgDelayMs > 100.0;
    
    // 计算模拟置信度（基于指标与阈值的距离）
    final bandwidthConfidence = (1.0 - (quality.bandwidthMbps / 1.0).clamp(0.0, 1.0));
    final lossConfidence = (quality.packetLossRate / 20.0).clamp(0.0, 1.0);
    final delayConfidence = (quality.avgDelayMs / 200.0).clamp(0.0, 1.0);
    
    final confidence = (bandwidthConfidence + lossConfidence + delayConfidence) / 3.0;
    final qualityScore = 1.0 - confidence;
    
    return TFLiteInferenceResult(
      confidence: confidence,
      qualityScore: qualityScore,
      shouldRecommendHotspot: isWeakNetwork,
      modelVersion: 'simulated_1.0.0',
    );
  }

  /// 批量推理（用于性能测试）
  Future<List<TFLiteInferenceResult?>> batchInfer(List<NetworkQuality> qualities) async {
    if (!_isModelLoaded) {
      print('⚠️ TFLite 模型未加载，无法进行批量推理');
      return List.filled(qualities.length, null);
    }

    final results = <TFLiteInferenceResult?>[];
    
    for (final quality in qualities) {
      final result = await infer(quality);
      results.add(result);
    }
    
    return results;
  }

  /// 获取模型信息
  Map<String, dynamic> getModelInfo() {
    if (!_isModelLoaded) {
      return {
        'loaded': false,
        'modelPath': _modelPath,
        'modelVersion': _modelVersion,
      };
    }

    final inputTensors = _interpreter!.getInputTensors();
    final outputTensors = _interpreter!.getOutputTensors();
    
    return {
      'loaded': true,
      'modelPath': _modelPath,
      'modelVersion': _modelVersion,
      'inputTensors': inputTensors.map((t) => {
        'shape': t.shape,
        'type': t.type.toString(),
        'name': t.name,
      }).toList(),
      'outputTensors': outputTensors.map((t) => {
        'shape': t.shape,
        'type': t.type.toString(),
        'name': t.name,
      }).toList(),
      'confidenceThreshold': _confidenceThreshold,
    };
  }
}
