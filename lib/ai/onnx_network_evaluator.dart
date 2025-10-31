// ONNX 网络质量评估器
// 负责加载和运行 ONNX 模型进行网络质量推理
// 替换原有的 TFLite 系统

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';

/// ONNX 推理结果
class ONNXInferenceResult {
  final double confidence; // 置信度 (0.0 - 1.0)
  final double qualityScore; // 质量评分 (0.0 - 1.0)
  final bool shouldRecommendHotspot; // 是否推荐热点
  final String modelVersion; // 模型版本

  const ONNXInferenceResult({
    required this.confidence,
    required this.qualityScore,
    required this.shouldRecommendHotspot,
    required this.modelVersion,
  });

  @override
  String toString() {
    return 'ONNXInferenceResult(confidence: $confidence, qualityScore: $qualityScore, shouldRecommendHotspot: $shouldRecommendHotspot, modelVersion: $modelVersion)';
  }
}

/// ONNX 网络质量评估器
class ONNXNetworkEvaluator {
  static const String _modelPath = 'assets/models/network_quality_model.onnx';
  static const double _confidenceThreshold = 0.6; // 置信度阈值，低于此值回退到规则引擎
  
  OrtSession? _session;
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

  /// 加载 ONNX 模型
  Future<bool> loadModel() async {
    if (_isLoading) return false;
    if (_isModelLoaded) return true;
    
    _isLoading = true;
    
    try {
      print('🔄 正在加载 ONNX 模型: $_modelPath');
      
      // 初始化 ONNX Runtime 环境
      OrtEnv.instance.init();
      
      // 从 assets 加载模型
      final rawAssetFile = await rootBundle.load(_modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();
      
      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      // 从字节数据创建会话
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      
      // 验证输入输出信息
      final inputNames = _session!.inputNames;
      final outputNames = _session!.outputNames;
      
      if (inputNames.isEmpty || outputNames.isEmpty) {
        throw Exception('模型输入输出为空');
      }
      
      print('✅ ONNX 模型加载成功');
      print('   输入节点: $inputNames');
      print('   输出节点: $outputNames');
      
      _isModelLoaded = true;
      return true;
      
    } catch (e, stackTrace) {
      print('❌ ONNX 模型加载失败: $e');
      print('堆栈跟踪: $stackTrace');
      _session = null;
      _isModelLoaded = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 卸载模型
  void unloadModel() {
    _session?.release();
    _session = null;
    _isModelLoaded = false;
    OrtEnv.instance.release();
    print('🗑️ ONNX 模型已卸载');
  }

  /// 使用 ONNX 模型进行推理
  Future<ONNXInferenceResult?> infer(NetworkQuality networkQuality) async {
    if (!_isModelLoaded || _session == null) {
      print('⚠️ ONNX 模型未加载，使用模拟推理');
      return simulateInference(networkQuality);
    }

    try {
      // 1. 特征预处理
      final inputFeatures = _preprocessFeatures(networkQuality);
      
      // 2. 准备输入张量
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputFeatures,
        _inputShape,
      );
      
      // 3. 运行推理
      final inputName = _session!.inputNames.first;
      final outputName = _session!.outputNames.first;
      
      final runOptions = OrtRunOptions();
      final inputs = {inputName: inputTensor};
      final outputs = await _session!.runAsync(runOptions, inputs);
      
      // 4. 获取输出结果
      final outputIndex = _session!.outputNames.indexOf(outputName);
      final outputTensor = outputs?[outputIndex];
      
      if (outputTensor == null) {
        throw Exception('推理输出为空');
      }
      
      // 清理资源
      inputTensor.release();
      runOptions.release();
      outputs?.forEach((value) {
        value?.release();
      });
      
      // 尝试获取输出数据
      List<double> doubleOutput = [];
      try {
        // 尝试直接转换
        if (outputTensor is List) {
          doubleOutput = (outputTensor as List).cast<double>();
        } else {
          // 如果不是列表，使用模拟推理
          return simulateInference(networkQuality);
        }
      } catch (e) {
        print('⚠️ 无法解析输出数据: $e，使用模拟推理');
        return simulateInference(networkQuality);
      }
      
      // 5. 后处理输出
      final result = _postprocessOutput(doubleOutput);
      
      print('🧠 ONNX 推理完成: $result');
      return result;
      
    } catch (e, stackTrace) {
      print('❌ ONNX 推理失败: $e');
      print('堆栈跟踪: $stackTrace');
      // 推理失败时回退到模拟推理
      return simulateInference(networkQuality);
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
  ONNXInferenceResult _postprocessOutput(List<double> rawOutput) {
    // 假设模型输出格式: [confidence, quality_score, hotspot_recommendation]
    final confidence = rawOutput.isNotEmpty ? rawOutput[0].clamp(0.0, 1.0) : 0.5;
    final qualityScore = rawOutput.length > 1 ? rawOutput[1].clamp(0.0, 1.0) : 0.5;
    final hotspotRecommendation = rawOutput.length > 2 ? rawOutput[2] > 0.5 : false;
    
    return ONNXInferenceResult(
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
  ONNXInferenceResult simulateInference(NetworkQuality quality) {
    print('🔬 使用模拟推理（模型未加载或推理失败）');
    
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
    
    return ONNXInferenceResult(
      confidence: confidence,
      qualityScore: qualityScore,
      shouldRecommendHotspot: isWeakNetwork,
      modelVersion: 'simulated_1.0.0',
    );
  }

  /// 批量推理（用于性能测试）
  Future<List<ONNXInferenceResult?>> batchInfer(List<NetworkQuality> qualities) async {
    final results = <ONNXInferenceResult?>[];
    
    for (final quality in qualities) {
      final result = await infer(quality);
      results.add(result);
    }
    
    return results;
  }

  /// 获取模型信息
  Map<String, dynamic> getModelInfo() {
    if (!_isModelLoaded || _session == null) {
      return {
        'loaded': false,
        'modelPath': _modelPath,
        'modelVersion': _modelVersion,
      };
    }

    final inputNames = _session!.inputNames;
    final outputNames = _session!.outputNames;
    
    return {
      'loaded': true,
      'modelPath': _modelPath,
      'modelVersion': _modelVersion,
      'inputNodes': inputNames,
      'outputNodes': outputNames,
      'confidenceThreshold': _confidenceThreshold,
    };
  }
}
