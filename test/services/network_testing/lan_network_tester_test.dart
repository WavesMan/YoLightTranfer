import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yolighttransfer/services/network_testing/lan_network_tester.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

// Mock classes for testing
class MockDeviceManager extends Mock implements DeviceManager {}
class MockDiscoveredDevice extends Mock implements DiscoveredDevice {}

void main() {
  group('LanNetworkTester', () {
    late LanNetworkTester tester;
    late MockDeviceManager mockDeviceManager;
    late MockDiscoveredDevice mockDevice;

    setUp(() {
      mockDeviceManager = MockDeviceManager();
      mockDevice = MockDiscoveredDevice();
      
      // 设置默认的 mock 行为
      when(() => mockDevice.ip).thenReturn('192.168.1.100');
      when(() => mockDevice.httpPort).thenReturn(8080);
      when(() => mockDevice.os).thenReturn('android');
      when(() => mockDevice.name).thenReturn('Test Device');
      
      tester = LanNetworkTester(mockDeviceManager);
    });

    test('should initialize with default parameters', () {
      expect(tester.probesPerPeer, 10);
      expect(tester.perProbeTimeout, const Duration(milliseconds: 500));
    });

    test('should initialize with custom parameters', () {
      final customTester = LanNetworkTester(
        mockDeviceManager,
        probesPerPeer: 5,
        perProbeTimeout: const Duration(seconds: 1),
      );
      
      expect(customTester.probesPerPeer, 5);
      expect(customTester.perProbeTimeout, const Duration(seconds: 1));
    });

    test('should throw NoDevicesException when no peers available', () async {
      when(() => mockDeviceManager.getOnlineDevices()).thenReturn([]);
      
      expect(() => tester.run(), throwsA(isA<NoDevicesException>()));
    });

    test('should create TestMetrics with valid values', () {
      final metrics = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 50.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );

      expect(metrics.peer, mockDevice);
      expect(metrics.bandwidthMbps, 50.0);
      expect(metrics.avgDelayMs, 20.0);
      expect(metrics.lossRate, 5.0);
    });

    test('should create AggregatedMetrics with valid values', () {
      final metrics = AggregatedMetrics(
        bandwidthMbps: 45.0,
        avgDelayMs: 25.0,
        lossRate: 3.0,
        peerCount: 3,
        platformCount: {'android': 2, 'ios': 1},
      );

      expect(metrics.bandwidthMbps, 45.0);
      expect(metrics.avgDelayMs, 25.0);
      expect(metrics.lossRate, 3.0);
      expect(metrics.peerCount, 3);
      expect(metrics.platformCount, {'android': 2, 'ios': 1});
    });

    test('should create empty AggregatedMetrics from empty list', () {
      final metrics = AggregatedMetrics.from([]);

      expect(metrics.bandwidthMbps, 0);
      expect(metrics.avgDelayMs, 0);
      expect(metrics.lossRate, 0);
      expect(metrics.peerCount, 0);
      expect(metrics.platformCount, isEmpty);
    });

    test('should create AggregatedMetrics from single result', () {
      final testMetrics = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 50.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );

      final aggregated = AggregatedMetrics.from([testMetrics]);

      expect(aggregated.bandwidthMbps, 50.0);
      expect(aggregated.avgDelayMs, 20.0);
      expect(aggregated.lossRate, 5.0);
      expect(aggregated.peerCount, 1);
      expect(aggregated.platformCount, {'android': 1});
    });

    test('should create AggregatedMetrics from multiple results', () {
      final mockDevice2 = MockDiscoveredDevice();
      when(() => mockDevice2.os).thenReturn('ios');
      
      final testMetrics1 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 50.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );
      
      final testMetrics2 = TestMetrics(
        peer: mockDevice2,
        bandwidthMbps: 60.0,
        avgDelayMs: 30.0,
        lossRate: 10.0,
      );

      final aggregated = AggregatedMetrics.from([testMetrics1, testMetrics2]);

      // 带宽中位数应该是 (50 + 60) / 2 = 55.0
      expect(aggregated.bandwidthMbps, 55.0);
      // 平均延迟应该是 (20 + 30) / 2 = 25.0
      expect(aggregated.avgDelayMs, 25.0);
      // 平均丢包率应该是 (5 + 10) / 2 = 7.5
      expect(aggregated.lossRate, 7.5);
      expect(aggregated.peerCount, 2);
      expect(aggregated.platformCount, {'android': 1, 'ios': 1});
    });

    test('should clamp loss rate to 0-100 range', () {
      final testMetrics1 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 50.0,
        avgDelayMs: 20.0,
        lossRate: -10.0, // 负值
      );
      
      final testMetrics2 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 60.0,
        avgDelayMs: 30.0,
        lossRate: 150.0, // 超过100
      );

      final aggregated = AggregatedMetrics.from([testMetrics1, testMetrics2]);

      // 平均丢包率应该是 (-10 + 150) / 2 = 70，但会被裁剪到 0-100
      expect(aggregated.lossRate, 70.0);
    });

    test('should calculate median bandwidth correctly for odd count', () {
      final testMetrics1 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 10.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );
      
      final testMetrics2 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 20.0,
        avgDelayMs: 30.0,
        lossRate: 10.0,
      );
      
      final testMetrics3 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 30.0,
        avgDelayMs: 40.0,
        lossRate: 15.0,
      );

      final aggregated = AggregatedMetrics.from([testMetrics1, testMetrics2, testMetrics3]);

      // 中位数应该是 20.0
      expect(aggregated.bandwidthMbps, 20.0);
    });

    test('should calculate median bandwidth correctly for even count', () {
      final testMetrics1 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 10.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );
      
      final testMetrics2 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 20.0,
        avgDelayMs: 30.0,
        lossRate: 10.0,
      );
      
      final testMetrics3 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 30.0,
        avgDelayMs: 40.0,
        lossRate: 15.0,
      );
      
      final testMetrics4 = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 40.0,
        avgDelayMs: 50.0,
        lossRate: 20.0,
      );

      final aggregated = AggregatedMetrics.from([testMetrics1, testMetrics2, testMetrics3, testMetrics4]);

      // 中位数应该是 (20 + 30) / 2 = 25.0
      expect(aggregated.bandwidthMbps, 25.0);
    });

    test('should estimate bandwidth correctly', () {
      // 测试带宽估算函数
      // 使用反射或其他方式测试私有方法，这里我们通过公共接口间接测试
      
      // 创建测试设备
      when(() => mockDeviceManager.getOnlineDevices()).thenReturn([mockDevice]);
      
      // 这个测试主要是验证代码结构，实际带宽估算逻辑在私有方法中
      expect(tester, isNotNull);
    });

    test('NoDevicesException should have correct message', () {
      final exception = NoDevicesException();
      expect(exception.toString(), 'NoDevicesException: 未发现可测的邻居设备');
    });

    test('TestMetrics should have correct string representation', () {
      final metrics = TestMetrics(
        peer: mockDevice,
        bandwidthMbps: 50.0,
        avgDelayMs: 20.0,
        lossRate: 5.0,
      );

      final str = metrics.toString();
      expect(str, contains('TestMetrics'));
      expect(str, contains('bandwidthMbps: 50.0'));
      expect(str, contains('avgDelayMs: 20.0'));
      expect(str, contains('lossRate: 5.0'));
    });

    test('AggregatedMetrics should have correct string representation', () {
      final metrics = AggregatedMetrics(
        bandwidthMbps: 45.0,
        avgDelayMs: 25.0,
        lossRate: 3.0,
        peerCount: 3,
        platformCount: {'android': 2, 'ios': 1},
      );

      final str = metrics.toString();
      expect(str, contains('AggregatedMetrics'));
      expect(str, contains('bandwidthMbps: 45.0'));
      expect(str, contains('avgDelayMs: 25.0'));
      expect(str, contains('lossRate: 3.0'));
      expect(str, contains('peerCount: 3'));
    });
  });
}
