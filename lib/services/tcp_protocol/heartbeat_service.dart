/// 心跳检测和断连处理服务
/// 实现TCP连接的心跳检测机制和断连自动处理

import 'dart:async';
import 'dart:io';
import 'tcp_control_message.dart';
import 'tcp_protocol_base.dart';

/// 心跳检测服务
class HeartbeatService {
  final Socket _socket;
  final JsonLinePeer _peer;
  final Duration _pingInterval;
  final Duration _timeoutDuration;
  
  Timer? _pingTimer;
  Timer? _timeoutTimer;
  bool _isConnected = true;
  
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  final StreamController<void> _timeoutController = StreamController<void>.broadcast();

  HeartbeatService({
    required Socket socket,
    required JsonLinePeer peer,
    Duration pingInterval = const Duration(seconds: 3),
    Duration timeoutDuration = const Duration(seconds: 10),
  }) : 
        _socket = socket,
        _peer = peer,
        _pingInterval = pingInterval,
        _timeoutDuration = timeoutDuration {
    _startHeartbeat();
    _setupMessageListener();
  }

  /// 连接状态流
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  
  /// 超时事件流
  Stream<void> get onTimeout => _timeoutController.stream;

  /// 当前连接状态
  bool get isConnected => _isConnected;

  /// 启动心跳检测
  void _startHeartbeat() {
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected) {
        _sendPing();
        _startTimeoutTimer();
      }
    });
    
    // 立即发送一次心跳
    _sendPing();
    _startTimeoutTimer();
  }

  /// 发送心跳包
  void _sendPing() {
    try {
      final pingMessage = PingMessage();
      _peer.send(pingMessage.toJson());
    } catch (e) {
      _handleConnectionLost();
    }
  }

  /// 启动超时计时器
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeoutDuration, () {
      _handleTimeout();
    });
  }

  /// 处理超时
  void _handleTimeout() {
    if (_isConnected) {
      _isConnected = false;
      _connectionStatusController.add(false);
      _timeoutController.add(null);
      print('心跳超时，连接已断开');
    }
  }

  /// 处理连接丢失
  void _handleConnectionLost() {
    if (_isConnected) {
      _isConnected = false;
      _connectionStatusController.add(false);
      print('连接丢失');
    }
  }

  /// 设置消息监听器
  void _setupMessageListener() {
    _peer.frames.listen((message) {
      final controlMessage = TcpControlMessage.fromJson(message);
      
      switch (controlMessage.op) {
        case TcpControlOp.pong:
          _handlePong();
          break;
        case TcpControlOp.ping:
          _handlePing();
          break;
        case TcpControlOp.error:
          _handleError(controlMessage);
          break;
        default:
          // 其他消息类型不影响心跳检测
          break;
      }
    }, onError: (error) {
      _handleConnectionLost();
    }, onDone: () {
      _handleConnectionLost();
    });
  }

  /// 处理PONG响应
  void _handlePong() {
    _timeoutTimer?.cancel();
    if (!_isConnected) {
      _isConnected = true;
      _connectionStatusController.add(true);
      print('连接恢复');
    }
  }

  /// 处理PING请求
  void _handlePing() {
    try {
      final pongMessage = PongMessage();
      _peer.send(pongMessage.toJson());
    } catch (e) {
      _handleConnectionLost();
    }
  }

  /// 处理错误消息
  void _handleError(TcpControlMessage message) {
    final errorMessage = ErrorMessage.fromBase(message);
    print('收到错误消息: ${errorMessage.errorMessage}');
    // 错误消息可能表示连接问题
    _handleConnectionLost();
  }

  /// 停止心跳检测服务
  void dispose() {
    _pingTimer?.cancel();
    _pingTimer = null;
    
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    
    _connectionStatusController.close();
    _timeoutController.close();
  }
}
