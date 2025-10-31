import 'dart:async';
import 'dart:io';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/speed_test/speed_test_service.dart';
import 'package:yolighttransfer/services/http/http_transfer_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';

/// 测速客户端状态
enum SpeedTestClientState {
  disconnected,   // 未连接
  connecting,     // 连接中
  connected,      // 已连接
  testing,        // 测速中
  error,          // 错误
}

/// 测速客户端事件
class SpeedTestClientEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SpeedTestClientEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 快速HTTP测速客户端
/// 负责与目标设备建立连接、发送测速请求、接收测速结果
class SpeedTestClient {
  final TransferLogManager _logManager;
  final TransferTaskManager? _taskManager;
  final HttpTransferManager _transferManager;

  // 客户端状态
  SpeedTestClientState _state = SpeedTestClientState.disconnected;
  
  // 目标设备
  DiscoveredDevice? _targetDevice;
  
  // 活跃测速会话
  final Map<String, SpeedTestResult> _activeTests = {};
  
  // 事件流
  final StreamController<SpeedTestClientEvent> _eventController = 
      StreamController<SpeedTestClientEvent>.broadcast();

  // 回调函数
  void Function(SpeedTestClientState state)? onStateChanged;
  void Function(SpeedTestClientEvent event)? onEvent;

  SpeedTestClient({
    required TransferLogManager logManager,
    TransferTaskManager? taskManager,
    HttpTransferManager? transferManager,
  })  : _logManager = logManager,
        _taskManager = taskManager,
        _transferManager = transferManager ?? HttpTransferManager(
          logManager: logManager,
          taskManager: taskManager,
        ) {
    // 设置事件监听
    _setupEventListeners();
  }

  /// 获取当前状态
  SpeedTestClientState get state => _state;

  /// 获取目标设备
  DiscoveredDevice? get targetDevice => _targetDevice;

  /// 获取事件流
  Stream<SpeedTestClientEvent> get events => _eventController.stream;

  /// 获取活跃测速会话
  List<String> get activeTests => _activeTests.keys.toList();

