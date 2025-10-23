/// 任务取消和进度同步服务
/// 实现端到端的任务控制和进度同步机制

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'tcp_control_message.dart';
import 'tcp_protocol_base.dart';

/// 传输任务状态
enum TransferTaskState {
  pending,      // 等待开始
  transferring, // 传输中
  completed,    // 已完成
  cancelled,    // 已取消
  error,        // 出错
}

/// 传输任务信息
class TransferTask {
  final String transferId;
  final String fileName;
  final int totalSize;
  
  TransferTaskState state = TransferTaskState.pending;
  int transferredBytes = 0;
  String? errorMessage;
  DateTime startTime = DateTime.now();
  DateTime? endTime;

  TransferTask({
    required this.transferId,
    required this.fileName,
    required this.totalSize,
  });

  /// 获取传输进度（0-100）
  double get progress {
    if (totalSize == 0) return 0.0;
    return (transferredBytes / totalSize * 100).clamp(0.0, 100.0);
  }

  /// 获取传输速度（字节/秒）
  double get transferSpeed {
    final duration = (endTime ?? DateTime.now()).difference(startTime);
    if (duration.inSeconds == 0) return 0.0;
    return transferredBytes / duration.inSeconds;
  }

  /// 获取剩余时间估算（秒）
  double get estimatedTimeRemaining {
    if (transferredBytes == 0 || transferSpeed == 0) return 0.0;
    return (totalSize - transferredBytes) / transferSpeed;
  }

  /// 检查是否已完成
  bool get isCompleted => state == TransferTaskState.completed;

  /// 检查是否被取消
  bool get isCancelled => state == TransferTaskState.cancelled;

  /// 检查是否出错
  bool get hasError => state == TransferTaskState.error;

  /// 标记为完成
  void markCompleted() {
    state = TransferTaskState.completed;
    transferredBytes = totalSize;
    endTime = DateTime.now();
  }

  /// 标记为取消
  void markCancelled() {
    state = TransferTaskState.cancelled;
    endTime = DateTime.now();
  }

  /// 标记为出错
  void markError(String message) {
    state = TransferTaskState.error;
    errorMessage = message;
    endTime = DateTime.now();
  }

  /// 更新进度
  void updateProgress(int bytes) {
    transferredBytes = bytes.clamp(0, totalSize);
    if (transferredBytes == totalSize) {
      markCompleted();
    }
  }
}

/// 任务控制服务
class TaskControlService {
  final JsonLinePeer _peer;
  
  final Map<String, TransferTask> _tasks = {};
  final StreamController<TransferTask> _taskController = StreamController<TransferTask>.broadcast();
  final StreamController<TransferTask> _progressController = StreamController<TransferTask>.broadcast();
  final StreamController<TransferTask> _cancellationController = StreamController<TransferTask>.broadcast();

  TaskControlService({
    required JsonLinePeer peer,
  }) : _peer = peer {
    _setupMessageListener();
  }

  /// 任务状态流
  Stream<TransferTask> get taskStream => _taskController.stream;
  
  /// 进度更新流
  Stream<TransferTask> get progressStream => _progressController.stream;
  
  /// 取消事件流
  Stream<TransferTask> get cancellationStream => _cancellationController.stream;

  /// 所有任务列表
  List<TransferTask> get tasks => _tasks.values.toList();

  /// 活动任务列表
  List<TransferTask> get activeTasks => _tasks.values
      .where((task) => task.state == TransferTaskState.transferring)
      .toList();

  /// 根据ID获取任务
  TransferTask? getTask(String transferId) {
    return _tasks[transferId];
  }

  /// 设置消息监听器
  void _setupMessageListener() {
    _peer.frames.listen((message) {
      final controlMessage = TcpControlMessage.fromJson(message);
      
      switch (controlMessage.op) {
        case TcpControlOp.cancel:
          _handleCancelRequest(controlMessage);
          break;
        case TcpControlOp.progress:
          _handleProgressReport(controlMessage);
          break;
        case TcpControlOp.ack:
          _handleAck(controlMessage);
          break;
        case TcpControlOp.error:
          _handleError(controlMessage);
          break;
        default:
          // 其他消息类型暂不处理
          break;
      }
    });
  }

  /// 创建新任务
  TransferTask createTask({
    required String transferId,
    required String fileName,
    required int totalSize,
  }) {
    final task = TransferTask(
      transferId: transferId,
      fileName: fileName,
      totalSize: totalSize,
    );
    
    _tasks[transferId] = task;
    _taskController.add(task);
    
    return task;
  }

  /// 开始传输任务
  void startTask(String transferId) {
    final task = _tasks[transferId];
    if (task != null && task.state == TransferTaskState.pending) {
      task.state = TransferTaskState.transferring;
      _taskController.add(task);
    }
  }

