import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';
import 'package:yolighttransfer/ai/tflite_network_evaluator.dart';

// Mock classes for testing
class MockNetworkQualityAnalyzer extends Mock implements NetworkQualityAnalyzer {}
class MockAppConfigService extends Mock implements AppConfigService {}
class MockTFLiteNetworkEvaluator extends Mock implements TFLiteNetworkEvaluator {}

// Fake classes for fallback values
class NetworkQualityFake extends Fake implements NetworkQuality {}

void main() {
  setUpAll(() {
    registerFallbackValue(NetworkQualityFake());
  });
  group('AINetworkAdvisor', () {
    late AINetworkAdvisor advisor;
    late MockNetworkQualityAnalyzer mockAnalyzer;
    late MockAppConfigService mockConfigService;
    late MockTFLiteNetworkEvaluator mockTFLiteEvaluator;

    setUp(() {
      mockAnalyzer = MockNetworkQualityAnalyzer();
      mockConfigService = MockAppConfigService();
      mockTFLiteEvaluator = MockTFLiteNetworkEvaluator();

      // 设置默认的 mock 行为
      when(() => mockTFLiteEvaluator.isModelLoaded).thenReturn(false);
      when(() => mockTFLiteEvaluator.confidenceThreshold).thenReturn(0.6);
      when(() => mockTFLiteEvaluator.loadModel()).thenAnswer((_) async => false);
      when(() => mockTFLiteEvaluator.getModelInfo()).thenReturn({
        'loaded': false,
        'modelPath': 'assets/models/network_quality_model.tflite',
        'modelVersion': '1.0.0',
      });
      // 设置模拟推理的默认行为
      when(() => mockTFLiteEvaluator.simulateInference(any()))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.7,
            qualityScore: 0.3,
            shouldRecommendHotspot: true,
            modelVersion: 'simulated_1.0.0',
          ));

      advisor = AINetworkAdvisor(
        networkAnalyzer: mockAnalyzer,
        configService: mockConfigService,
        tfliteEvaluator: mockTFLiteEvaluator,
      );
    });

    tearDown(() {
      advisor.clearHistory();
    });

    test('should initialize with default scene', () {
      expect(advisor.currentScene, AIScene.general);
    });

    test('should update scene correctly', () {
      advisor.updateScene(AIScene.manufacturing);
      expect(advisor.currentScene, AIScene.manufacturing);

      advisor.updateScene(AIScene.education);
      expect(advisor.currentScene, AIScene.education);
    });

    test('should not notify when updating to same scene', () {
      var notifyCount = 0;
      advisor.addListener(() => notifyCount++);

      advisor.updateScene(AIScene.general); // 已经是当前场景
      expect(notifyCount, 0);

      advisor.updateScene(AIScene.manufacturing); // 新场景
      expect(notifyCount, 1);
    });

    test('should handle user rejection correctly', () {
      // 记录用户拒绝
      advisor.recordUserRejection();
      expect(advisor.lastUserRejection, isNotNull);

      // 检查冷却时间
      expect(advisor.rejectionCooldownRemaining, greaterThan(0));

      // 清除拒绝记录
      advisor.clearUserRejection();
      expect(advisor.lastUserRejection, isNull);
      expect(advisor.rejectionCooldownRemaining, isNull);
    });

    test('should return correct recommendation with external network quality', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 设置 TFLite 模拟推理
      when(() => mockTFLiteEvaluator.simulateInference(any()))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.8,
            qualityScore: 0.2,
            shouldRecommendHotspot: true,
            modelVersion: 'simulated_1.0.0',
          ));

      // 需要连续调用3次才能触发推荐（防抖机制）
      await advisor.shouldRecommendHotspotWith(networkQuality);
      await advisor.shouldRecommendHotspotWith(networkQuality);
      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      expect(recommendation.shouldRecommendHotspot, isTrue);
      expect(recommendation.reason, contains('弱网环境'));
      expect(recommendation.networkQuality, networkQuality);
    });

    test('should respect user rejection cooldown', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 记录用户拒绝
      advisor.recordUserRejection();

      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      expect(recommendation.shouldRecommendHotspot, isFalse);
      expect(recommendation.reason, contains('用户近期已拒绝推荐'));
    });

    test('should use TFLite when model is loaded and confident', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 设置 TFLite 为已加载且置信度高
      when(() => mockTFLiteEvaluator.isModelLoaded).thenReturn(true);
      when(() => mockTFLiteEvaluator.infer(any()))
          .thenAnswer((_) async => TFLiteInferenceResult(
                confidence: 0.8,
                qualityScore: 0.2,
                shouldRecommendHotspot: true,
                modelVersion: '1.0.0',
              ));

      // 需要连续调用3次才能触发推荐（防抖机制）
      await advisor.shouldRecommendHotspotWith(networkQuality);
      await advisor.shouldRecommendHotspotWith(networkQuality);
      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      expect(recommendation.shouldRecommendHotspot, isTrue);
      expect(recommendation.reason, contains('AI 置信度'));
    });

    test('should fallback to rule engine when TFLite confidence is low', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 设置 TFLite 置信度低
      when(() => mockTFLiteEvaluator.isModelLoaded).thenReturn(true);
      when(() => mockTFLiteEvaluator.infer(any()))
          .thenAnswer((_) async => TFLiteInferenceResult(
                confidence: 0.5, // 低于阈值 0.6
                qualityScore: 0.5,
                shouldRecommendHotspot: true,
                modelVersion: '1.0.0',
              ));
      // 设置配置服务返回有效值
      when(() => mockConfigService.get<double>(any())).thenReturn(1.0);

      // 需要连续调用3次才能触发推荐（防抖机制）
      await advisor.shouldRecommendHotspotWith(networkQuality);
      await advisor.shouldRecommendHotspotWith(networkQuality);
      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      expect(recommendation.reason, contains('弱网环境'));
    });

    test('should handle debounce mechanism correctly', () async {
      final poorNetworkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 第一次检测 - 应该不推荐（历史记录不足）
      var recommendation = await advisor.shouldRecommendHotspotWith(poorNetworkQuality);
      expect(recommendation.shouldRecommendHotspot, isFalse);
      expect(recommendation.reason, contains('网络质量检测中'));

      // 第二次检测 - 应该不推荐（历史记录不足）
      recommendation = await advisor.shouldRecommendHotspotWith(poorNetworkQuality);
      expect(recommendation.shouldRecommendHotspot, isFalse);
      expect(recommendation.reason, contains('网络质量检测中'));

      // 第三次检测 - 应该推荐（连续3次弱网）
      recommendation = await advisor.shouldRecommendHotspotWith(poorNetworkQuality);
      expect(recommendation.shouldRecommendHotspot, isTrue);
      expect(recommendation.reason, contains('弱网环境'));
    });

    test('should handle mixed network conditions in debounce', () async {
      final poorQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      final goodQuality = NetworkQuality(
        bandwidthMbps: 10.0,
        packetLossRate: 1.0,
        avgDelayMs: 20.0,
        timestamp: DateTime.now(),
      );

      // 设置模拟推理返回 false 表示强网
      when(() => mockTFLiteEvaluator.simulateInference(goodQuality))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.7,
            qualityScore: 0.8,
            shouldRecommendHotspot: false,
            modelVersion: 'simulated_1.0.0',
          ));

      // 两次弱网，一次强网 - 应该不推荐
      await advisor.shouldRecommendHotspotWith(poorQuality);
      await advisor.shouldRecommendHotspotWith(poorQuality);
      final recommendation = await advisor.shouldRecommendHotspotWith(goodQuality);

      expect(recommendation.shouldRecommendHotspot, isFalse);
      expect(recommendation.reason, contains('网络质量不稳定'));
    });

    test('should get bandwidth threshold by scene', () {
      // 测试默认阈值
      when(() => mockConfigService.get<double>(any())).thenReturn(1.0);

      // 通用场景
      advisor.updateScene(AIScene.general);
      // 阈值应该在 1.0 左右

      // 制造车间场景
      advisor.updateScene(AIScene.manufacturing);
      // 阈值应该在 0.8 左右

      // 高校实验室场景
      advisor.updateScene(AIScene.education);
      // 阈值应该在 1.2 左右
    });

    test('should get TFLite model info', () {
      final modelInfo = advisor.getTFLiteModelInfo();
      
      expect(modelInfo, isNotNull);
      expect(modelInfo['loaded'], isFalse);
      expect(modelInfo['modelPath'], 'assets/models/network_quality_model.tflite');
    });

    test('should clear history correctly', () {
      // 添加一些历史记录
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 记录用户拒绝
      advisor.recordUserRejection();
      expect(advisor.lastUserRejection, isNotNull);

      // 清空历史
      advisor.clearHistory();
      expect(advisor.lastUserRejection, isNull);
      expect(advisor.weakNetworkHistory, isEmpty);
    });

    test('should handle TFLite model loading failure gracefully', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 设置 TFLite 加载失败
      when(() => mockTFLiteEvaluator.isModelLoaded).thenReturn(false);
      when(() => mockTFLiteEvaluator.loadModel()).thenAnswer((_) async => false);
      when(() => mockTFLiteEvaluator.simulateInference(any()))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.7,
            qualityScore: 0.3,
            shouldRecommendHotspot: true,
            modelVersion: 'simulated_1.0.0',
          ));

      // 需要连续调用3次才能触发推荐（防抖机制）
      await advisor.shouldRecommendHotspotWith(networkQuality);
      await advisor.shouldRecommendHotspotWith(networkQuality);
      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      // 应该使用模拟推理
      expect(recommendation.shouldRecommendHotspot, isTrue);
    });

    test('should handle TFLite inference exception', () async {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
        timestamp: DateTime.now(),
      );

      // 设置 TFLite 推理抛出异常
      when(() => mockTFLiteEvaluator.isModelLoaded).thenReturn(true);
      when(() => mockTFLiteEvaluator.infer(any()))
          .thenThrow(Exception('TFLite inference failed'));
      when(() => mockTFLiteEvaluator.simulateInference(any()))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.6,
            qualityScore: 0.4,
            shouldRecommendHotspot: false,
            modelVersion: 'simulated_1.0.0',
          ));

      final recommendation = await advisor.shouldRecommendHotspotWith(networkQuality);

      // 应该回退到模拟推理
      expect(recommendation.shouldRecommendHotspot, isFalse);
    });
  });

  group('AIRecommendation', () {
    test('should create with valid values', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 5.0,
        packetLossRate: 2.0,
        avgDelayMs: 30.0,
        timestamp: DateTime.now(),
      );

      final recommendation = AIRecommendation(
        shouldRecommendHotspot: true,
        reason: '弱网环境',
        networkQuality: networkQuality,
        timestamp: DateTime.now(),
      );

      expect(recommendation.shouldRecommendHotspot, isTrue);
      expect(recommendation.reason, '弱网环境');
      expect(recommendation.networkQuality, networkQuality);
      expect(recommendation.timestamp, isA<DateTime>());
    });

    test('should have correct string representation', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 5.0,
        packetLossRate: 2.0,
        avgDelayMs: 30.0,
        timestamp: DateTime.now(),
      );

      final recommendation = AIRecommendation(
        shouldRecommendHotspot: false,
        reason: '网络质量正常',
        networkQuality: networkQuality,
        timestamp: DateTime.now(),
      );

      final str = recommendation.toString();
      expect(str, contains('recommend: false'));
      expect(str, contains('reason: 网络质量正常'));
    });
  });

  group('AIScene', () {
    test('should have correct enum values', () {
      expect(AIScene.values.length, 3);
      expect(AIScene.general.name, 'general');
      expect(AIScene.manufacturing.name, 'manufacturing');
      expect(AIScene.education.name, 'education');
    });
  });
}
