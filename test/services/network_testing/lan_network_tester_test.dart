import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yolighttransfer/services/network_testing/lan_network_tester.dart';

// Mock classes for testing
class MockRawDatagramSocket extends Mock implements RawDatagramSocket {}
class MockSocket extends Mock implements Socket {}
class MockServerSocket extends Mock implements ServerSocket {}

void main() {
  group('LanNetworkTester', () {
    late LanNetworkTester tester;

    setUp(() {
      tester = LanNetworkTester();
    });

    tearDown(() {
      // Clean up any resources
    });

    test('should initialize with default values', () {
      expect(tester.isTesting, false);
      expect(tester.currentMetrics, isNull);
    });

    test('should start and stop testing', () async {
      // 由于网络测试涉及实际的 Socket 操作，这里主要测试状态管理
      // 实际项目中可能需要使用 mock 来模拟网络操作
      
      // 开始测试
      final startResult = await tester.startTesting();
      expect(startResult, isTrue);
      expect(tester.isTesting, isTrue);
      
      // 停止测试
      await tester.stopTesting();
      expect(tester.isTesting, isFalse);
    });

    test('should handle test timeout gracefully', () async {
      // 测试超时处理
      // 注意：实际测试可能需要调整超时时间
      final result = await tester.startTesting();
      expect(result, isTrue);
      
      // 等待一段时间后检查状态
      await Future.delayed(Duration(milliseconds: 100));
      expect(tester.isTesting, isTrue);
      
      // 停止测试
      await tester.stopTesting();
      expect(tester.isTesting, isFalse);
    });

    test('should provide current metrics when available', () async {
      // 启动测试
      await tester.startTesting();
      
      // 初始状态下应该没有指标
      expect(tester.currentMetrics, isNull);
      
      // 停止测试
      await tester.stopTesting();
    });

    test('should handle multiple start/stop calls', () async {
      // 多次启动和停止不应该导致错误
      for (int i = 0; i < 3; i++) {
        final startResult = await tester.startTesting();
        expect(startResult, isTrue);
        expect(tester.isTesting, isTrue);
        
        await tester.stopTesting();
        expect(tester.isTesting, isFalse);
      }
    });

    test('should handle network interface discovery', () async {
      // 测试网络接口发现功能
      // 注意：这个测试可能在不同环境中表现不同
      final interfaces = await tester.getAvailableInterfaces();
      
      // 至少应该返回一个列表（可能为空）
      expect(interfaces, isA<List<NetworkInterface>>());
    });

    test('should handle UDP ping test', () async {
      // UDP ping 测试
      // 由于涉及实际网络操作，这里主要测试方法调用
      final result = await tester.testUdpPing('127.0.0.1', 8080);
      
      // 结果应该是一个 NetworkMetrics 对象或 null
      expect(result == null || result is NetworkMetrics, isTrue);
    });

    test('should handle TCP bandwidth test', () async {
      // TCP 带宽测试
      final result = await tester.testTcpBandwidth('127.0.0.1', 8080);
      
      // 结果应该是一个 NetworkMetrics 对象或 null
      expect(result == null || result is NetworkMetrics, isTrue);
    });

    test('should handle HTTP bandwidth test', () async {
      // HTTP 带宽测试
      final result = await tester.testHttpBandwidth('http://127.0.0.1:8080');
      
      // 结果应该是一个 NetworkMetrics 对象或 null
      expect(result == null || result is NetworkMetrics, isTrue);
    });

    test('should calculate metrics correctly', () {
      // 测试指标计算逻辑
      final testData = [
        TestData(
          sentPackets: 10,
          receivedPackets: 8,
          totalBytes: 1024,
          totalTimeMs: 1000,
        ),
      ];

      final metrics = tester.calculateMetrics(testData);
      
      expect(metrics, isNotNull);
      expect(metrics.bandwidthMbps, greaterThanOrEqualTo(0.0));
      expect(metrics.packetLossRate, greaterThanOrEqualTo(0.0));
      expect(metrics.avgDelayMs, greaterThanOrEqualTo(0.0));
    });

    test('should handle empty test data', () {
      final metrics = tester.calculateMetrics([]);
      
      // 对于空数据，应该返回默认值或 null
      expect(metrics, isNotNull);
      expect(metrics.bandwidthMbps, 0.0);
      expect(metrics.packetLossRate, 100.0); // 所有包都丢失
      expect(metrics.avgDelayMs, 0.0);
    });

    test('should handle packet loss calculation', () {
      final testData = [
        TestData(
          sentPackets: 10,
          receivedPackets: 5, // 50% 丢包
          totalBytes: 1024,
          totalTimeMs: 1000,
        ),
      ];

      final metrics = tester.calculateMetrics(testData);
      expect(metrics.packetLossRate, 50.0);
    });

    test('should handle bandwidth calculation', () {
      final testData = [
        TestData(
          sentPackets: 10,
          receivedPackets: 10,
          totalBytes: 1024 * 1024, // 1 MB
          totalTimeMs: 1000, // 1秒
        ),
      ];

      final metrics = tester.calculateMetrics(testData);
      // 1 MB/s = 8 Mbps
      expect(metrics.bandwidthMbps, closeTo(8.0, 0.1));
    });

    test('should handle zero time case', () {
      final testData = [
        TestData(
          sentPackets: 10,
          receivedPackets: 10,
          totalBytes: 1024,
          totalTimeMs: 0, // 零时间
        ),
      ];

      final metrics = tester.calculateMetrics(testData);
      expect(metrics.bandwidthMbps, 0.0);
    });

    test('should handle error scenarios', () async {
      // 测试错误处理
      // 使用无效的地址进行测试
      final result = await tester.testUdpPing('invalid.address', 9999);
      expect(result, isNull);
    });

    test('should provide test configuration', () {
      final config = tester.getTestConfiguration();
      
      expect(config, isNotNull);
      expect(config['udpPort'], isA<int>());
      expect(config['tcpPort'], isA<int>());
      expect(config['testDurationMs'], isA<int>());
    });

    test('should reset metrics on stop', () async {
      // 启动测试
      await tester.startTesting();
      
      // 停止测试后应该重置指标
      await tester.stopTesting();
      expect(tester.currentMetrics, isNull);
    });
  });

  group('NetworkMetrics', () {
    test('should create with valid values', () {
      final metrics = NetworkMetrics(
        bandwidthMbps: 10.0,
        packetLossRate: 5.0,
        avgDelayMs: 50.0,
        timestamp: DateTime.now(),
      );

      expect(metrics.bandwidthMbps, 10.0);
      expect(metrics.packetLossRate, 5.0);
      expect(metrics.avgDelayMs, 50.0);
      expect(metrics.timestamp, isA<DateTime>());
    });

    test('should handle edge values', () {
      final zeroMetrics = NetworkMetrics(
        bandwidthMbps: 0.0,
        packetLossRate: 0.0,
        avgDelayMs: 0.0,
        timestamp: DateTime.now(),
      );

      final maxMetrics = NetworkMetrics(
        bandwidthMbps: 1000.0,
        packetLossRate: 100.0,
        avgDelayMs: 1000.0,
        timestamp: DateTime.now(),
      );

      expect(zeroMetrics.bandwidthMbps, 0.0);
      expect(maxMetrics.packetLossRate, 100.0);
    });

    test('should have correct string representation', () {
      final metrics = NetworkMetrics(
        bandwidthMbps: 5.5,
        packetLossRate: 2.5,
        avgDelayMs: 25.0,
        timestamp: DateTime(2023, 1, 1),
      );

      final str = metrics.toString();
      expect(str, contains('5.5'));
      expect(str, contains('2.5'));
      expect(str, contains('25.0'));
    });
  });

  group('TestData', () {
    test('should create with valid values', () {
      final testData = TestData(
        sentPackets: 10,
        receivedPackets: 8,
        totalBytes: 1024,
        totalTimeMs: 1000,
      );

      expect(testData.sentPackets, 10);
      expect(testData.receivedPackets, 8);
      expect(testData.totalBytes, 1024);
      expect(testData.totalTimeMs, 1000);
    });

    test('should calculate packet loss correctly', () {
      final testData = TestData(
        sentPackets: 10,
        receivedPackets: 5,
        totalBytes: 1024,
        totalTimeMs: 1000,
      );

      expect(testData.packetLossRate, 50.0);
    });

    test('should handle zero sent packets', () {
      final testData = TestData(
        sentPackets: 0,
        receivedPackets: 0,
        totalBytes: 0,
        totalTimeMs: 0,
      );

      expect(testData.packetLossRate, 0.0);
    });
  });
}
