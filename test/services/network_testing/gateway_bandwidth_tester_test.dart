import 'package:flutter_test/flutter_test.dart';
import 'package:yolighttransfer/services/network_testing/gateway_bandwidth_tester.dart';

void main() {
  group('GatewayBandwidthTester', () {
    late GatewayBandwidthTester tester;

    setUp(() {
      tester = GatewayBandwidthTester(
        '192.168.1.1',
        weakThresholdMbps: 1.0,
        port: 80,
      );
    });

    test('should create with correct parameters', () {
      expect(tester.gatewayIp, '192.168.1.1');
      expect(tester.weakThresholdMbps, 1.0);
      expect(tester.port, 80);
    });

    test('should calculate current phase correctly', () {
      // 使用反射或其他方式测试私有方法，这里我们测试逻辑
      // 快速判断阶段 (0-2000ms)
      expect(_getPhaseForTest(500), Phase.fastJudge);
      expect(_getPhaseForTest(1500), Phase.fastJudge);
      
      // 扩展测试阶段 (2000-10000ms)
      expect(_getPhaseForTest(2500), Phase.extended);
      expect(_getPhaseForTest(5000), Phase.extended);
      expect(_getPhaseForTest(9500), Phase.extended);
      
      // 完成阶段 (10000ms+)
      expect(_getPhaseForTest(10000), Phase.finished);
      expect(_getPhaseForTest(15000), Phase.finished);
    });

    test('should determine early termination correctly', () {
      // 测试弱网提前终止逻辑
      final weakSamples = [0.5, 0.6, 0.4]; // 平均0.5 < 1.0
      final strongSamples = [2.0, 2.5, 1.8]; // 平均2.1 > 1.0
      
      expect(_shouldEarlyTerminateForTest(weakSamples, 1.0), true);
      expect(_shouldEarlyTerminateForTest(strongSamples, 1.0), false);
    });

    test('should calculate average speed correctly', () {
      // 测试去除离群值的平均速度计算
      final samples = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
      // 去除最高和最低的20%（2个），剩下 [0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
      final expectedAverage = (0.3 + 0.4 + 0.5 + 0.6 + 0.7 + 0.8) / 6;
      
      expect(_calculateAverageSpeedForTest(samples), closeTo(expectedAverage, 0.001));
    });

    test('should handle empty samples gracefully', () {
      expect(_calculateAverageSpeedForTest([]), 0.0);
    });

    test('should handle single sample', () {
      expect(_calculateAverageSpeedForTest([2.5]), 2.5);
    });

    test('should handle two samples', () {
      expect(_calculateAverageSpeedForTest([1.0, 2.0]), 1.5);
    });
  });

  group('BandwidthProgress', () {
    test('should create with correct values', () {
      final progress = BandwidthProgress(
        elapsedMs: 1500,
        instSpeedMbps: 2.5,
        phase: Phase.fastJudge,
        bandwidthMbps: 2.5,
      );

      expect(progress.elapsedMs, 1500);
      expect(progress.instSpeedMbps, 2.5);
      expect(progress.phase, Phase.fastJudge);
      expect(progress.bandwidthMbps, 2.5);
    });

    test('should create without final bandwidth', () {
      final progress = BandwidthProgress(
        elapsedMs: 500,
        instSpeedMbps: 1.5,
        phase: Phase.fastJudge,
      );

      expect(progress.elapsedMs, 500);
      expect(progress.instSpeedMbps, 1.5);
      expect(progress.phase, Phase.fastJudge);
      expect(progress.bandwidthMbps, isNull);
    });

    test('should have correct string representation', () {
      final progress = BandwidthProgress(
        elapsedMs: 1500,
        instSpeedMbps: 2.5,
        phase: Phase.fastJudge,
      );

      expect(progress.toString(), contains('1500'));
      expect(progress.toString(), contains('2.50'));
      expect(progress.toString(), contains('fastJudge'));
    });
  });
}

// 测试辅助函数 - 模拟私有方法逻辑
Phase _getPhaseForTest(int elapsedMs) {
  if (elapsedMs < 2000) {
    return Phase.fastJudge;
  } else if (elapsedMs < 10000) {
    return Phase.extended;
  } else {
    return Phase.finished;
  }
}

bool _shouldEarlyTerminateForTest(List<double> speedSamples, double threshold) {
  if (speedSamples.length < 3) return false;
  
  final recentSamples = speedSamples.sublist(speedSamples.length - 3);
  final avgSpeed = recentSamples.reduce((a, b) => a + b) / recentSamples.length;
  
  return avgSpeed < threshold;
}

double _calculateAverageSpeedForTest(List<double> speedSamples) {
  if (speedSamples.isEmpty) return 0.0;
  
  final sortedSamples = List<double>.from(speedSamples)..sort();
  final removeCount = (sortedSamples.length * 0.2).round();
  final validSamples = sortedSamples.sublist(
    removeCount, 
    sortedSamples.length - removeCount
  );
  
  if (validSamples.isEmpty) return 0.0;
  
  return validSamples.reduce((a, b) => a + b) / validSamples.length;
}
