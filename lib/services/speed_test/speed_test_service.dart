import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/ai/onnx_network_evaluator.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/services/http/http_transfer_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';

/// 测速结果
class SpeedTestResult {
  final String testId;
  final DiscoveredDevice targetDevice;
  final DateTime timestamp;
  final double bandwidthMbps; // 带宽 (Mbps)
  final double avgDelayMs; // 平均延迟 (ms)
  final double packetLossRate; // 丢包率 (%)
  final double jitterMs; // 抖动 (ms)
  final double qualityScore; // 质量评分 (0-1)
  final bool shouldRecommendHotspot; // 是否推荐热点
  final double confidence; // 置信度
  final String modelVersion; // 模型版本
  final Map<String, dynamic> rawMetrics; // 原始指标

  SpeedTestResult({
    required this.testId,
    required this.targetDevice,
    required this.timestamp,
    required this.bandwidthMbps,
    required this.avgDelayMs,
    required this.packetLossRate,
    required this.jitterMs,
    required this.qualityScore,
    required this.shouldRecommendHotspot,
    required this.confidence,
    required this.modelVersion,
    required this.rawMetrics,
  });

  @override
  String toString() {
    return 'SpeedTestResult{'
        'testId: $testId, '
        'target: ${targetDevice.name}, '
        'bandwidth: ${bandwidthMbps.toStringAsFixed(2)} Mbps, '
        'delay: ${avgDelayMs.toStringAsFixed(2)} ms, '
        'loss: ${packetLossRate.toStringAsFixed(2)}%, '
        'quality: ${qualityScore.toStringAsFixed(2)}, '
        'hotspot: $shouldRecommendHotspot'
        '}';
  }

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'targetDevice': {
        'id': targetDevice.id,
        'name': targetDevice.name,
        'ip': targetDevice.ip,
        'os': targetDevice.os,
      },
      'timestamp': timestamp.toIso8601String(),
      'bandwidthMbps': bandwidthMbps,
      'avgDelayMs': avgDelayMs,
      'packetLossRate': packetLossRate,
      'jitterMs': jitterMs,
      'qualityScore': qualityScore,
      'shouldRecommendHotspot': shouldRecommendHotspot,
      'confidence': confidence,
      'modelVersion': modelVersion,
      'rawMetrics': rawMetrics,
    };
  }
}

/// 测速进度回调
typedef SpeedTestProgressCallback = void Function(
  String testId,
  String phase,
  double progress,
  String status,
  Map<String, dynamic>? metrics,
);

/// 测速完成回调
typedef SpeedTestCompleteCallback = void Function(SpeedTestResult result);

/// 测速错误回调
typedef SpeedTestErrorCallback = void Function(String testId, String error);

/// 快速HTTP测速服务
/// 负责管理测速流程、生成测速包、收集网络指标、集成AI分析
class SpeedTestService {
  final TransferLogManager _logManager;
  final TransferTaskManager? _taskManager;
  final ONNXNetworkEvaluator _onnxEvaluator;

  // 测速会话管理
  final Map<String, _SpeedTestSession> _activeSessions = {};
  
  // 回调函数
  SpeedTestProgressCallback? onProgress;
  SpeedTestCompleteCallback? onComplete;
  SpeedTestErrorCallback? onError;

  // 测速配置
  static const Map<String, int> _testSizes = {
    'small': 1024,      // 1KB - 测量延迟
    'medium': 102400,   // 100KB - 测量带宽
    'large': 1048576,   // 1MB - 测量最大带宽和稳定性
  };

  static const int _testRepeats = 3; // 每个大小重复测试次数
  static const Duration _timeout = Duration(seconds: 30);

  SpeedTestService({
    required TransferLogManager logManager,
    TransferTaskManager? taskManager,
    ONNXNetworkEvaluator? onnxEvaluator,
  })  : _logManager = logManager,
        _taskManager = taskManager,
        _onnxEvaluator = onnxEvaluator ?? ONNXNetworkEvaluator();

