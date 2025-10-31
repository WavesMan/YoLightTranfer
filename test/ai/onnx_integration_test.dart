// ONNX 集成系统测试
// 验证 ONNX 模型加载和推理功能

import 'package:flutter_test/flutter_test.dart';
import 'package:yolighttransfer/ai/onnx_network_evaluator.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ONNX 网络质量评估器测试', () {
    late ONNXNetworkEvaluator onnxEvaluator;

    setUp(() {
      onnxEvaluator = ONNXNetworkEvaluator();
    });

    tearDown(() {
      onnxEvaluator.unloadModel();
    });

    test('模型加载测试', () async {
      // 测试模型加载
      final loaded = await onnxEvaluator.loadModel();
      expect(loaded, isTrue);
      expect(onnxEvaluator.isModelLoaded, isTrue);
    });

    test('模型信息获取测试', () async {
      // 测试模型信息获取
      final modelInfo = onnxEvaluator.getModelInfo();
      expect(modelInfo['loaded'], isFalse);
      expect(modelInfo['modelPath'], isNotNull);

      // 加载模型后再次测试
      await onnxEvaluator.loadModel();
      final loadedModelInfo = onnxEvaluator.getModelInfo();
      expect(loadedModelInfo['loaded'], isTrue);
      expect(loadedModelInfo['inputNodes'], isNotEmpty);
      expect(loadedModelInfo['outputNodes'], isNotEmpty);
    });

    test('模拟推理测试', () {
      // 测试模拟推理（模型未加载时）
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      final result = onnxEvaluator.simulateInference(networkQuality);
      expect(result, isNotNull);
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.qualityScore, greaterThanOrEqualTo(0.0));
      expect(result.qualityScore, lessThanOrEqualTo(1.0));
      expect(result.shouldRecommendHotspot, isTrue); // 弱网应该推荐热点
    });

    test('批量推理测试', () async {
      // 测试批量推理
      final qualities = [
        NetworkQuality(
          bandwidthMbps: 0.5,
          packetLossRate: 10.0,
          avgDelayMs: 150.0,
          timestamp: DateTime.now(),
        ),
        NetworkQuality(
          bandwidthMbps: 50.0,
          packetLossRate: 1.0,
          avgDelayMs: 20.0,
          timestamp: DateTime.now(),
        ),
      ];

      final results = await onnxEvaluator.batchInfer(qualities);
      expect(results, hasLength(2));
      // 模型未加载时使用模拟推理，所以返回结果而不是 null
      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(results[0]!.shouldRecommendHotspot, isTrue); // 弱网应该推荐热点
      expect(results[1]!.shouldRecommendHotspot, isFalse); // 正常网络不应该推荐热点
    });

    test('特征预处理测试', () {
      // 测试特征预处理逻辑
      final networkQuality = NetworkQuality(
        bandwidthMbps: 50.0,
        packetLossRate: 5.0,
        avgDelayMs: 50.0,
        timestamp: DateTime.now(),
      );

      // 通过模拟推理间接测试预处理
      final result = onnxEvaluator.simulateInference(networkQuality);
      expect(result, isNotNull);
      expect(result.confidence, lessThan(0.5)); // 正常网络置信度应该较低
      expect(result.shouldRecommendHotspot, isFalse); // 正常网络不应该推荐热点
    });
  });

  group('ONNX 推理结果测试', () {
    test('推理结果属性验证', () {
      final result = ONNXInferenceResult(
        confidence: 0.8,
        qualityScore: 0.9,
        shouldRecommendHotspot: true,
        modelVersion: '1.0.0',
      );

      expect(result.confidence, 0.8);
      expect(result.qualityScore, 0.9);
      expect(result.shouldRecommendHotspot, isTrue);
      expect(result.modelVersion, '1.0.0');
    });

    test('推理结果字符串表示', () {
      final result = ONNXInferenceResult(
        confidence: 0.75,
        qualityScore: 0.85,
        shouldRecommendHotspot: false,
        modelVersion: 'test_1.0',
      );

      final stringRepresentation = result.toString();
      expect(stringRepresentation, contains('ONNXInferenceResult'));
      expect(stringRepresentation, contains('confidence: 0.75'));
      expect(stringRepresentation, contains('qualityScore: 0.85'));
      expect(stringRepresentation, contains('shouldRecommendHotspot: false'));
      expect(stringRepresentation, contains('modelVersion: test_1.0'));
    });
  });
}
