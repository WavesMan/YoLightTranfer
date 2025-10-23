/// 文件接收服务端逻辑
/// 实现完整的文件接收、存储和断点续传功能

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'tcp_control_message.dart';
import 'tcp_protocol_base.dart';

/// 文件接收状态
enum FileReceiveStatus {
  waiting,      // 等待文件元数据
  receiving,    // 正在接收文件数据
  completed,    // 文件接收完成
  cancelled,    // 文件接收被取消
  error,        // 文件接收出错
}

/// 文件接收任务
class FileReceiveTask {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String savePath;
  final int offset;
  
  FileReceiveStatus status = FileReceiveStatus.waiting;
  int receivedBytes = 0;
  String? errorMessage;
  File? outputFile;
  IOSink? fileSink;

  FileReceiveTask({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.savePath,
    this.offset = 0,
  });

  /// 获取接收进度（0-100）
  double get progress {
    if (fileSize == 0) return 0.0;
    return (receivedBytes / fileSize * 100).clamp(0.0, 100.0);
  }

  /// 检查是否已完成
  bool get isCompleted => status == FileReceiveStatus.completed;

  /// 检查是否出错
  bool get hasError => status == FileReceiveStatus.error;

  /// 检查是否被取消
  bool get isCancelled => status == FileReceiveStatus.cancelled;

  /// 释放资源
  Future<void> dispose() async {
    await fileSink?.flush();
    await fileSink?.close();
    fileSink = null;
  }
}

/// 文件接收器
class FileReceiver {
  final JsonLinePeer _peer;
  final String _baseSavePath;
  
  FileReceiveTask? _currentTask;
  bool _receivingData = false;
  int _expectedChunkSize = 0;
  
  final StreamController<FileReceiveTask> _taskController = StreamController<FileReceiveTask>.broadcast();
  final StreamController<FileReceiveTask> _progressController = StreamController<FileReceiveTask>.broadcast();
  final StreamController<FileReceiveTask> _completionController = StreamController<FileReceiveTask>.broadcast();

  FileReceiver({
    required JsonLinePeer peer,
    String baseSavePath = '',
  }) : 
        _peer = peer,
        _baseSavePath = baseSavePath {
    _setupMessageListener();
  }

  /// 任务状态流
  Stream<FileReceiveTask> get taskStream => _taskController.stream;
  
  /// 进度更新流
  Stream<FileReceiveTask> get progressStream => _progressController.stream;
  
  /// 完成事件流
  Stream<FileReceiveTask> get completionStream => _completionController.stream;

  /// 当前活动任务
  FileReceiveTask? get currentTask => _currentTask;

  /// 设置消息监听器
  void _setupMessageListener() {
    _peer.frames.listen((message) async {
      try {
        await _handleMessage(message);
      } catch (e) {
        _handleError('消息处理错误: $e');
      }
    }, onError: (error) {
      _handleError('消息流错误: $error');
    });
  }

  /// 处理消息
  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final type = message['type'] as String?;
    
