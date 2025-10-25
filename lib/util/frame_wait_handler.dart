import 'dart:async';

/// 帧等待处理器：专门处理控制帧的等待逻辑
class FrameWaitHandler {
  final Stream<Map<String, dynamic>> _sourceStream;
  final Map<String, Completer<Map<String, dynamic>>> _pendingCompleters = {};
  final Map<String, Timer> _pendingTimers = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;

  FrameWaitHandler(this._sourceStream) {
    _startListening();
  }

  /// 开始监听Stream
  void _startListening() {
    _subscription = _sourceStream.listen(_handleFrame);
  }

  /// 处理接收到的帧
  void _handleFrame(Map<String, dynamic> frame) {
    final type = frame['type'] as String?;
    final forType = frame['for'] as String?;
    
    // 查找匹配的等待器
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
        if (!completer.isCompleted) {
          completer.complete(frame);
        }
        keysToRemove.add(key);
        
        // 取消对应的定时器
        final timer = _pendingTimers.remove(key);
        timer?.cancel();
      }
    }
    
    // 移除已完成的等待器
    for (final key in keysToRemove) {
      _pendingCompleters.remove(key);
    }
  }

  /// 等待特定类型的帧
  Future<Map<String, dynamic>> waitFor({
    required String type,
    String? forType,
    Duration timeout = const Duration(seconds: 10),
    bool cancelExisting = false,
  }) {
    final key = forType != null ? '$type|$forType' : type;
    
    // 如果已经有等待此帧的Completer
    if (_pendingCompleters.containsKey(key)) {
      if (cancelExisting) {
        // 取消现有的等待并创建新的
        final existingCompleter = _pendingCompleters[key]!;
        if (!existingCompleter.isCompleted) {
          existingCompleter.completeError(StateError('等待被新请求取消'));
        }
        _pendingCompleters.remove(key);
        
        final existingTimer = _pendingTimers.remove(key);
        existingTimer?.cancel();
      } else {
        // 返回同一个Future
        return _pendingCompleters[key]!.future;
      }
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

  /// 等待文件传输响应（接受或拒绝）
  Future<Map<String, dynamic>> waitForFileTransferResponse({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 使用race等待第一个响应
    final acceptedFuture = waitFor(
      type: 'FILE_TRANSFER_ACCEPTED',
      timeout: timeout,
    );
    
    final rejectedFuture = waitFor(
      type: 'FILE_TRANSFER_REJECTED',
      timeout: timeout,
    );
    
    try {
      final result = await Future.any([acceptedFuture, rejectedFuture]);
      return result;
    } catch (e) {
      // 如果两个都超时，抛出超时异常
      if (e is TimeoutException) {
        rethrow;
      }
      // 其他错误，重新抛出
      throw e;
    }
  }

  /// 等待ACK确认帧
  Future<Map<String, dynamic>> waitForAck({
    required String forType,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitFor(
      type: 'ACK',
      forType: forType,
      timeout: timeout,
    );
  }

  /// 等待错误帧
  Future<Map<String, dynamic>> waitForError({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return waitFor(
      type: 'ERROR',
      timeout: timeout,
    );
  }

  /// 批量等待多个帧类型
  Future<Map<String, dynamic>> waitForAny({
    required List<FrameWaitCondition> conditions,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final futures = <Future<Map<String, dynamic>>>[];
    
    for (final condition in conditions) {
      futures.add(waitFor(
        type: condition.type,
        forType: condition.forType,
        timeout: timeout,
      ));
    }
    
    try {
      final result = await Future.any(futures);
      return result;
    } catch (e) {
      // 如果所有都超时，抛出超时异常
      if (e is TimeoutException) {
        rethrow;
      }
      throw e;
    }
  }

  /// 取消特定类型的等待
  void cancelWait({
    required String type,
    String? forType,
    String reason = '用户取消',
  }) {
    final key = forType != null ? '$type|$forType' : type;
    
    final completer = _pendingCompleters.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError(reason));
    }
    
    final timer = _pendingTimers.remove(key);
    timer?.cancel();
  }

  /// 取消所有等待操作
  void cancelAllWaits([String reason = '用户取消']) {
    for (final completer in _pendingCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(reason));
      }
    }
    _pendingCompleters.clear();
    
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }

  /// 获取当前等待中的帧类型
  List<String> getPendingWaits() {
    return _pendingCompleters.keys.toList();
  }

  /// 检查是否有等待中的操作
  bool get hasPendingWaits => _pendingCompleters.isNotEmpty;

  /// 释放资源
  void dispose() {
    cancelAllWaits('处理器已释放');
    _subscription?.cancel();
    _subscription = null;
  }
}

/// 帧等待条件
class FrameWaitCondition {
  final String type;
  final String? forType;

  const FrameWaitCondition({
    required this.type,
    this.forType,
  });

  /// 创建ACK等待条件
  factory FrameWaitCondition.ack({required String forType}) {
    return FrameWaitCondition(type: 'ACK', forType: forType);
  }

  /// 创建错误等待条件
  factory FrameWaitCondition.error() {
    return FrameWaitCondition(type: 'ERROR');
  }

  /// 创建文件传输接受等待条件
  factory FrameWaitCondition.fileTransferAccepted() {
    return FrameWaitCondition(type: 'FILE_TRANSFER_ACCEPTED');
  }

  /// 创建文件传输拒绝等待条件
  factory FrameWaitCondition.fileTransferRejected() {
    return FrameWaitCondition(type: 'FILE_TRANSFER_REJECTED');
  }

  @override
  String toString() {
    return forType != null ? '$type|$forType' : type;
  }
}