  /// 启动快速测速
  Future<SpeedTestResult?> startSpeedTest({
    required DiscoveredDevice targetDevice,
    String? testId,
  }) async {
    final sessionId = testId ?? 'speedtest_${DateTime.now().millisecondsSinceEpoch}';
    
    // 检查是否已有活跃会话
    if (_activeSessions.containsKey(sessionId)) {
      _log('⚠️ 测速会话已存在: $sessionId');
      return null;
    }

    // 创建测速会话
    final session = _SpeedTestSession(
      sessionId: sessionId,
      targetDevice: targetDevice,
      logManager: _logManager,
      taskManager: _taskManager,
      onnxEvaluator: _onnxEvaluator,
    );

    _activeSessions[sessionId] = session;

    // 设置回调
    session.onProgress = (testId, phase, progress, status, metrics) {
      _log('📊 测速进度: $phase - ${(progress * 100).toStringAsFixed(1)}% - $status');
      onProgress?.call(testId, phase, progress, status, metrics);
    };

    session.onComplete = (result) {
      _log('✅ 测速完成: ${result.bandwidthMbps.toStringAsFixed(2)} Mbps');
      _activeSessions.remove(sessionId);
      onComplete?.call(result);
    };

    session.onError = (testId, error) {
      _log('❌ 测速失败: $error');
      _activeSessions.remove(sessionId);
      onError?.call(sessionId, error);
    };

    try {
      _log('🚀 开始快速测速: $sessionId -> ${targetDevice.name}');
      return await session.start();
    } catch (e) {
      _log('❌ 测速启动失败: $e');
      _activeSessions.remove(sessionId);
      onError?.call(sessionId, e.toString());
      return null;
    }
  }

  /// 取消测速
  void cancelSpeedTest(String testId) {
    final session = _activeSessions[testId];
    if (session != null) {
      session.cancel();
      _activeSessions.remove(testId);
      _log('⏹️ 测速已取消: $testId');
    }
  }

  /// 获取活跃测速会话
  List<String> getActiveSessions() {
    return _activeSessions.keys.toList();
  }

  /// 检查测速会话状态
  Map<String, dynamic>? getSessionStatus(String testId) {
    return _activeSessions[testId]?.getStatus();
  }

  /// 生成测速包数据
  static Uint8List generateSpeedTestData(int size) {
    final random = Random();
    final data = Uint8List(size);
    
    // 生成随机数据，避免压缩影响
    for (int i = 0; i < size; i++) {
      data[i] = random.nextInt(256);
    }
    
    return data;
  }

  /// 创建测速包文件
  static Future<File> createSpeedTestFile(String fileName, int size) async {
    final tempDir = await Directory.systemTemp.createTemp('speedtest');
    final file = File('${tempDir.path}/$fileName');
    
    final data = generateSpeedTestData(size);
    await file.writeAsBytes(data);
    
    return file;
  }

  /// 清理测速包文件
  static Future<void> cleanupSpeedTestFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final entities = await tempDir.list().toList();
      
      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('speedtest')) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      print('⚠️ 清理测速包文件失败: $e');
    }
  }

  /// 格式化带宽
  static String formatBandwidth(double mbps) {
    if (mbps < 1.0) {
      return '${(mbps * 1000).toStringAsFixed(1)} Kbps';
    }
    return '${mbps.toStringAsFixed(1)} Mbps';
  }

  /// 格式化延迟
  static String formatDelay(double ms) {
    return '${ms.toStringAsFixed(1)} ms';
  }

  /// 记录日志
  void _log(String message) {
    print('📡 [SpeedTest] $message');
  }

  /// 释放资源
  Future<void> dispose() async {
    // 取消所有活跃会话
    for (final session in _activeSessions.values) {
      session.cancel();
    }
    _activeSessions.clear();
    
    // 清理临时文件
    await cleanupSpeedTestFiles();
    
    _log('🗑️ 测速服务已释放');
  }
}

/// 测速会话
class _SpeedTestSession {
  final String sessionId;
  final DiscoveredDevice targetDevice;
  final TransferLogManager _logManager;
  final TransferTaskManager? _taskManager;
  final ONNXNetworkEvaluator _onnxEvaluator;

  // 回调函数
  SpeedTestProgressCallback? onProgress;
  SpeedTestCompleteCallback? onComplete;
  SpeedTestErrorCallback? onError;

  // 测速状态
  bool _isRunning = false;
  bool _isCancelled = false;
  HttpTransferManager? _transferManager;
  List<File> _tempFiles = [];

  // 测速结果
  final Map<String, List<double>> _testResults = {
    'bandwidth': [],
    'delay': [],
    'loss': [],
    'jitter': [],
  };

  _SpeedTestSession({
    required this.sessionId,
    required this.targetDevice,
    required TransferLogManager logManager,
    required TransferTaskManager? taskManager,
    required ONNXNetworkEvaluator onnxEvaluator,
  })  : _logManager = logManager,
        _taskManager = taskManager,
        _onnxEvaluator = onnxEvaluator;

