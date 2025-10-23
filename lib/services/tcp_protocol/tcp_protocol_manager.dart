/// TCP协议服务管理器
/// 整合所有TCP协议相关服务，提供统一的接口

import 'dart:async';
import 'dart:io';
import 'tcp_control_message.dart';
import 'heartbeat_service.dart';
import 'file_receiver.dart';
import 'task_control_service.dart';
import 'tcp_protocol_base.dart';

/// TCP协议管理器状态
enum TcpProtocolState {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  error,         // 错误状态
}

/// TCP协议管理器
class TcpProtocolManager {
  Socket? _socket;
  JsonLinePeer? _peer;
  HeartbeatService? _heartbeatService;
  FileReceiver? _fileReceiver;
  TaskControlService? _taskControlService;
  
  TcpProtocolState _state = TcpProtocolState.disconnected;
  
  final StreamController<TcpProtocolState> _stateController = StreamController<TcpProtocolState>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  /// 连接状态流
  Stream<TcpProtocolState> get stateStream => _stateController.stream;
  
  /// 错误事件流
  Stream<String> get errorStream => _errorController.stream;
  
  /// 当前状态
  TcpProtocolState get state => _state;

  /// 文件接收器（如果已初始化）
  FileReceiver? get fileReceiver => _fileReceiver;
  
  /// 任务控制服务（如果已初始化）
  TaskControlService? get taskControlService => _taskControlService;
  
  /// 心跳服务（如果已初始化）
  HeartbeatService? get heartbeatService => _heartbeatService;

  /// 连接到服务端
  Future<void> connectAsClient({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_state != TcpProtocolState.disconnected) {
      throw StateError('已有活动的连接');
    }

    _updateState(TcpProtocolState.connecting);

    try {
      _socket = await Socket.connect(host, port, timeout: timeout);
      _peer = JsonLinePeer(_socket!);
      
      await _initializeServices();
      _updateState(TcpProtocolState.connected);
      
    } catch (e) {
      _updateState(TcpProtocolState.error);
      _handleError('连接失败: $e');
      rethrow;
    }
  }

  /// 启动服务端
  Future<void> startAsServer({
    required int port,
    String baseSavePath = '',
  }) async {
    if (_state != TcpProtocolState.disconnected) {
      throw StateError('已有活动的连接');
    }

    _updateState(TcpProtocolState.connecting);

    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      
      server.listen((clientSocket) async {
        // 处理新客户端连接
        await _handleNewClient(clientSocket, baseSavePath);
      }, onError: (e) {
        _handleError('服务端错误: $e');
      });

      _updateState(TcpProtocolState.connected);
      
    } catch (e) {
      _updateState(TcpProtocolState.error);
      _handleError('启动服务端失败: $e');
      rethrow;
    }
  }

  /// 处理新客户端连接
  Future<void> _handleNewClient(Socket clientSocket, String baseSavePath) async {
    // 关闭之前的连接（单客户端模式）
    await disconnect();
    
    _socket = clientSocket;
    _peer = JsonLinePeer(_socket!);
    
    await _initializeServices(baseSavePath: baseSavePath);
    _updateState(TcpProtocolState.connected);
  }

  /// 初始化所有服务
  Future<void> _initializeServices({String baseSavePath = ''}) async {
    if (_socket == null || _peer == null) {
      throw StateError('Socket或Peer未初始化');
    }

    // 初始化任务控制服务
    _taskControlService = TaskControlService(peer: _peer!);
    
    // 初始化文件接收器
    _fileReceiver = FileReceiver(
      peer: _peer!,
      baseSavePath: baseSavePath,
    );
    
    // 初始化心跳服务
    _heartbeatService = HeartbeatService(
      socket: _socket!,
      peer: _peer!,
    );
    
    // 设置心跳超时处理
    _heartbeatService!.onTimeout.listen((_) {
      _handleConnectionTimeout();
    });
    
    // 设置连接状态监听
    _heartbeatService!.connectionStatus.listen((connected) {
      if (!connected) {
        _handleConnectionLost();
      }
    });
    
    // 设置文件接收器的原始数据处理
    _socket!.listen((data) {
      _fileReceiver?.handleRawData(data);
    }, onError: (e) {
      _handleError('Socket数据接收错误: $e');
    }, onDone: () {
      _handleConnectionLost();
    });
  }

  /// 发送控制消息
  void sendControlMessage(TcpControlMessage message) {
    if (_peer == null) {
      throw StateError('未连接');
    }
    _peer!.send(message.toJson());
  }

  /// 发送取消任务请求
  void sendCancel(String transferId, {String? reason}) {
    _taskControlService?.cancelTask(transferId, reason: reason);
  }

  /// 发送进度报告
  void sendProgress(String transferId, int transferred, int total) {
    final progressMessage = ProgressMessage(
      transferId: transferId,
      transferred: transferred,
      total: total,
    );
    sendControlMessage(progressMessage);
  }

  /// 发送错误通知
  void sendError(String transferId, String errorMessage) {
    final errorMessageObj = ErrorMessage(
      transferId: transferId,
      errorMessage: errorMessage,
    );
    sendControlMessage(errorMessageObj);
  }

  /// 创建传输任务
  TransferTask? createTransferTask({
    required String transferId,
    required String fileName,
    required int totalSize,
  }) {
    return _taskControlService?.createTask(
      transferId: transferId,
      fileName: fileName,
      totalSize: totalSize,
    );
  }

  /// 开始传输任务
  void startTransferTask(String transferId) {
    _taskControlService?.startTask(transferId);
  }

  /// 更新传输进度
  void updateTransferProgress(String transferId, int transferredBytes) {
    _taskControlService?.updateTaskProgress(transferId, transferredBytes);
  }

  /// 完成传输任务
  void completeTransferTask(String transferId) {
    _taskControlService?.completeTask(transferId);
  }

  /// 处理连接超时
  void _handleConnectionTimeout() {
    _updateState(TcpProtocolState.error);
    _handleError('连接超时');
    _cleanup();
  }

  /// 处理连接丢失
  void _handleConnectionLost() {
    _updateState(TcpProtocolState.disconnected);
    _cleanup();
  }

  /// 处理错误
  void _handleError(String errorMessage) {
    _errorController.add(errorMessage);
    print('TCP协议错误: $errorMessage');
  }

  /// 更新状态
  void _updateState(TcpProtocolState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    _heartbeatService?.dispose();
    _heartbeatService = null;
    
    _fileReceiver?.dispose();
    _fileReceiver = null;
    
    _taskControlService?.dispose();
    _taskControlService = null;
    
    _peer?.dispose();
    _peer = null;
    
    await _socket?.close();
    _socket = null;
  }

  /// 断开连接
  Future<void> disconnect() async {
    _cleanup();
    _updateState(TcpProtocolState.disconnected);
  }

  /// 释放所有资源
  Future<void> dispose() async {
    disconnect();
    _stateController.close();
    _errorController.close();
  }
}
