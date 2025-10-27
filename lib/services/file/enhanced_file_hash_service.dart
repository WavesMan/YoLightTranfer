import 'dart:io';
import 'package:crypto/crypto.dart';

/// 哈希算法类型
enum HashAlgorithm {
  sha256,
}

/// 哈希算法扩展方法
extension HashAlgorithmExtension on HashAlgorithm {
  /// 获取算法名称
  String get name {
    switch (this) {
      case HashAlgorithm.sha256:
        return 'SHA-256';
    }
  }

  /// 获取哈希值长度（字符数）
  int get length {
    switch (this) {
      case HashAlgorithm.sha256:
        return 64;
    }
  }
}

/// 增强的文件哈希服务：支持多种哈希算法和完整性验证
class EnhancedFileHashService {
  
  /// 计算文件的哈希值（支持多种算法）
  static Future<String> calculateFileHash(
    String filePath, {
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('文件为空: $filePath');
      }
      
      // 使用流式读取计算哈希，避免内存溢出
      final inputStream = file.openRead();
      final digest = await _getHashStream(inputStream, algorithm).first;
      
      return digest.toString();
    } catch (e) {
      print('计算文件哈希失败: $e');
      rethrow;
    }
  }

  /// 计算字节数据的哈希值
  static String calculateBytesHash(
    List<int> bytes, {
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) {
    try {
      final digest = _getHashConverter(algorithm).convert(bytes);
      return digest.toString();
    } catch (e) {
      print('计算字节数据哈希失败: $e');
      rethrow;
    }
  }

  /// 验证文件哈希值是否匹配
  static Future<bool> verifyFileHash(
    String filePath, 
    String expectedHash, {
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) async {
    try {
      final actualHash = await calculateFileHash(filePath, algorithm: algorithm);
      return actualHash == expectedHash;
    } catch (e) {
      print('验证文件哈希失败: $e');
      return false;
    }
  }

  /// 验证字节数据哈希值是否匹配
  static bool verifyBytesHash(
    List<int> bytes, 
    String expectedHash, {
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) {
    try {
      final actualHash = calculateBytesHash(bytes, algorithm: algorithm);
      return actualHash == expectedHash;
    } catch (e) {
      print('验证字节数据哈希失败: $e');
      return false;
    }
  }

  /// 获取文件的完整哈希信息
  static Future<Map<String, dynamic>> getFileHashInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final fileSize = await file.length();
      final fileName = filePath.split(Platform.pathSeparator).last;
      
      // 计算SHA-256哈希值
      final sha256Hash = await calculateFileHash(filePath, algorithm: HashAlgorithm.sha256);
      
      return {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'sha256': sha256Hash,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'fileSizeText': _formatFileSize(fileSize),
      };
    } catch (e) {
      print('获取文件哈希信息失败: $e');
      rethrow;
    }
  }

  /// 计算文件的增量哈希（用于大文件校验）
  static Future<Map<String, dynamic>> calculateIncrementalHash(
    String filePath, {
    int chunkSize = 1024 * 1024, // 1MB
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final fileSize = await file.length();
      final totalChunks = (fileSize / chunkSize).ceil();
      
      final chunkHashes = <String>[];
      final randomAccessFile = await file.open();
      
      for (int i = 0; i < totalChunks; i++) {
        final offset = i * chunkSize;
        final remainingBytes = fileSize - offset;
        final currentChunkSize = remainingBytes < chunkSize ? remainingBytes : chunkSize;
        
        final chunkBytes = await randomAccessFile.read(currentChunkSize);
        final chunkHash = calculateBytesHash(chunkBytes, algorithm: algorithm);
        chunkHashes.add(chunkHash);
      }
      
      await randomAccessFile.close();
      
      // 计算整体哈希
      final overallHash = calculateBytesHash(
        chunkHashes.join().codeUnits,
        algorithm: algorithm,
      );
      
      return {
        'filePath': filePath,
        'fileSize': fileSize,
        'chunkSize': chunkSize,
        'totalChunks': totalChunks,
        'overallHash': overallHash,
        'chunkHashes': chunkHashes,
        'algorithm': algorithm.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      print('计算增量哈希失败: $e');
      rethrow;
    }
  }

  /// 验证增量哈希
  static Future<bool> verifyIncrementalHash(
    String filePath,
    Map<String, dynamic> hashInfo,
  ) async {
    try {
      final calculatedHashInfo = await calculateIncrementalHash(
        filePath,
        chunkSize: hashInfo['chunkSize'] ?? 1024 * 1024,
        algorithm: _parseHashAlgorithm(hashInfo['algorithm']),
      );
      
      return calculatedHashInfo['overallHash'] == hashInfo['overallHash'];
    } catch (e) {
      print('验证增量哈希失败: $e');
      return false;
    }
  }

  /// 格式化哈希值用于显示
  static String formatHashForDisplay(String hash, {int maxLength = 16}) {
    if (hash.length <= maxLength) {
      return hash;
    }
    return '${hash.substring(0, maxLength)}...';
  }

  /// 检查哈希值格式是否有效
  static bool isValidHash(String hash, {HashAlgorithm? algorithm}) {
    if (algorithm != null) {
      return hash.length == algorithm.length && 
             RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash);
    }
    
    // 自动检测算法 - 仅支持SHA-256
    if (hash.length == HashAlgorithm.sha256.length) {
      return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash);
    }
    
    return false;
  }

  /// 获取哈希算法描述
  static String getHashAlgorithmDescription(HashAlgorithm algorithm) {
    switch (algorithm) {
      case HashAlgorithm.sha256:
        return 'SHA-256 (256位，64字符) - 推荐用于文件完整性验证';
    }
  }

  /// 比较两个哈希值是否相同
  static bool compareHashes(String hash1, String hash2) {
    return hash1.toLowerCase() == hash2.toLowerCase();
  }

  /// 获取推荐的哈希算法
  static HashAlgorithm getRecommendedAlgorithm() {
    return HashAlgorithm.sha256;
  }

  // 私有方法

  /// 获取哈希流
  static Stream<Digest> _getHashStream(
    Stream<List<int>> stream, 
    HashAlgorithm algorithm,
  ) {
    switch (algorithm) {
      case HashAlgorithm.sha256:
        return sha256.bind(stream);
    }
  }

  /// 获取哈希转换器
  static Hash _getHashConverter(HashAlgorithm algorithm) {
    switch (algorithm) {
      case HashAlgorithm.sha256:
        return sha256;
    }
  }

  /// 解析哈希算法
  static HashAlgorithm _parseHashAlgorithm(String? algorithmName) {
    switch (algorithmName?.toLowerCase()) {
      case 'sha256':
      case 'sha-256':
        return HashAlgorithm.sha256;
      default:
        return HashAlgorithm.sha256;
    }
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