  /// 更新任务进度
  void updateTaskProgress(String transferId, int transferredBytes) {
    final task = _tasks[transferId];
    if (task != null && task.state == TransferTaskState.transferring) {
      task.updateProgress(transferredBytes);
      _progressController.add(task);
      
      // 定期发送进度报告（避免过于频繁）
      if (transferredBytes % (1024 * 1024) == 0 || // 每1MB发送一次
          transferredBytes == task.totalSize) {
        _sendProgressReport(task);
      }
    }
  }

  /// 完成任务
  void completeTask(String transferId) {
    final task = _tasks[transferId];
    if (task != null) {
      task.markCompleted();
      _taskController.add(task);
      _progressController.add(task);
      
      // 发送完成确认
      _sendAck(transferId);
    }
  }

  /// 取消任务（本地发起）
  void cancelTask(String transferId, {String? reason}) {
    final task = _tasks[transferId];
    if (task != null && !task.isCompleted && !task.isCancelled) {
      task.markCancelled();
      _cancellationController.add(task);
      _taskController.add(task);
      
      // 发送取消请求到对端
      _sendCancelRequest(transferId, reason: reason);
    }
  }

  /// 标记任务出错
  void markTaskError(String transferId, String errorMessage) {
    final task = _tasks[transferId];
    if (task != null) {
      task.markError(errorMessage);
      _taskController.add(task);
      
      // 发送错误通知到对端
      _sendError(transferId, errorMessage);
    }
  }

  /// 处理取消请求（从对端接收）
  void _handleCancelRequest(TcpControlMessage message) {
    final transferId = message.transferId;
    final task = _tasks[transferId];
    
    if (task != null && !task.isCompleted && !task.isCancelled) {
      task.markCancelled();
      _cancellationController.add(task);
      _taskController.add(task);
      
      // 发送确认响应
      _sendAck(transferId);
    }
  }

  /// 处理进度报告（从对端接收）
  void _handleProgressReport(TcpControlMessage message) {
    final transferId = message.transferId;
    final task = _tasks[transferId];
    final extra = message.extra ?? {};
    
    if (task != null) {
      final transferred = extra['transferred'] as int? ?? 0;
      final total = extra['total'] as int? ?? task.totalSize;
      
      task.updateProgress(transferred);
      _progressController.add(task);
    }
  }

  /// 处理确认响应
  void _handleAck(TcpControlMessage message) {
    final transferId = message.transferId;
    final task = _tasks[transferId];
    
    if (task != null) {
      // 确认响应可用于各种场景，这里可以扩展具体逻辑
      print('收到任务 $transferId 的确认响应');
    }
  }

  /// 处理错误通知
  void _handleError(TcpControlMessage message) {
    final transferId = message.transferId;
    final task = _tasks[transferId];
    final errorMessage = ErrorMessage.fromBase(message);
    
    if (task != null) {
      task.markError(errorMessage.errorMessage);
      _taskController.add(task);
    }
  }

  /// 发送取消请求
  void _sendCancelRequest(String transferId, {String? reason}) {
    final cancelMessage = CancelMessage(
      transferId: transferId,
      extra: reason != null ? {'reason': reason} : null,
    );
    _peer.send(cancelMessage.toJson());
  }

  /// 发送进度报告
  void _sendProgressReport(TransferTask task) {
    final progressMessage = ProgressMessage(
      transferId: task.transferId,
      transferred: task.transferredBytes,
      total: task.totalSize,
      extra: {
        'speed': task.transferSpeed,
        'eta': task.estimatedTimeRemaining,
      },
    );
    _peer.send(progressMessage.toJson());
  }

  /// 发送确认响应
  void _sendAck(String transferId) {
    final ackMessage = AckMessage(transferId: transferId);
    _peer.send(ackMessage.toJson());
  }

  /// 发送错误通知
  void _sendError(String transferId, String errorMessage) {
    final errorMessageObj = ErrorMessage(
      transferId: transferId,
      errorMessage: errorMessage,
    );
    _peer.send(errorMessageObj.toJson());
  }

  /// 移除任务
  void removeTask(String transferId) {
    _tasks.remove(transferId);
  }

  /// 清理已完成的任务
  void cleanupCompletedTasks() {
    final toRemove = <String>[];
    _tasks.forEach((id, task) {
      if (task.isCompleted || task.isCancelled || task.hasError) {
        final age = DateTime.now().difference(task.endTime ?? DateTime.now());
        if (age.inMinutes > 5) { // 保留5分钟的历史记录
          toRemove.add(id);
        }
      }
    });
    
    for (final id in toRemove) {
      _tasks.remove(id);
    }
  }

  /// 释放资源
  void dispose() {
    _taskController.close();
    _progressController.close();
    _cancellationController.close();
  }
}
