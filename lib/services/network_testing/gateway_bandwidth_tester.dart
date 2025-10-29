import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 测速阶段枚举
enum Phase {
  fastJudge,  // 快速判断阶段（2秒）
  extended,   // 扩展测试阶段（2-10秒）
  finished    // 测试完成
}

/// 带宽测速进度数据
class BandwidthProgress {
  final int elapsedMs;          // 已耗时（毫秒）
  final double instSpeedMbps;   // 即时速率（Mbps）
  final Phase phase;            // 当前阶段
  final double? bandwidthMbps;  // 最终带宽（仅在完成阶段有值）

  const BandwidthProgress({
    required this.elapsedMs,
    required this.instSpeedMbps,
    required this.phase,
    this.bandwidthMbps,
  });

  @override
  String toString() {
    return 'BandwidthProgress(elapsed: ${elapsedMs}ms, speed: ${instSpeedMbps.toStringAsFixed(2)}Mbps, phase: $phase)';
  }
}

/// 上游网关带宽测速器
/// 采用动态截断算法：2秒快速判断，弱网则立即返回，强网则继续测试到10秒
class GatewayBandwidthTester {
  final String gatewayIp;
  final int port;
  final double weakThresholdMbps;

  static const int _testDataSize = 100 * 1024; // 100KB测试数据
  static const Duration _fastJudgeDuration = Duration(seconds: 2);
  static const Duration _maxDuration = Duration(seconds: 10);
  static const Duration _progressInterval = Duration(milliseconds: 200);

  GatewayBandwidthTester(
    this.gatewayIp, {
    required this.weakThresholdMbps,
    this.port = 80,
  });

  /// 执行带宽测速，返回进度事件流
  Stream<BandwidthProgress> measure({Duration maxDuration = const Duration(seconds: 10)}) async* {
    final controller = StreamController<BandwidthProgress>();
    final stopwatch = Stopwatch()..start();
    final random = Random();

    try {
      // 创建测试数据
      final testData = Uint8List(_testDataSize);
      for (int i = 0; i < _testDataSize; i++) {
        testData[i] = random.nextInt(256);
      }

      // 建立HTTP连接
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      // 发送测速请求
      final uri = Uri(
        scheme: 'http',
        host: gatewayIp,
        port: port,
        path: '/speedtest',
      );

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/octet-stream');
      request.contentLength = _testDataSize;

      // 开始发送数据
      final sink = request;
      sink.add(testData);
      await sink.flush();
      await sink.close();

      final response = await request.done;
      
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('网关响应异常: ${response.statusCode}');
      }

      // 读取响应数据并计算带宽
      final totalBytes = _testDataSize;
      int receivedBytes = 0;
      final List<double> speedSamples = [];

      // 进度更新定时器
      final progressTimer = Timer.periodic(_progressInterval, (timer) async {
        final elapsedMs = stopwatch.elapsedMilliseconds;
        final currentPhase = _getCurrentPhase(elapsedMs);
        
        // 计算即时速率
        double instSpeedMbps = 0.0;
        if (elapsedMs > 0) {
          instSpeedMbps = (receivedBytes * 8) / (elapsedMs * 1000); // Mbps
        }

        // 添加速度样本
        if (instSpeedMbps > 0) {
          speedSamples.add(instSpeedMbps);
        }

        // 检查是否需要提前结束（弱网快速判断）
        if (currentPhase == Phase.fastJudge && 
            speedSamples.length >= 3 && 
            _shouldEarlyTerminate(speedSamples, weakThresholdMbps)) {
          timer.cancel();
          final avgSpeed = _calculateAverageSpeed(speedSamples);
          controller.add(BandwidthProgress(
            elapsedMs: elapsedMs,
            instSpeedMbps: avgSpeed,
            phase: Phase.finished,
            bandwidthMbps: avgSpeed,
          ));
          controller.close();
          return;
        }

        // 检查是否超时
        if (elapsedMs >= maxDuration.inMilliseconds) {
          timer.cancel();
          final avgSpeed = _calculateAverageSpeed(speedSamples);
          controller.add(BandwidthProgress(
            elapsedMs: elapsedMs,
            instSpeedMbps: avgSpeed,
            phase: Phase.finished,
            bandwidthMbps: avgSpeed,
          ));
          controller.close();
          return;
        }

        // 发送进度更新
        controller.add(BandwidthProgress(
          elapsedMs: elapsedMs,
          instSpeedMbps: instSpeedMbps,
          phase: currentPhase,
        ));
      });

      // 读取响应数据
      final responseStream = response;
      await for (final data in responseStream) {
        receivedBytes += data.length;
      }

      // 完成测速
      progressTimer.cancel();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgSpeed = _calculateAverageSpeed(speedSamples);
      
      controller.add(BandwidthProgress(
        elapsedMs: elapsedMs,
        instSpeedMbps: avgSpeed,
        phase: Phase.finished,
        bandwidthMbps: avgSpeed,
      ));
      controller.close();

    } catch (e) {
      // 测速失败，返回0带宽
      final elapsedMs = stopwatch.elapsedMilliseconds;
      controller.add(BandwidthProgress(
        elapsedMs: elapsedMs,
        instSpeedMbps: 0.0,
        phase: Phase.finished,
        bandwidthMbps: 0.0,
      ));
      controller.close();
    }
  }

  /// 根据耗时获取当前阶段
  Phase _getCurrentPhase(int elapsedMs) {
    if (elapsedMs < _fastJudgeDuration.inMilliseconds) {
      return Phase.fastJudge;
    } else if (elapsedMs < _maxDuration.inMilliseconds) {
      return Phase.extended;
    } else {
      return Phase.finished;
    }
  }

  /// 判断是否需要提前结束测速（弱网快速判断）
  bool _shouldEarlyTerminate(List<double> speedSamples, double threshold) {
    if (speedSamples.length < 3) return false;
    
    // 取最近3个样本的平均值
    final recentSamples = speedSamples.sublist(speedSamples.length - 3);
    final avgSpeed = recentSamples.reduce((a, b) => a + b) / recentSamples.length;
    
    // 如果平均速度低于阈值，提前结束
    return avgSpeed < threshold;
  }

  /// 计算平均速度（去除离群值）
  double _calculateAverageSpeed(List<double> speedSamples) {
    if (speedSamples.isEmpty) return 0.0;
    
    // 去除最高和最低的20%样本
    final sortedSamples = List<double>.from(speedSamples)..sort();
    final removeCount = (sortedSamples.length * 0.2).round();
    final validSamples = sortedSamples.sublist(
      removeCount, 
      sortedSamples.length - removeCount
    );
    
    if (validSamples.isEmpty) return 0.0;
    
    return validSamples.reduce((a, b) => a + b) / validSamples.length;
  }

  /// 简化的测速方法（返回最终带宽）
  Future<double> measureBandwidth() async {
    final stream = measure();
    final lastProgress = await stream.last;
    return lastProgress.bandwidthMbps ?? 0.0;
  }
}
