import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';

/// 多线程哈希计算服务
class MultiThreadHashService {
  static const int _defaultChunkSize = 1024 * 1024; // 1MB
  static const int _maxIsolates = 4; // 最大并发Isolate数量

  /// 使用多线程计算文件哈希（最终哈希值）
  static Future<String> calculateFileHash(
    String filePath, {
    int chunkSize = _defaultChunkSize,
    int maxConcurrent = _maxIsolates,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    
    // 如果文件较小，使用单线程计算
    if (fileSize < chunkSize * 2) {
      return await _calculateSingleThreadHash(file);
    }

    // 计算分块数量
    final chunkCount = (fileSize / chunkSize).ceil();
    final chunksPerIsolate = (chunkCount / maxConcurrent).ceil();
    
    print('🔢 多线程哈希计算 - 文件大小: ${fileSize} bytes, 分块数: $chunkCount, 并发数: $maxConcurrent');

    // 创建Isolate池并行读取文件块
    final isolates = <Isolate>[];
    final receivePorts = <ReceivePort>[];
    final chunkDataMap = <int, List<int>>{};

    try {
      // 启动Isolate并行读取文件块
      for (int i = 0; i < maxConcurrent; i++) {
        final startChunk = i * chunksPerIsolate;
        final endChunk = (i + 1) * chunksPerIsolate;
        
        if (startChunk >= chunkCount) break;

        final receivePort = ReceivePort();
        receivePorts.add(receivePort);

        final isolate = await Isolate.spawn(
          _chunkReaderWorker,
          _ChunkReaderData(
            filePath: filePath,
            chunkSize: chunkSize,
            startChunk: startChunk,
            endChunk: endChunk.min(chunkCount),
            sendPort: receivePort.sendPort,
          ),
        );
        isolates.add(isolate);

        // 监听结果
        final completer = Completer<Map<int, List<int>>>();
        receivePort.listen((message) {
          if (message is Map<int, List<int>>) {
            completer.complete(message);
          }
        });

        final chunkMap = await completer.future;
        chunkDataMap.addAll(chunkMap);
      }

      // 按顺序合并所有分块数据，计算最终哈希
      final allBytes = <int>[];
      for (int i = 0; i < chunkCount; i++) {
        if (chunkDataMap.containsKey(i)) {
          allBytes.addAll(chunkDataMap[i]!);
        }
      }

      final finalHash = sha256.convert(allBytes).toString();
      return finalHash;
    } finally {
      // 清理资源
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.immediate);
      }
      for (final receivePort in receivePorts) {
        receivePort.close();
      }
    }
  }

  /// Isolate工作函数：读取文件块
  static void _chunkReaderWorker(_ChunkReaderData data) {
    final file = File(data.filePath);
    final randomAccessFile = file.openSync();
    final chunkMap = <int, List<int>>{};

    try {
      for (int chunkIndex = data.startChunk; chunkIndex < data.endChunk; chunkIndex++) {
        final start = chunkIndex * data.chunkSize;
        final end = (chunkIndex + 1) * data.chunkSize;
        
        final buffer = randomAccessFile.readSync(end - start);
        chunkMap[chunkIndex] = buffer;
      }

      data.sendPort.send(chunkMap);
    } catch (e) {
      data.sendPort.send({});
    } finally {
      randomAccessFile.closeSync();
    }
  }

  /// 单线程哈希计算（用于小文件）
  static Future<String> _calculateSingleThreadHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}

/// Isolate工作数据：文件块读取
class _ChunkReaderData {
  final String filePath;
  final int chunkSize;
  final int startChunk;
  final int endChunk;
  final SendPort sendPort;

  _ChunkReaderData({
    required this.filePath,
    required this.chunkSize,
    required this.startChunk,
    required this.endChunk,
    required this.sendPort,
  });
}

/// 扩展方法：为int添加min方法
extension IntExtensions on int {
  int min(int other) => this < other ? this : other;
}