  /// 启动测速
  Future<SpeedTestResult?> start() async {
    if (_isRunning) {
      _error('测速会话已在运行');
      return null;
    }

    _isRunning = true;
    _isCancelled = false;

    try {
      // 1. 初始化ONNX模型
      await _initializeONNX();

      // 2. 执行渐进式测速
      final metrics = await _performProgressiveSpeedTest();

      // 3. AI分析
      final aiResult = await _performAIAnalysis(metrics);

      // 4. 生成最终结果
      final result = _generateFinalResult(metrics, aiResult);

      // 5. 清理资源
      await _cleanup();

      // 6. 回调完成
      onComplete?.call(result);
      return result;

    } catch (e) {
      _error('测速过程异常: $e');
      await _cleanup();
      return null;
    } finally {
      _isRunning = false;
    }
  }

  /// 取消测速
  void cancel() {
    _isCancelled = true;
    _transferManager?.dispose();
    _cleanup();
  }

  /// 获取会话状态
  Map<String, dynamic> getStatus() {
    return {
      'sessionId': sessionId,
      'targetDevice': targetDevice.name,
      'isRunning': _isRunning,
      'isCancelled': _isCancelled,
      'testResults': _testResults,
    };
  }

  /// 初始化ONNX模型
  Future<void> _initializeONNX() async {
    _updateProgress('初始化', 0.05, '加载AI模型...');
    
    final loaded = await _onnxEvaluator.loadModel();
    if (!loaded) {
      _log('⚠️ ONNX模型加载失败，将使用模拟推理');
    } else {
      _log('✅ ONNX模型加载成功');
    }
  }

  /// 执行渐进式测速
  Future<Map<String, double>> _performProgressiveSpeedTest() async {
    final metrics = <String, double>{};
    int totalTests = SpeedTestService._testSizes.length * SpeedTestService._testRepeats;
    int completedTests = 0;

    // 小包测速 - 测量延迟
    _updateProgress('延迟测量', 0.1, '测量网络延迟...');
    final delayResults = await _testPacketSize('small');
    metrics['avgDelayMs'] = _calculateAverage(delayResults['delay'] ?? []);
    metrics['jitterMs'] = _calculateJitter(delayResults['delay'] ?? []);
    completedTests += SpeedTestService._testRepeats;

    // 中包测速 - 测量带宽
    _updateProgress('带宽测量', 0.4, '测量网络带宽...');
    final bandwidthResults = await _testPacketSize('medium');
    metrics['bandwidthMbps'] = _calculateAverage(bandwidthResults['bandwidth'] ?? []);
    completedTests += SpeedTestService._testRepeats;

    // 大包测速 - 测量稳定性和丢包率
    _updateProgress('稳定性测量', 0.7, '测量网络稳定性...');
    final stabilityResults = await _testPacketSize('large');
    metrics['packetLossRate'] = _calculateLossRate(stabilityResults);
    completedTests += SpeedTestService._testRepeats;

    // 计算最终带宽（取中包和大包的平均值）
    final mediumBandwidth = _calculateAverage(bandwidthResults['bandwidth'] ?? []);
    final largeBandwidth = _calculateAverage(stabilityResults['bandwidth'] ?? []);
    metrics['finalBandwidthMbps'] = (mediumBandwidth + largeBandwidth) / 2;

    _updateProgress('数据分析', 0.9, '分析测速结果...');

    return metrics;
  }

  /// 测试特定大小的数据包
  Future<Map<String, List<double>>> _testPacketSize(String sizeName) async {
    final size = SpeedTestService._testSizes[sizeName]!;
    final results = <String, List<double>>{
      'bandwidth': [],
      'delay': [],
      'loss': [],
    };

    for (int i = 0; i < SpeedTestService._testRepeats; i++) {
      if (_isCancelled) break;

      final progress = 0.1 + (0.6 * (i / SpeedTestService._testRepeats));
      _updateProgress('$sizeName测速', progress, '测试 ${i + 1}/${SpeedTestService._testRepeats}');

      final testResult = await _performSingleTest(size, sizeName);
      
      if (testResult != null) {
        results['bandwidth']!.add(testResult['bandwidth'] ?? 0.0);
        results['delay']!.add(testResult['delay'] ?? 0.0);
      }
    }

    return results;
  }

