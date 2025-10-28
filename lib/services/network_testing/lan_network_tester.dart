import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';

/// 异常：附近无设备
class NoDevicesException implements Exception {
  @override
  String toString() => 'NoDevicesException: 未发现可测的邻居设备';
}

/// 单台邻居设备的测试指标
class TestMetrics {
  final DiscoveredDevice peer;
  final double bandwidthMbps; // 估算带宽
  final double avgDelayMs; // 平均往返时间
  final double lossRate; // 丢包率（%）

  const TestMetrics({
    required this.peer,
    required this.bandwidthMbps,
    required this.avgDelayMs,
    required this.lossRate,
  });
}

/// 聚合后的测试指标
class AggregatedMetrics {
  final double bandwidthMbps; // 中位数/加权平均
  final double avgDelayMs; // 均值
  final double lossRate; // 均值（截断到 0~100）
  final int peerCount; // 采样设备数量
  final Map<String, int> platformCount; // 各平台数量统计

  const AggregatedMetrics({
    required this.bandwidthMbps,
    required this.avgDelayMs,
    required this.lossRate,
    required this.peerCount,
    required this.platformCount,
  });

  static AggregatedMetrics from(List<TestMetrics> results) {
    if (results.isEmpty) {
      return const AggregatedMetrics(
        bandwidthMbps: 0,
        avgDelayMs: 0,
        lossRate: 0,
        peerCount: 0,
        platformCount: {},
      );
    }

    // 带宽使用中位数抗离群值
    final bwList = results.map((e) => e.bandwidthMbps).toList()..sort();
    final medianBw = bwList.length.isOdd
        ? bwList[bwList.length ~/ 2]
        : (bwList[bwList.length ~/ 2 - 1] + bwList[bwList.length ~/ 2]) / 2.0;

    // 延迟与丢包率使用均值
    final avgDelay = results.map((e) => e.avgDelayMs).reduce((a, b) => a + b) / results.length;
    double loss = results.map((e) => e.lossRate).reduce((a, b) => a + b) / results.length;
    loss = loss.clamp(0, 100);

    // 平台统计
    final Map<String, int> platformCount = {};
    for (final r in results) {
      final p = r.peer.os.toLowerCase();
      platformCount[p] = (platformCount[p] ?? 0) + 1;
    }

    return AggregatedMetrics(
      bandwidthMbps: medianBw,
      avgDelayMs: avgDelay,
      lossRate: loss,
      peerCount: results.length,
      platformCount: platformCount,
    );
  }
}

/// 局域网主动测速器（MVP实现）
/// - 基于 HTTP GET /status 的往返时间作为 RTT 近似
/// - 将超时/连接错误视为丢包
/// - 带宽用启发式从 RTT/丢包估算，避免对端实现额外协议
class LanNetworkTester {
  final DeviceManager _deviceManager;

  // 每个 peer 的探测参数
  final int probesPerPeer;
  final Duration perProbeTimeout;

  LanNetworkTester(this._deviceManager, {
    this.probesPerPeer = 10,
    this.perProbeTimeout = const Duration(milliseconds: 500),
  });

  /// 对单个 peer 进行测试
  Future<TestMetrics> testTo(DiscoveredDevice peer) async {
    final delays = <int>[];
    int success = 0;

    for (int i = 0; i < probesPerPeer; i++) {
      final sw = Stopwatch()..start();
      try {
        final client = HttpClient();
        client.connectionTimeout = perProbeTimeout;
        // 访问 /status?fileName=__probe__，对端会返回 404 或 400，但可用于测时
        final uri = Uri(
          scheme: 'http',
          host: peer.ip,
          port: peer.httpPort,
          path: '/status',
          queryParameters: {'fileName': '__probe__'},
        );
        final req = await client.getUrl(uri).timeout(perProbeTimeout);
        final resp = await req.close().timeout(perProbeTimeout);
        // 只要有响应就算成功（200/404/400 都可）
        if (resp.statusCode > 0) {
          success++;
          delays.add(sw.elapsedMilliseconds);
        }
        await resp.drain();
        client.close();
      } catch (_) {
        // 失败视为丢包
      }
      // 两次探测间隔，避免拥塞
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 平均 RTT
    final avgDelayMs = delays.isEmpty
        ? perProbeTimeout.inMilliseconds.toDouble()
        : delays.reduce((a, b) => a + b) / delays.length;

    // 丢包率
    final lossRate = ((probesPerPeer - success) / probesPerPeer) * 100.0;

    // 启发式估算带宽（受 RTT 和丢包影响），限定 0~100 Mbps
    final bw = _estimateBandwidth(avgDelayMs: avgDelayMs, lossRate: lossRate);

    return TestMetrics(
      peer: peer,
      bandwidthMbps: bw,
      avgDelayMs: avgDelayMs,
      lossRate: lossRate,
    );
  }

  /// 运行整体测试：采样最多 5 台邻居并发测试，返回聚合结果
  Future<AggregatedMetrics> run() async {
    final peers = _deviceManager.getOnlineDevices();
    if (peers.isEmpty) throw NoDevicesException();

    final sample = peers.take(5).toList(growable: false);
    final futures = sample.map(testTo).toList();

    final results = await Future.wait(futures);
    return AggregatedMetrics.from(results);
  }

  double _estimateBandwidth({required double avgDelayMs, required double lossRate}) {
    // 以 RTT 越小、丢包越低 => 带宽越高
    // 采用简单公式：bw = k / (delay_ms + 5) * (1 - lossRate/150)
    // 经验系数 k=1500，使 20ms, 0%loss ≈ 60-70Mbps，最终裁剪到 [0,100]
    final k = 1500.0;
    final bw = (k / (avgDelayMs + 5.0)) * max(0.0, 1.0 - lossRate / 150.0);
    return bw.clamp(0.0, 100.0);
  }
}
