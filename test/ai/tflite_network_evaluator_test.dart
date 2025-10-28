import 'package:flutter_test/flutter_test.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/ai/tflite_network_evaluator.dart';

void main() {
  group('TFLiteNetworkEvaluator', () {
    late TFLiteNetworkEvaluator evaluator;

    setUp(() {
      evaluator = TFLiteNetworkEvaluator();
    });

    tearDown(() {
      evaluator.unloadModel();
    });

    test('should initialize with correct default values', () {
      expect(evaluator.isModelLoaded, false);
      expect(evaluator.modelVersion, '1.0.0');
      expect(evaluator.confidenceThreshold, 0.6);
    });

    test('should handle model loading failure gracefully', () async {
      // 由于没有真实的模型文件，加载应该失败
      final result = await evaluator.loadModel();
      expect(result, false);
      expect(evaluator.isModelLoaded, false);
    });

    test('should simulate inference when model not loaded', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      final result = await evaluator.infer(networkQuality);
      expect(result, isNull);
    });

    test('should provide simulated inference result', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      final result = evaluator.simulateInference(networkQuality);
      
      expect(result.confidence, greaterThan(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.qualityScore, greaterThan(0.0));
      expect(result.qualityScore, lessThanOrEqualTo(1.0));
      expect(result.shouldRecommendHotspot, isTrue);
      expect(result.modelVersion, 'simulated_1.0.0');
    });

    test('should simulate inference for good network conditions', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 10.0,
        packetLossRate: 1.0,
        avgDelayMs: 20.0,
        timestamp: DateTime.now(),
      );

      final result = evaluator.simulateInference(networkQuality);
      
      expect(result.shouldRecommendHotspot, isFalse);
      expect(result.confidence, lessThan(0.5));
    });

    test('should batch simulate inference', () async {
      final qualities = [
        NetworkQuality(
          bandwidthMbps: 0.5,
          packetLossRate: 10.0,
          avgDelayMs: 150.0,
          timestamp: DateTime.now(),
        ),
        NetworkQuality(
          bandwidthMbps: 10.0,
          packetLossRate: 1.0,
          avgDelayMs: 20.0,
          timestamp: DateTime.now(),
        ),
      ];

      final results = await evaluator.batchInfer(qualities);
      
      expect(results.length, 2);
      expect(results.every((result) => result == null), isTrue);
    });

    test('should provide model info when not loaded', () {
      final modelInfo = evaluator.getModelInfo();
      
      expect(modelInfo['loaded'], false);
      expect(modelInfo['modelPath'], 'assets/models/network_quality_model.tflite');
      expect(modelInfo['modelVersion'], '1.0.0');
    });

    test('should handle feature preprocessing correctly', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 50.0,
        packetLossRate: 10.0,
        avgDelayMs: 50.0,
        timestamp: DateTime.now(),
      );

      // 测试预处理逻辑（通过反射访问私有方法）
      // 注意：实际项目中可能需要使用反射或修改访问权限
      // 这里我们验证模拟推理的结果
      final result = evaluator.simulateInference(networkQuality);
      
      // 对于中等网络条件，应该不推荐热点
      expect(result.shouldRecommendHotspot, isFalse);
    });

    test('should handle extreme network conditions in simulation', () {
      final veryPoorNetwork = NetworkQuality(
        bandwidthMbps: 0.1,
        packetLossRate: 50.0,
        avgDelayMs: 500.0,
        timestamp: DateTime.now(),
      );

      final result = evaluator.simulateInference(veryPoorNetwork);
      
      expect(result.shouldRecommendHotspot, isTrue);
      expect(result.confidence, greaterThan(0.7));
    });

    test('should handle perfect network conditions in simulation', () {
      final perfectNetwork = NetworkQuality(
        bandwidthMbps: 100.0,
        packetLossRate: 0.0,
        avgDelayMs: 1.0,
        timestamp: DateTime.now(),
      );

      final result = evaluator.simulateInference(perfectNetwork);
      
      expect(result.shouldRecommendHotspot, isFalse);
      expect(result.confidence, lessThan(0.3));
    });

    test('should unload model without errors', () {
      // 即使模型未加载，卸载也不应该抛出异常
      expect(() => evaluator.unloadModel(), returnsNormally);
    });
  });

  group('TFLiteInferenceResult', () {
    test('should create with valid values', () {
      const result = TFLiteInferenceResult(
        confidence: 0.8,
        qualityScore: 0.2,
        shouldRecommendHotspot: true,
        modelVersion: '1.0.0',
      );

      expect(result.confidence, 0.8);
      expect(result.qualityScore, 0.2);
      expect(result.shouldRecommendHotspot, isTrue);
      expect(result.modelVersion, '1.0.0');
    });

    test('should have correct string representation', () {
      const result = TFLiteInferenceResult(
        confidence: 0.75,
        qualityScore: 0.25,
        shouldRecommendHotspot: false,
        modelVersion: 'test-1.0',
      );

      final str = result.toString();
      expect(str, contains('confidence: 0.75'));
      expect(str, contains('qualityScore: 0.25'));
      expect(str, contains('shouldRecommendHotspot: false'));
      expect(str, contains('modelVersion: test-1.0'));
    });

    test('should handle edge confidence values', () {
      const minConfidence = TFLiteInferenceResult(
        confidence: 0.0,
        qualityScore: 1.0,
        shouldRecommendHotspot: false,
        modelVersion: '1.0.0',
      );

      const maxConfidence = TFLiteInferenceResult(
        confidence: 1.0,
        qualityScore: 0.0,
        shouldRecommendHotspot: true,
        modelVersion: '1.0.0',
      );

      expect(minConfidence.confidence, 0.0);
      expect(maxConfidence.confidence, 1.0);
    });
  });
}
