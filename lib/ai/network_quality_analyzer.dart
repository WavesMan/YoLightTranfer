// AI模块：网络质量分析器
// 负责采集带宽、延迟、丢包率等网络指标
// 为AI规则引擎提供数据输入

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

/// 网络质量数据模型
class NetworkQuality {
  final double bandwidthMbps; // 带宽（Mbps）
  final double packetLossRate; // 丢包率（%）
  final double avgDelayMs; // 平均延迟（ms）
  final DateTime timestamp; // 采集时间

  const NetworkQuality({
    required this.bandwidthMbps,
    required this.packetLossRate,
    required this.avgDelayMs,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NetworkQuality(bandwidth: ${bandwidthMbps.toStringAsFixed(2)}Mbps, '
           'loss: ${packetLossRate.toStringAsFixed(2)}%, '
           'delay: ${avgDelayMs.toStringAsFixed(0)}ms)';
  }

  /// 判断是否为弱网
  bool get isWeakNetwork {
    return bandwidthMbps < 1.0 && 
           packetLossRate > 5.0 && 
           avgDelayMs > 100.0;
  }
}

/// 网络质量分析器
class NetworkQualityAnalyzer {
  static const int _testDataSize = 100 * 1024; // 100KB测试数据
  static const int _testCount = 10; // 测试包数量
  static const Duration _timeout = Duration(milliseconds: 500);
  
  final String _testServerIp;
  final int _testServerPort;
  final List<NetworkQuality> _history = []; // 历史数据（滑动窗口）
  static const int _historySize = 3; // 滑动窗口大小

  NetworkQualityAnalyzer(this._testServerIp, this._testServerPort);

  /// 测算带宽（单位：Mbps）
  Future<double> measureBandwidth() async {
    try {
      // 创建测试数据
      final Uint8List testData = Uint8List(_testDataSize);
      final random = Random();
      for (int i = 0; i < _testDataSize; i++) {
        testData[i] = random.nextInt(256);
      }

      // 建立TCP连接（复用现有HTTP服务器端口）
      final socket = await Socket.connect(
        _testServerIp, 
        _testServerPort, 
        timeout: const Duration(seconds: 5)
      );
      final stopwatch = Stopwatch()..start();

      // 发送测试数据
      socket.add(testData);
      await socket.flush();

      // 等待接收端确认
      final response = <int>[];
      socket.listen((data) => response.addAll(data)).onDone(() => socket.close());
      
      // 等待响应或超时
      await Future.doWhile(() => 
        Future.delayed(const Duration(milliseconds: 100), () => response.isEmpty)
      );

      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;
      if (durationMs == 0) return 0;

      // 计算带宽：1Byte=8bit，1Mbps=1024*1024bit
      final bytesPerSecond = (_testDataSize / (durationMs / 1000));
      final mbps = (bytesPerSecond * 8) / (1024 * 1024);
      return mbps;
    } catch (e) {
      print('带宽测算失败：$e');
      return 0; // 异常时返回0（视为网络不可用）
    }
  }

  /// 测算丢包率和延迟
  Future<({double packetLossRate, double avgDelayMs})> measureLossAndDelay() async {
    final udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    int successCount = 0;
    final delays = <int>[];
    final random = Random();

    try {
      for (int i = 0; i < _testCount; i++) {
        // 每个包带唯一标识和发送时间
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final packetId = random.nextInt(10000);
        final data = utf8.encode('test_${packetId}_$timestamp');

        // 发送UDP包
        udpSocket.send(data, InternetAddress(_testServerIp), _testServerPort);
        final stopwatch = Stopwatch()..start();

        // 等待响应（超时500ms）
        bool received = false;
        await for (var event in udpSocket) {
          if (event == RawSocketEvent.read) {
            final datagram = udpSocket.receive();
            if (datagram != null) {
              final response = utf8.decode(datagram.data);
              if (response.contains('test_${packetId}_')) {
                // 解析响应中的发送时间，计算RTT
                final parts = response.split('_');
                final sendTime = int.parse(parts[2]);
                final rtt = DateTime.now().millisecondsSinceEpoch - sendTime;
                delays.add(rtt);
                successCount++;
                received = true;
                break;
              }
            }
          }
          if (stopwatch.elapsedMilliseconds > _timeout.inMilliseconds) break;
        }
        
        // 间隔100ms避免包冲突
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final packetLossRate = ((_testCount - successCount) / _testCount) * 100;
      final avgDelayMs = delays.isNotEmpty ? 
        delays.reduce((a, b) => a + b) / delays.length : 0.0;
      
      return (packetLossRate: packetLossRate, avgDelayMs: avgDelayMs.toDouble());
    } finally {
      udpSocket.close();
    }
  }

  /// 综合测算网络质量（包含滑动窗口平均）
  Future<NetworkQuality> measureNetworkQuality() async {
    try {
      // 并行测算带宽和丢包率/延迟
      final bandwidthFuture = measureBandwidth();
      final lossAndDelayFuture = measureLossAndDelay();
      
      final bandwidth = await bandwidthFuture;
      final lossAndDelay = await lossAndDelayFuture;

      final quality = NetworkQuality(
        bandwidthMbps: bandwidth,
        packetLossRate: lossAndDelay.packetLossRate,
        avgDelayMs: lossAndDelay.avgDelayMs,
        timestamp: DateTime.now(),
      );

      // 更新历史数据（滑动窗口）
      _updateHistory(quality);
      
      // 返回滑动窗口平均值
      return _getAverageQuality();
    } catch (e) {
      print('网络质量测算失败：$e');
      // 返回默认值（网络不可用）
      return NetworkQuality(
        bandwidthMbps: 0,
        packetLossRate: 100,
        avgDelayMs: 1000,
        timestamp: DateTime.now(),
      );
    }
  }

  /// 更新历史数据（滑动窗口）
  void _updateHistory(NetworkQuality quality) {
    _history.add(quality);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }
  }

  /// 获取滑动窗口平均值
  NetworkQuality _getAverageQuality() {
    if (_history.isEmpty) {
      return NetworkQuality(
        bandwidthMbps: 0,
        packetLossRate: 0,
        avgDelayMs: 0,
        timestamp: DateTime.now(),
      );
    }

    final avgBandwidth = _history.map((q) => q.bandwidthMbps).reduce((a, b) => a + b) / _history.length;
    final avgLossRate = _history.map((q) => q.packetLossRate).reduce((a, b) => a + b) / _history.length;
    final avgDelay = _history.map((q) => q.avgDelayMs).reduce((a, b) => a + b) / _history.length;

    return NetworkQuality(
      bandwidthMbps: avgBandwidth,
      packetLossRate: avgLossRate,
      avgDelayMs: avgDelay,
      timestamp: DateTime.now(),
    );
  }

  /// 获取历史数据（用于调试和分析）
  List<NetworkQuality> get history => List.unmodifiable(_history);

  /// 清空历史数据
  void clearHistory() {
    _history.clear();
  }
}
