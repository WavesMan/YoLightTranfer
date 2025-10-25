import 'dart:async';

/// Stream工具函数
class StreamUtils {
  /// 创建一个带超时的Stream监听
  static StreamSubscription<T> listenWithTimeout<T>(
    Stream<T> stream,
    void Function(T event) onData, {
    Duration timeout = const Duration(seconds: 10),
    void Function()? onTimeout,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) {
    Timer? timeoutTimer;
    
    final subscription = stream.listen(
      (event) {
        // 重置超时定时器
        timeoutTimer?.cancel();
        timeoutTimer = Timer(timeout, () {
          onTimeout?.call();
        });
        
        onData(event);
      },
      onError: onError,
      onDone: () {
        timeoutTimer?.cancel();
        onDone?.call();
      },
    );
    
    // 启动初始超时定时器
    timeoutTimer = Timer(timeout, () {
      onTimeout?.call();
    });
    
    return subscription;
  }

  /// 创建一个带重试机制的Stream监听
  static StreamSubscription<T> listenWithRetry<T>(
    Stream<T> Function() streamFactory,
    void Function(T event) onData, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) {
    int retryCount = 0;
    StreamSubscription<T>? subscription;
    
    void startListening() {
      subscription = streamFactory().listen(
        onData,
        onError: (error, stackTrace) {
          if (retryCount < maxRetries) {
            retryCount++;
            print('Stream监听错误，第$retryCount次重试...');
            Future.delayed(retryDelay, startListening);
          } else {
            onError?.call(error, stackTrace);
          }
        },
        onDone: onDone,
      );
    }
    
    startListening();
    
    return subscription!;
  }

  /// 创建一个带缓冲的Stream转换器
  static StreamTransformer<T, T> bufferTransformer<T>({
    Duration bufferDuration = const Duration(milliseconds: 100),
    int? bufferCount,
  }) {
    return StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        // 这里可以实现缓冲逻辑
        // 当前直接传递数据
        sink.add(data);
      },
    );
  }

  /// 创建一个带过滤器的Stream
  static Stream<T> filteredStream<T>(
    Stream<T> source,
    bool Function(T) filter,
  ) {
    return source.where(filter);
  }

  /// 创建一个带映射的Stream
  static Stream<R> mappedStream<T, R>(
    Stream<T> source,
    R Function(T) mapper,
  ) {
    return source.map(mapper);
  }

  /// 合并多个Stream，处理重复事件
  static Stream<T> mergeStreams<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>();
    
    for (final stream in streams) {
      stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          // 当所有流都完成时关闭控制器
          // 这里简化处理，实际应该跟踪所有流的完成状态
        },
      );
    }
    
    return controller.stream;
  }

  /// 创建一个防抖Stream
  static Stream<T> debounceStream<T>(
    Stream<T> source,
    Duration duration,
  ) {
    Timer? timer;
    
    return source.transform(StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        timer?.cancel();
        timer = Timer(duration, () {
          sink.add(data);
        });
      },
      handleDone: (sink) {
        timer?.cancel();
        sink.close();
      },
    ));
  }

  /// 创建一个节流Stream
  static Stream<T> throttleStream<T>(
    Stream<T> source,
    Duration duration,
  ) {
    Timer? timer;
    T? lastData;
    bool hasData = false;
    
    return source.transform(StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        lastData = data;
        hasData = true;
        
        if (timer == null) {
          sink.add(data);
          hasData = false;
          
          timer = Timer(duration, () {
            timer = null;
            if (hasData && lastData != null) {
              sink.add(lastData!);
              hasData = false;
            }
          });
        }
      },
      handleDone: (sink) {
        timer?.cancel();
        if (hasData && lastData != null) {
          sink.add(lastData!);
        }
        sink.close();
      },
    ));
  }

  /// 检查Stream是否已关闭
  static bool isStreamClosed(Stream stream) {
    try {
      // 尝试监听Stream，如果已关闭会抛出异常
      stream.listen((_) {});
      return false;
    } catch (e) {
      return true;
    }
  }

  /// 安全地取消Stream订阅
  static void safeCancel(StreamSubscription? subscription) {
    try {
      subscription?.cancel();
    } catch (e) {
      // 忽略取消订阅时的错误
    }
  }

  /// 创建一个单次使用的Stream监听器
  static Future<T> listenOnce<T>(
    Stream<T> stream,
    Duration timeout,
  ) async {
    final completer = Completer<T>();
    StreamSubscription<T>? subscription;
    Timer? timeoutTimer;
    
    subscription = stream.listen(
      (data) {
        completer.complete(data);
        subscription?.cancel();
        timeoutTimer?.cancel();
      },
      onError: (error, stackTrace) {
        completer.completeError(error, stackTrace);
        subscription?.cancel();
        timeoutTimer?.cancel();
      },
    );
    
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Stream监听超时', timeout));
        subscription?.cancel();
      }
    });
    
    return completer.future;
  }

  /// 创建一个带错误恢复的Stream
  static Stream<T> withErrorRecovery<T>(
    Stream<T> source,
    Stream<T> Function(Object error, StackTrace stackTrace) recoveryStream,
  ) {
    final controller = StreamController<T>();
    StreamSubscription<T>? subscription;
    
    void startListening() {
      subscription = source.listen(
        controller.add,
        onError: (error, stackTrace) {
          print('Stream错误，尝试恢复: $error');
          try {
            final recovery = recoveryStream(error, stackTrace);
            subscription?.cancel();
            subscription = recovery.listen(
              controller.add,
              onError: controller.addError,
              onDone: controller.close,
            );
          } catch (e) {
            controller.addError(e);
          }
        },
        onDone: controller.close,
      );
    }
    
    startListening();
    
    controller.onCancel = () {
      subscription?.cancel();
    };
    
    return controller.stream;
  }

  /// 创建一个带背压控制的Stream
  static Stream<T> withBackpressure<T>(
    Stream<T> source,
    int bufferSize,
  ) {
    final controller = StreamController<T>();
    final buffer = <T>[];
    bool isPaused = false;
    StreamSubscription<T>? subscription;
    
    subscription = source.listen(
      (data) {
        buffer.add(data);
        
        if (buffer.length >= bufferSize && !isPaused) {
          isPaused = true;
          subscription?.pause();
        }
        
        if (!isPaused) {
          _drainBuffer(controller, buffer, subscription!, () {
            isPaused = false;
          });
        }
      },
      onError: controller.addError,
      onDone: () {
        _drainBuffer(controller, buffer, subscription!, () {});
        controller.close();
      },
    );
    
    controller.onListen = () {
      if (!isPaused && buffer.isNotEmpty) {
        _drainBuffer(controller, buffer, subscription!, () {
          isPaused = false;
        });
      }
    };
    
    return controller.stream;
  }

  /// 排空缓冲区
  static void _drainBuffer<T>(
    StreamController<T> controller,
    List<T> buffer,
    StreamSubscription<T> subscription,
    void Function() onDrained,
  ) {
    while (buffer.isNotEmpty) {
      final data = buffer.removeAt(0);
      controller.add(data);
    }
    
    if (subscription.isPaused) {
      subscription.resume();
    }
    
    onDrained();
  }
}
