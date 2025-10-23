import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// 文件哈希服务：提供SHA256哈希计算和验证功能
class FileHashService {
  
  /// 计算文件的SHA256哈希值
  static Future<String> calculateFileHash(String filePath) async {
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
      final digest = await sha256.bind(inputStream).first;
      
      return digest.toString();
    } catch (e) {
      print('计算文件哈希失败: $e');
      rethrow;
    }
  }
  
  /// 计算字节数据的SHA256哈希值
  static String calculateBytesHash(List<int> bytes) {
    try {
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('计算字节数据哈希失败: $e');
      rethrow;
    }
  }
  
  /// 验证文件哈希值是否匹配
  static Future<bool> verifyFileHash(String filePath, String expectedHash) async {
    try {
      final actualHash = await calculateFileHash(filePath);
      return actualHash == expectedHash;
    } catch (e) {
      print('验证文件哈希失败: $e');
      return false;
    }
  }
  
  /// 验证字节数据哈希值是否匹配
  static bool verifyBytesHash(List<int> bytes, String expectedHash) {
    try {
      final actualHash = calculateBytesHash(bytes);
      return actualHash == expectedHash;
    } catch (e) {
      print('验证字节数据哈希失败: $e');
      return false;
    }
  }
  
  /// 获取文件大小和哈希值的组合信息
  static Future<Map<String, dynamic>> getFileHashInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final fileSize = await file.length();
      final hash = await calculateFileHash(filePath);
      
      return {
        'filePath': filePath,
        'fileSize': fileSize,
        'sha256': hash,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      print('获取文件哈希信息失败: $e');
      rethrow;
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
  static bool isValidHash(String hash) {
    // SHA256哈希值应该是64个十六进制字符
    final regex = RegExp(r'^[a-fA-F0-9]{64}$');
    return regex.hasMatch(hash);
  }
}