  /// 执行单次测速
  Future<Map<String, double>?> _performSingleTest(int size, String sizeName) async {
    try {
      final fileName = 'speedtest_${sizeName}_${DateTime.now().millisecondsSinceEpoch}.dat';
      final testFile = await SpeedTestService.createSpeedTestFile(fileName, size);
      _tempFiles.add(testFile);

      // 初始化传输管理器
      _transferManager = HttpTransferManager(
        logManager: _logManager,
        taskManager: _taskManager,
      );

      // 初始化客户端
      _transferManager!.initClient(
        serverIp: targetDevice.ip,
        serverPort: targetDevice.httpPort,
      );

      final startTime = DateTime.now();
      
      // 上传测速包
      final success = await _transferManager!.uploadFile(
        filePath: testFile.path,
        fileName: fileName,
        targetDevice: targetDevice,
        resumeUpload: false,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

      if (!success) {
        _log('❌ 测速包上传失败: $fileName');
        return null;
      }

      // 计算带宽 (Mbps)
      final bandwidth = (size * 8) / (duration * 1000000); // Mbps
      
      // 估算延迟（基于小包测试）
      final delay = sizeName == 'small' ? duration * 1000 : 0.0;

      _log('📊 测速结果: ${SpeedTestService.formatBandwidth(bandwidth)}, 延迟: ${SpeedTestService.formatDelay(delay)}');

      return {
        'bandwidth': bandwidth,
        'delay': delay,
        'duration': duration,
      };

    } catch (e) {
      _log('❌ 单次测速失败: $e');
      return null;
    }
  }

  /// 执行AI分析
  Future<ONNXInferenceResult?> _performAIAnalysis(Map<String, double> metrics) async {
    final networkQuality = NetworkQuality(
      bandwidthMbps: metrics['finalBandwidthMbps'] ?? 0.0,
      avgDelayMs: metrics['avgDelayMs'] ?? 0.0,
      packetLossRate: metrics['packetLossRate'] ?? 0.0,
      timestamp: DateTime.now(),
    );

    return await _onnxEvaluator.infer(networkQuality);
  }

  /// 生成最终结果
  SpeedTestResult _generateFinalResult(
    Map<String, double> metrics,
    ONNXInferenceResult? aiResult,
  ) {
    final ai = aiResult ?? _onnxEvaluator.simulateInference(
      NetworkQuality(
        bandwidthMbps: metrics['finalBandwidthMbps'] ?? 0.0,
        avgDelayMs: metrics['avgDelayMs'] ?? 0.0,
        packetLossRate: metrics['packetLossRate'] ?? 0.0,
        timestamp: DateTime.now(),
      ),
    );

    return SpeedTestResult(
      testId: sessionId,
      targetDevice: targetDevice,
      timestamp: DateTime.now(),
      bandwidthMbps: metrics['finalBandwidthMbps'] ?? 0.0,
      avgDelayMs: metrics['avgDelayMs'] ?? 0.0,
      packetLossRate: metrics['packetLossRate'] ?? 0.0,
      jitterMs: metrics['jitterMs'] ?? 0.0,
      qualityScore: ai.qualityScore,
      shouldRecommendHotspot: ai.shouldRecommendHotspot,
      confidence: ai.confidence,
      modelVersion: ai.modelVersion,
      rawMetrics: metrics,
    );
  }

  /// 计算平均值
  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// 计算抖动（标准差）
  double _calculateJitter(List<double> delays) {
    if (delays.length < 2) return 0.0;
    
    final mean = _calculateAverage(delays);
    final variance = delays.map((d) => pow(d - mean, 2)).reduce((a, b) => a + b) / delays.length;
    return sqrt(variance);
  }

  /// 计算丢包率
  double _calculateLossRate(Map<String, List<double>> results) {
    final totalTests = SpeedTestService._testRepeats;
    final successfulTests = (results['bandwidth'] ?? []).length;
    
    if (totalTests == 0) return 100.0;
    
    return ((totalTests - successfulTests) / totalTests) * 100.0;
  }

  /// 更新进度
  void _updateProgress(String phase, double progress, String status) {
    if (_isCancelled) return;
    
    onProgress?.call(sessionId, phase, progress, status, {
      'sessionId': sessionId,
      'targetDevice': targetDevice.name,
      'phase': phase,
      'progress': progress,
      'status': status,
    });
  }

  /// 清理资源
  Future<void> _cleanup() async {
    _transferManager?.dispose();
    _transferManager = null;
    
    // 清理临时文件
    for (final file in _tempFiles) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        _log('⚠️ 清理临时文件失败: ${file.path} - $e');
      }
    }
    _tempFiles.clear();
  }

  /// 记录日志
  void _log(String message) {
    print('📡 [SpeedTestSession] $message');
  }

  /// 记录错误
  void _error(String message) {
    _log('❌ $message');
    onError?.call(sessionId, message);
  }
}
