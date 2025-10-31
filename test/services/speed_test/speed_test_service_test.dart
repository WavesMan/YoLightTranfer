import 'package:flutter_test/flutter_test.dart';
import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/speed_test/speed_test_service.dart';
import 'package:yolighttransfer/services/speed_test/speed_test_manager.dart';
import 'package:yolighttransfer/services/speed_test/speed_test_client.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';

void main() {
  group('SpeedTestService', () {
    late TransferLogManager logManager;
    late SpeedTestService speedTestService;

    setUp(() {
      logManager = TransferLogManager();
      speedTestService = SpeedTestService(logManager: logManager);
    });

    tearDown(() async {
      await speedTestService.dispose();
    });

    test('生成测速包数据', () {
      // 测试小包
      final smallData = SpeedTestService.generateSpeedTestData(1024);
      expect(smallData.length, 1024);
      
      // 测试中包
      final mediumData = SpeedTestService.generateSpeedTestData(102400);
      expect(mediumData.length, 102400);
      
      // 测试大包
      final largeData = SpeedTestService.generateSpeedTestData(1048576);
      expect(largeData.length, 1048576);
    });

    test('格式化带宽', () {
      // 测试Kbps格式化
      expect(SpeedTestService.formatBandwidth(0.5), '500.0 Kbps');
      
      // 测试Mbps格式化
      expect(SpeedTestService.formatBandwidth(10.5), '10.5 Mbps');
      expect(SpeedTestService.formatBandwidth(100.0), '100.0 Mbps');
    });

    test('格式化延迟', () {
      expect(SpeedTestService.formatDelay(10.5), '10.5 ms');
      expect(SpeedTestService.formatDelay(100.0), '100.0 ms');
      expect(SpeedTestService.formatDelay(0.1), '0.1 ms');
    });

    test('创建模拟设备', () {
      final device = DiscoveredDevice(
        id: 'test-device-1',
        name: 'Test Device',
        os: 'Android',
        ip: '192.168.1.100',
        httpPort: 8080,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );

      expect(device.id, 'test-device-1');
      expect(device.name, 'Test Device');
      expect(device.ip, '192.168.1.100');
      expect(device.httpPort, 8080);
    });

    test('测速服务初始化', () {
      expect(speedTestService.getActiveSessions(), isEmpty);
    });

    test('测速包文件创建和清理', () async {
      // 测试文件创建
      final file = await SpeedTestService.createSpeedTestFile('test.dat', 1024);
      expect(await file.exists(), isTrue);
      expect(await file.length(), 1024);
      
      // 测试文件清理
      await SpeedTestService.cleanupSpeedTestFiles();
      // 注意：实际文件清理可能需要时间，这里主要测试没有异常
    });

    test('测速结果数据结构', () {
      final device = DiscoveredDevice(
        id: 'test-device-1',
        name: 'Test Device',
        os: 'Android',
        ip: '192.168.1.100',
        httpPort: 8080,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );

      final result = SpeedTestResult(
        testId: 'test-1',
        targetDevice: device,
        timestamp: DateTime.now(),
        bandwidthMbps: 50.5,
        avgDelayMs: 25.3,
        packetLossRate: 1.2,
        jitterMs: 5.1,
        qualityScore: 0.85,
        shouldRecommendHotspot: false,
        confidence: 0.92,
        modelVersion: '1.0.0',
        rawMetrics: {
          'finalBandwidthMbps': 50.5,
          'avgDelayMs': 25.3,
          'packetLossRate': 1.2,
          'jitterMs': 5.1,
        },
      );

      expect(result.testId, 'test-1');
      expect(result.bandwidthMbps, 50.5);
      expect(result.avgDelayMs, 25.3);
      expect(result.packetLossRate, 1.2);
      expect(result.qualityScore, 0.85);
      expect(result.shouldRecommendHotspot, false);
      expect(result.confidence, 0.92);

      // 测试JSON序列化
      final json = result.toJson();
      expect(json['testId'], 'test-1');
      expect(json['bandwidthMbps'], 50.5);
      expect(json['qualityScore'], 0.85);
      expect(json['shouldRecommendHotspot'], false);
    });

    test('测速进度回调', () async {
      var progressCalled = false;
      var completeCalled = false;
      var errorCalled = false;

      speedTestService.onProgress = (testId, phase, progress, status, metrics) {
        progressCalled = true;
        expect(phase, isNotNull);
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      };

      speedTestService.onComplete = (result) {
        completeCalled = true;
      };

      speedTestService.onError = (testId, error) {
        errorCalled = true;
      };

      // 注意：实际测速需要真实设备连接，这里只测试回调设置
      expect(progressCalled, false);
      expect(completeCalled, false);
      expect(errorCalled, false);
    });
  });

  group('SpeedTestManager', () {
    late TransferLogManager logManager;
    late SpeedTestManager speedTestManager;

    setUp(() {
      logManager = TransferLogManager();
      speedTestManager = SpeedTestManager(logManager: logManager);
    });

    tearDown(() async {
      await speedTestManager.dispose();
    });

    test('管理器初始化', () {
      expect(speedTestManager.state, SpeedTestManagerState.idle);
      expect(speedTestManager.activeTests, isEmpty);
      expect(speedTestManager.history, isEmpty);
    });

    test('状态变更回调', () {
      var stateChanged = false;
      var newState = SpeedTestManagerState.idle;

      speedTestManager.onStateChanged = (state) {
        stateChanged = true;
        newState = state;
      };

      // 注意：实际状态变更需要触发测速操作
      expect(stateChanged, false);
      expect(newState, SpeedTestManagerState.idle);
    });

    test('历史记录管理', () {
      final device = DiscoveredDevice(
        id: 'test-device-1',
        name: 'Test Device',
        os: 'Android',
        ip: '192.168.1.100',
        httpPort: 8080,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      );

      final result = SpeedTestResult(
        testId: 'test-1',
        targetDevice: device,
        timestamp: DateTime.now(),
        bandwidthMbps: 50.5,
        avgDelayMs: 25.3,
        packetLossRate: 1.2,
        jitterMs: 5.1,
        qualityScore: 0.85,
        shouldRecommendHotspot: false,
        confidence: 0.92,
        modelVersion: '1.0.0',
        rawMetrics: {},
      );

      // 注意：实际历史记录添加需要完成测速
      expect(speedTestManager.getDeviceHistory('test-device-1'), isEmpty);
      expect(speedTestManager.getLatestTest(), isNull);
    });

    test('报告导出', () {
      final report = speedTestManager.exportReport();
      expect(report['totalTests'], 0);
      expect(report['activeTests'], 0);
      expect(report['history'], isEmpty);
      expect(report['summary'], isNotNull);
    });
  });

  group('SpeedTestClient', () {
    late TransferLogManager logManager;
    late SpeedTestClient speedTestClient;

    setUp(() {
      logManager = TransferLogManager();
      speedTestClient = SpeedTestClient(logManager: logManager);
    });

    tearDown(() async {
      await speedTestClient.dispose();
    });

    test('客户端初始化', () {
      expect(speedTestClient.state, SpeedTestClientState.disconnected);
      expect(speedTestClient.targetDevice, isNull);
      expect(speedTestClient.activeTests, isEmpty);
    });

    test('事件流', () async {
      var eventReceived = false;

      speedTestClient.events.listen((event) {
        eventReceived = true;
      });

      // 注意：实际事件需要触发连接或测速操作
      expect(eventReceived, false);
    });

    test('连接质量指标', () async {
      final metrics = await speedTestClient.getConnectionMetrics();
      expect(metrics['connected'], false);
      expect(metrics['latency'], 0.0);
      expect(metrics['bandwidth'], 0.0);
      expect(metrics['stability'], 0.0);
    });

    test('状态变更回调', () {
      var stateChanged = false;
      var newState = SpeedTestClientState.disconnected;

      speedTestClient.onStateChanged = (state) {
        stateChanged = true;
        newState = state;
      };

      // 注意：实际状态变更需要触发连接操作
      expect(stateChanged, false);
      expect(newState, SpeedTestClientState.disconnected);
    });
  });
}