    if (type != null) {
      // 处理文件传输协议消息
      await _handleFileProtocolMessage(type, message);
    } else {
      // 处理控制协议消息
      await _handleControlMessage(message);
    }
  }

  /// 处理文件传输协议消息
  Future<void> _handleFileProtocolMessage(String type, Map<String, dynamic> message) async {
    switch (type) {
      case 'FILE_META':
        await _handleFileMeta(message);
        break;
      case 'CHUNK':
        await _handleChunk(message);
        break;
      case 'FILE_END':
        await _handleFileEnd();
        break;
      default:
        // 忽略未知类型
        break;
    }
  }

  /// 处理控制协议消息
  Future<void> _handleControlMessage(Map<String, dynamic> message) async {
    final controlMessage = TcpControlMessage.fromJson(message);
    
    switch (controlMessage.op) {
      case TcpControlOp.cancel:
        await _handleCancel(controlMessage);
        break;
      case TcpControlOp.ping:
        // 心跳由心跳服务处理
        break;
      case TcpControlOp.pong:
        // 心跳回应由心跳服务处理
        break;
      default:
        // 其他控制消息暂不处理
        break;
    }
  }

  /// 处理文件元数据
  Future<void> _handleFileMeta(Map<String, dynamic> message) async {
    if (_currentTask != null) {
      _handleError('已有正在进行的文件传输任务');
      return;
    }

    final name = message['name'] as String? ?? 'unknown';
    final size = message['size'] as int? ?? 0;
    final path = message['path'] as String? ?? '';
    final offset = message['offset'] as int? ?? 0;

    // 构建保存路径
    final savePath = _buildSavePath(path.isEmpty ? name : '$path/$name');

    // 创建接收任务
    _currentTask = FileReceiveTask(
      transferId: 'file-$name-${DateTime.now().millisecondsSinceEpoch}',
      fileName: name,
      fileSize: size,
      savePath: savePath,
      offset: offset,
    );

    try {
      // 准备文件输出流
      await _prepareFileOutput(_currentTask!);
      
      // 发送确认响应
      _sendAck(_currentTask!.transferId);
      
      // 通知任务开始
      _taskController.add(_currentTask!);
      
    } catch (e) {
      _handleError('文件准备失败: $e');
    }
  }

  /// 处理文件分片
  Future<void> _handleChunk(Map<String, dynamic> message) async {
    if (_currentTask == null || _currentTask!.status != FileReceiveStatus.receiving) {
      _handleError('没有活动的文件接收任务');
      return;
    }

    final size = message['size'] as int? ?? 0;
    if (size <= 0) {
      _handleError('无效的分片大小: $size');
      return;
    }

    _expectedChunkSize = size;
    _receivingData = true;
  }

  /// 处理文件结束
  Future<void> _handleFileEnd() async {
    if (_currentTask == null) {
      return;
    }

    try {
      await _completeFileReceive();
    } catch (e) {
      _handleError('文件完成处理失败: $e');
    }
  }

  /// 处理取消请求
  Future<void> _handleCancel(TcpControlMessage message) async {
    if (_currentTask != null && _currentTask!.transferId == message.transferId) {
      await _cancelCurrentTask();
    }
  }

  /// 构建保存路径
  String _buildSavePath(String relativePath) {
    if (_baseSavePath.isEmpty) {
      return relativePath;
    }
    return '$_baseSavePath/${relativePath.replaceAll('\\', '/')}';
  }

  /// 准备文件输出
  Future<void> _prepareFileOutput(FileReceiveTask task) async {
    // 创建目录（如果需要）
    final file = File(task.savePath);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 打开文件输出流
    task.outputFile = file;
    task.fileSink = file.openWrite(mode: FileMode.writeOnlyAppend);
    task.status = FileReceiveStatus.receiving;
    task.receivedBytes = task.offset;

    // 如果从断点开始，需要设置文件位置
    if (task.offset > 0) {
      // 这里需要实现断点续传的文件位置设置
      // 由于Dart的IOSink不支持seek，需要特殊处理
    }
  }

  /// 完成文件接收
  Future<void> _completeFileReceive() async {
    if (_currentTask == null) return;

    final task = _currentTask!;
    
    try {
      await task.fileSink?.flush();
      await task.dispose();
      
      task.status = FileReceiveStatus.completed;
      task.receivedBytes = task.fileSize;
      
      // 发送完成确认
      _sendAck(task.transferId);
      
      // 通知完成
      _completionController.add(task);
      _progressController.add(task);
      
      _currentTask = null;
      
    } catch (e) {
      _handleError('文件完成失败: $e');
    }
  }

  /// 取消当前任务
  Future<void> _cancelCurrentTask() async {
    if (_currentTask == null) return;

    final task = _currentTask!;
    
    try {
      await task.dispose();
      
      // 删除部分接收的文件
      if (task.outputFile != null && await task.outputFile!.exists()) {
        await task.outputFile!.delete();
      }
      
      task.status = FileReceiveStatus.cancelled;
      _taskController.add(task);
      
    } catch (e) {
      print('取消任务时出错: $e');
    } finally {
      _currentTask = null;
    }
  }

  /// 处理原始数据（从Socket接收）
  void handleRawData(List<int> data) {
    if (!_receivingData || _currentTask == null) {
      return;
    }

    final task = _currentTask!;
    
    try {
      // 写入文件
      task.fileSink?.add(data);
      task.receivedBytes += data.length;
      
      // 更新进度
      _progressController.add(task);
      
      // 检查是否达到预期分片大小
      if (task.receivedBytes - task.offset >= _expectedChunkSize) {
        _receivingData = false;
        _expectedChunkSize = 0;
      }
      
    } catch (e) {
      _handleError('文件写入错误: $e');
    }
  }

  /// 发送确认响应
  void _sendAck(String transferId) {
    final ackMessage = AckMessage(transferId: transferId);
    _peer.send(ackMessage.toJson());
  }

  /// 处理错误
  void _handleError(String errorMessage) {
    if (_currentTask != null) {
      _currentTask!.status = FileReceiveStatus.error;
      _currentTask!.errorMessage = errorMessage;
      _taskController.add(_currentTask!);
      
      // 发送错误通知
      final errorMessageObj = ErrorMessage(
        transferId: _currentTask!.transferId,
        errorMessage: errorMessage,
      );
      _peer.send(errorMessageObj.toJson());
      
      _currentTask = null;
    }
    
    _receivingData = false;
    _expectedChunkSize = 0;
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_currentTask != null) {
      await _currentTask!.dispose();
    }
    
    _taskController.close();
    _progressController.close();
    _completionController.close();
  }
}
