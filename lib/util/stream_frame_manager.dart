import 'dart:async';
import 'dart:convert';

/// Stream帧管理器：统一管理Stream监听，避免重复监听问题
class StreamFrameManager {
  final Stream<Map<String, dynamic>> _sourceStream;
  final StreamController<Map<String, dynamic>> _broadcastController;
  final Map<String, Completer<Map<String, dynamic>>> _pendingCompleters = {};
  final Map<String, Timer> _pendingTimers = {};

  StreamFrameManager(this._sourceStream)
      : _broadcastController = StreamController<Map<String, dynamic>>.broadcast() {
    _setupStreamListening();
  }

  /// 获取广播流
  Stream<Map<String, dynamic>> get broadcastStream => _broadcastController.stream;

  /// 设置Stream监听
  void _setupStreamListening() {
    _sourceStream.listen(
      (frame) {
        // 广播帧到所有监听器
        _broadcastController.add(frame);
        
        // 检查是否有等待此帧的Completer
        _checkPendingCompleters(frame);
      },
      onError: (error) {
        _broadcastController.addError(error);
        _cancelAllPendingCompleters('Stream error: $error');
      },
      onDone: () {
        _broadcastController.close();
        _cancelAllPendingCompleters('Stream closed');
      },
    );
  }

  /// 检查是否有等待此帧的Completer
  void _checkPendingCompleters(Map<String, dynamic> frame) {
    final type = frame['type'] as String?;
    final forType = frame['for'] as String?;
    
    // 生成匹配键
    final keysToRemove = <String>[];
    
    for (final key in _pendingCompleters.keys) {
      final parts = key.split('|');
      final expectedType = parts[0];
      final expectedForType = parts.length > 1 ? parts[1] : null;
      
      bool matches = type == expectedType;
      if (expectedForType != null) {
        matches = matches && forType == expectedForType;
      }
      
      if (matches) {
        final completer = _pendingCompleters[key]!;
        completer.complete(frame);
        keysToRemove.add(key);
        
        // 取消对应的定时器
        final timer = _pendingTimers.remove(key);
        timer?.cancel();
      }
    }
    
    // 移除已完成的Completer
    for (final key in keysToRemove) {
      _pendingCompleters.remove(key);
    }
  }

  /// 取消所有等待中的Completer
  void _cancelAllPendingCompleters(String reason) {
    for (final completer in _pendingCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(reason));
      }
    }
    _pendingCompleters.clear();
    
    // 取消所有定时器
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }

  /// 等待特定类型的帧
  Future<Map<String, dynamic>> waitForFrame({
    required String type,
    String? forType,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final key = forType != null ? '$type|$forType' : type;
    
    // 如果已经有等待此帧的Completer，返回同一个Future
    if (_pendingCompleters.containsKey(key)) {
      return _pendingCompleters[key]!.future;
    }
    
    final completer = Completer<Map<String, dynamic>>();
    _pendingCompleters[key] = completer;
    
    // 设置超时定时器
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('等待帧超时: type=$type, for=$forType', timeout));
        _pendingCompleters.remove(key);
        _pendingTimers.remove(key);
      }
    });
    
    _pendingTimers[key] = timer;
    
    return completer.future;
  }

  /// 等待文件传输接受响应
  Future<Map<String, dynamic>> waitForFileTransferAccepted({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForFrame(
      type: 'FILE_TRANSFER_ACCEPTED',
      timeout: timeout,
    );
  }

  /// 等待文件传输拒绝响应
  Future<Map<String, dynamic>> waitForFileTransferRejected({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForFrame(
      type: 'FILE_TRANSFER_REJECTED',
      timeout: timeout,
    );
  }

  /// 等待ACK确认帧
  Future<Map<String, dynamic>> waitForAck({
    required String forType,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForFrame(
      type: 'ACK',
      forType: forType,
      timeout: timeout,
    );
  }

  /// 等待文件结束确认
  Future<Map<String, dynamic>> waitForFileEndAck({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForAck(forType: 'FILE_END', timeout: timeout);
  }

  /// 等待文件元数据确认
  Future<Map<String, dynamic>> waitForFileMetaAck({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForAck(forType: 'FILE_META', timeout: timeout);
  }

  /// 等待分片确认
  Future<Map<String, dynamic>> waitForChunkAck({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForAck(forType: 'CHUNK', timeout: timeout);
  }

  /// 等待错误帧
  Future<Map<String, dynamic>> waitForError({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitForFrame(
      type: 'ERROR',
      timeout: timeout,
    );
  }

  /// 取消所有等待操作
  void cancelAllWaits([String reason = '用户取消']) {
    _cancelAllPendingCompleters(reason);
  }

  /// 释放资源
  void dispose() {
    cancelAllWaits('管理器已释放');
    _broadcastController.close();
  }
}