  /// 连接到目标设备
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_state == SpeedTestClientState.connected && _targetDevice?.id == device.id) {
      _log('⚠️ 已连接到目标设备: ${device.name}');
      return true;
    }

    _setState(SpeedTestClientState.connecting);
    _targetDevice = device;

    try {
      _log('🔗 连接到设备: ${device.name} (${device.ip}:${device.httpPort})');

      // 初始化传输管理器
      _transferManager.initClient(
        serverIp: device.ip,
        serverPort: device.httpPort,
      );

      // 测试连接
      final connected = await _testConnection();
      
      if (connected) {
        _setState(SpeedTestClientState.connected);
        _emitEvent('connected', {
          'device': device.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        _log('✅ 连接成功: ${device.name}');
        return true;
      } else {
        _setState(SpeedTestClientState.error);
        _emitEvent('connection_failed', {
          'device': device.toJson(),
          'error': '连接测试失败',
        });
        _log('❌ 连接失败: ${device.name}');
        return false;
      }

    } catch (e) {
      _setState(SpeedTestClientState.error);
      _emitEvent('connection_error', {
        'device': device.toJson(),
        'error': e.toString(),
      });
      _log('❌ 连接异常: $e');
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _transferManager.dispose();
    _targetDevice = null;
    _activeTests.clear();
    _setState(SpeedTestClientState.disconnected);
    
    _emitEvent('disconnected', {
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _log('🔌 已断开连接');
  }

  /// 启动快速测速
  Future<SpeedTestResult?> startSpeedTest({
    String? testId,
    Map<String, dynamic>? options,
  }) async {
    if (_state != SpeedTestClientState.connected || _targetDevice == null) {
      _log('❌ 未连接到设备，无法启动测速');
      return null;
    }

    try {
      _log('🚀 启动测速: ${_targetDevice!.name}');

      // 创建测速服务
      final speedTestService = SpeedTestService(
        logManager: _logManager,
        taskManager: _taskManager,
      );

      // 设置进度回调
      speedTestService.onProgress = (testId, phase, progress, status, metrics) {
        _emitEvent('test_progress', {
          'testId': testId,
          'phase': phase,
          'progress': progress,
          'status': status,
          'metrics': metrics,
        });
      };

      // 启动测速
      final result = await speedTestService.startSpeedTest(
        targetDevice: _targetDevice!,
        testId: testId,
      );

      if (result != null) {
        _activeTests[result.testId] = result;
        
        _emitEvent('test_started', {
          'testId': result.testId,
          'device': _targetDevice!.toJson(),
          'timestamp': result.timestamp.toIso8601String(),
        });

        // 监听测速完成
        speedTestService.onComplete = (completedResult) {
          _handleTestComplete(completedResult);
          speedTestService.dispose();
        };

        speedTestService.onError = (testId, error) {
          _handleTestError(testId, error);
          speedTestService.dispose();
        };

        _log('✅ 测速启动成功: ${result.testId}');
        return result;
      } else {
        _log('❌ 测速启动失败');
        return null;
      }

    } catch (e) {
      _log('❌ 测速启动异常: $e');
      _emitEvent('test_error', {
        'testId': testId,
        'error': e.toString(),
      });
      return null;
    }
  }

  /// 批量测速
  Future<List<SpeedTestResult>> batchSpeedTest({
    required List<DiscoveredDevice> devices,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final results = <SpeedTestResult>[];
    
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      
      _log('📊 批量测速进度: ${i + 1}/${devices.length} - ${device.name}');
      
      // 连接到设备
      final connected = await connectToDevice(device);
      if (!connected) {
        _log('⚠️ 连接失败，跳过设备: ${device.name}');
        continue;
      }
      
      // 启动测速
      final result = await startSpeedTest();
      if (result != null) {
        results.add(result);
      }
      
      // 等待间隔，避免网络拥塞
      if (i < devices.length - 1) {
        await Future.delayed(interval);
      }
    }
    
    return results;
  }

  /// 取消测速
  void cancelSpeedTest(String testId) {
    // 这里需要实现具体的取消逻辑
    // 目前只是从活跃会话中移除
    _activeTests.remove(testId);
    
    _emitEvent('test_cancelled', {
      'testId': testId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _log('⏹️ 测速已取消: $testId');
  }

  /// 获取测速结果
  SpeedTestResult? getTestResult(String testId) {
    return _activeTests[testId];
  }

  /// 获取连接质量指标
  Future<Map<String, dynamic>> getConnectionMetrics() async {
    if (_state != SpeedTestClientState.connected || _targetDevice == null) {
      return {
        'connected': false,
        'latency': 0.0,
        'bandwidth': 0.0,
        'stability': 0.0,
      };
    }

    try {
      // 执行快速连接测试
      final latency = await _measureLatency();
      final bandwidth = await _measureQuickBandwidth();
      
      return {
        'connected': true,
        'latency': latency,
        'bandwidth': bandwidth,
        'stability': _calculateStability(latency, bandwidth),
        'device': _targetDevice!.toJson(),
      };
    } catch (e) {
      return {
        'connected': false,
        'latency': 0.0,
        'bandwidth': 0.0,
        'stability': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// 发送自定义测速包
  Future<bool> sendCustomTestPacket({
    required Uint8List data,
    String? packetId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_state != SpeedTestClientState.connected || _targetDevice == null) {
      return false;
    }

    try {
      final packetId = packetId ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = 'speedtest_custom_$packetId.dat';
      
      // 创建临时文件
      final tempDir = await Directory.systemTemp.createTemp('speedtest_client');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(data);
      
      final startTime = DateTime.now();
      
      // 上传文件
      final success = await _transferManager.uploadFile(
        filePath: file.path,
        fileName: fileName,
        targetDevice: _targetDevice!,
        resumeUpload: false,
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      // 清理临时文件
      await file.delete();
      await tempDir.delete();
      
      if (success) {
        _emitEvent('custom_packet_sent', {
          'packetId': packetId,
          'size': data.length,
          'duration': duration,
          'bandwidth': (data.length * 8) / (duration / 1000) / 1000000, // Mbps
          'metadata': metadata,
        });
        
        _log('📦 自定义测速包发送成功: $packetId (${data.length} bytes, ${duration}ms)');
        return true;
      } else {
        _log('❌ 自定义测速包发送失败: $packetId');
        return false;
      }
      
    } catch (e) {
      _log('❌ 自定义测速包发送异常: $e');
      return false;
    }
  }

  /// 测试连接
  Future<bool> _testConnection() async {
    try {
      // 发送小测试包验证连接
      final testData = SpeedTestService.generateSpeedTestData(128); // 128 bytes
      return await sendCustomTestPacket(
        data: testData,
        packetId: 'connection_test',
        metadata: {'purpose': 'connection_test'},
      );
    } catch (e) {
      return false;
    }
  }

  /// 测量延迟
  Future<double> _measureLatency() async {
    try {
      final testData = SpeedTestService.generateSpeedTestData(64); // 64 bytes
      final startTime = DateTime.now();
      
      final success = await sendCustomTestPacket(
        data: testData,
        packetId: 'latency_test',
        metadata: {'purpose': 'latency_measurement'},
      );
      
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds.toDouble();
      
      return success ? latency : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 测量快速带宽
  Future<double> _measureQuickBandwidth() async {
    try {
      final testData = SpeedTestService.generateSpeedTestData(10240); // 10KB
      final startTime = DateTime.now();
      
      final success = await sendCustomTestPacket(
        data: testData,
        packetId: 'quick_bandwidth_test',
        metadata: {'purpose': 'quick_bandwidth_measurement'},
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds / 1000.0;
      
      if (success && duration > 0) {
        return (testData.length * 8) / (duration * 1000000); // Mbps
      } else {
        return 0.0;
      }
    } catch (e) {
      return 0.0;
    }
  }

  /// 计算连接稳定性
  double _calculateStability(double latency, double bandwidth) {
    // 简单的稳定性计算
    // 低延迟和高带宽表示稳定性好
    final latencyScore = latency > 0 ? (1000 / latency).clamp(0.0, 1.0) : 0.0;
    final bandwidthScore = (bandwidth / 100).clamp(0.0, 1.0); // 假设100Mbps为理想带宽
    
    return (latencyScore * 0.6 + bandwidthScore * 0.4);
  }

  /// 处理测速完成
  void _handleTestComplete(SpeedTestResult result) {
    _activeTests.remove(result.testId);
    
    _emitEvent('test_completed', {
      'testId': result.testId,
      'result': result.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _log('✅ 测速完成: ${result.testId} - ${SpeedTestService.formatBandwidth(result.bandwidthMbps)}');
  }

  /// 处理测速错误
  void _handleTestError(String testId, String error) {
    _activeTests.remove(testId);
    
    _emitEvent('test_error', {
      'testId': testId,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _log('❌ 测速错误: $testId - $error');
  }

  /// 设置事件监听
  void _setupEventListeners() {
    _eventController.stream.listen((event) {
      onEvent?.call(event);
    });
  }

  /// 设置状态
  void _setState(SpeedTestClientState newState) {
    if (_state != newState) {
      _state = newState;
      _log('🔄 状态变更: ${_state.name}');
      onStateChanged?.call(_state);
    }
  }

  /// 发送事件
  void _emitEvent(String type, Map<String, dynamic> data) {
    final event = SpeedTestClientEvent(
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _eventController.add(event);
  }

  /// 记录日志
  void _log(String message) {
    print('📡 [SpeedTestClient] $message');
  }

  /// 释放资源
  Future<void> dispose() async {
    disconnect();
    await _eventController.close();
    _transferManager.dispose();
    _log('🗑️ 测速客户端已释放');
  }
}
