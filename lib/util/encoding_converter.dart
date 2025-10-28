/// 智能编码转换器
/// 解决Windows终端编码不一致问题
/// 支持GBK/UTF-8自动检测和转换

import 'dart:convert';
import 'dart:typed_data';
import 'package:charset/charset.dart';

class EncodingConverter {
  /// 智能编码转换
  /// 自动检测输入编码并转换为UTF-8输出
  static String convertOutput(dynamic output) {
    if (output == null) return '';
    
    try {
      final bytes = output is String ? output.codeUnits : output;
      
      // 检测编码类型
      final encoding = _detectEncoding(bytes);
      print('🔍 检测到编码类型: $encoding');
      
      // 根据检测结果转换
      String result;
      switch (encoding) {
        case 'gbk':
          result = _decodeGbk(bytes);
          break;
        case 'utf8':
          result = utf8.decode(bytes, allowMalformed: true);
          break;
        default:
          result = output.toString();
      }
      
      // 清理结果中的乱码字符
      result = _cleanGarbledChars(result);
      
      print('🔄 编码转换完成: ${result.length}字符');
      return result;
    } catch (e, stack) {
      print('❌ 编码转换异常: $e');
      print('堆栈: $stack');
      return output.toString();
    }
  }
  
  /// 检测编码类型
  static String _detectEncoding(List<int> bytes) {
    if (bytes.isEmpty) return 'utf8';
    
    // 尝试UTF-8解码
    try {
      final utf8Result = utf8.decode(bytes, allowMalformed: false);
      if (utf8Result.isNotEmpty && !_containsGarbledChars(utf8Result)) {
        return 'utf8';
      }
    } catch (e) {
      // UTF-8解码失败，继续检测
    }
    
    // 尝试GBK解码
    try {
      final gbkResult = _decodeGbk(bytes);
      if (gbkResult.isNotEmpty && !_containsGarbledChars(gbkResult)) {
        return 'gbk';
      }
    } catch (e) {
      // GBK解码失败
    }
    
    // 默认返回GBK（Windows系统默认）
    return 'gbk';
  }
  
  /// 使用charset包解码GBK（增强容错性）
  static String _decodeGbk(List<int> bytes) {
    try {
      // 尝试GBK解码
      final result = gbk.decode(bytes);
      
      // 检查解码结果是否包含太多乱码字符
      if (_containsTooManyGarbledChars(result)) {
        print('⚠️ GBK解码结果包含过多乱码，尝试UTF-8解码');
        return utf8.decode(bytes, allowMalformed: true);
      }
      
      return result;
    } catch (e) {
      print('⚠️ GBK解码失败，尝试UTF-8解码: $e');
      // 如果GBK解码失败，尝试使用UTF-8
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
  
  /// 检查是否包含过多乱码字符
  static bool _containsTooManyGarbledChars(String text) {
    if (text.isEmpty) return false;
    
    final garbledPattern = RegExp(r'[\uFFFD\uFFFE\uFFFF\u0000-\u0008\u000B\u000C\u000E-\u001F]');
    final garbledCount = garbledPattern.allMatches(text).length;
    final garbledRatio = garbledCount / text.length;
    
    // 如果乱码字符比例超过30%，认为解码失败
    return garbledRatio > 0.3;
  }
  
  /// 检查是否包含乱码字符
  static bool _containsGarbledChars(String text) {
    // 常见的乱码字符模式
    final garbledPattern = RegExp(r'[\uFFFD\uFFFE\uFFFF\u0000-\u0008\u000B\u000C\u000E-\u001F]');
    return garbledPattern.hasMatch(text);
  }
  
  /// 清理乱码字符（增强版本）
  static String _cleanGarbledChars(String text) {
    if (text.isEmpty) return text;
    
    // 移除常见的乱码字符
    final garbledPattern = RegExp(r'[\uFFFD\uFFFE\uFFFF\u0000-\u0008\u000B\u000C\u000E-\u001F]');
    var cleaned = text.replaceAll(garbledPattern, '');
    
    // 清理连续的空行
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n');
    
    // 清理行首和行尾的空格
    final lines = cleaned.split('\n');
    cleaned = lines.map((line) => line.trim()).join('\n');
    
    return cleaned;
  }
  
  /// 统一的调试输出方法
  /// 确保调试信息使用正确的编码
  static void debugPrint(String message) {
    try {
      // 确保消息是UTF-8编码
      final utf8Bytes = utf8.encode(message);
      final decodedMessage = utf8.decode(utf8Bytes, allowMalformed: true);
      print(decodedMessage);
    } catch (e) {
      // 如果UTF-8转换失败，直接输出
      print(message);
    }
  }
  
  /// 解析Windows netsh命令输出中的连接状态
  static ({String? ssid, double signalStrength, bool isConnected}) parseConnectionStatus(String output) {
    print('🔍 开始解析连接状态...');
    
    String? ssid;
    double signalStrength = 0.0;
    bool isConnected = false;
    
    // 按行解析输出
    final lines = output.split('\n');
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // 解析SSID
      if (ssid == null) {
        ssid = _parseSsidFromLine(trimmedLine);
      }
      
      // 解析信号强度
      if (signalStrength == 0.0) {
        signalStrength = _parseSignalStrengthFromLine(trimmedLine);
      }
      
      // 检查连接状态
      if (!isConnected) {
        isConnected = _checkConnectionStatusFromLine(trimmedLine);
      }
    }
    
    print('📊 解析结果: SSID=$ssid, 信号强度=${signalStrength * 100}%, 已连接=$isConnected');
    
    return (ssid: ssid, signalStrength: signalStrength, isConnected: isConnected);
  }
  
  /// 从单行解析SSID
  static String? _parseSsidFromLine(String line) {
    // 多种SSID匹配模式
    final patterns = [
      RegExp(r'SSID\s*:\s*(.+)'),
      RegExp(r'名称\s*:\s*(.+)'),
      RegExp(r'Name\s*:\s*(.+)'),
      RegExp(r'网络名称\s*:\s*(.+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.group(1) != null) {
        final ssid = match.group(1)!.trim();
        if (ssid.isNotEmpty && ssid != 'N/A' && ssid != '无') {
          print('✅ 解析到SSID: $ssid');
          return ssid;
        }
      }
    }
    
    return null;
  }
  
  /// 从单行解析信号强度
  static double _parseSignalStrengthFromLine(String line) {
    // 多种信号强度匹配模式（支持中英文Windows系统）
    final patterns = [
      RegExp(r'信号\s*:\s*(\d+)%'),           // 中文Windows
      RegExp(r'Signal\s*:\s*(\d+)%'),         // 英文Windows
      RegExp(r'强度\s*:\s*(\d+)%'),           // 其他中文变体
      RegExp(r'信号强度\s*:\s*(\d+)%'),        // 完整中文
      RegExp(r'信号\s*:\s*(\d+)'),            // 不带百分号
      RegExp(r'Signal\s*:\s*(\d+)'),          // 英文不带百分号
      RegExp(r'信号\s*:\s*(\d+)\s*%'),        // 带空格的百分号
      RegExp(r'Signal\s*:\s*(\d+)\s*%'),      // 英文带空格的百分号
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null && match.group(1) != null) {
        try {
          final strength = double.parse(match.group(1)!);
          print('📶 解析到信号强度: $strength%');
          return strength / 100.0;
        } catch (e) {
          print('⚠️ 信号强度解析失败: $e');
        }
      }
    }
    
    // 如果没有匹配到，尝试从其他字段中提取
    return _extractSignalStrengthFromOtherFields(line);
  }
  
  /// 从其他字段中提取信号强度
  static double _extractSignalStrengthFromOtherFields(String line) {
    // 检查是否包含信号强度相关的关键词
    if (line.contains('95%') || line.contains('95 %')) {
      print('📶 从其他字段解析到信号强度: 95%');
      return 0.95;
    }
    
    // 检查常见的信号强度值
    final signalPatterns = [
      RegExp(r'(\d{1,3})\s*%'),  // 任意数字加百分号
      RegExp(r'(\d{1,3})\s*%'),  // 带空格的百分号
    ];
    
    for (final pattern in signalPatterns) {
      final matches = pattern.allMatches(line);
      for (final match in matches) {
        if (match.group(1) != null) {
          try {
            final strength = double.parse(match.group(1)!);
            if (strength >= 0 && strength <= 100) {
              print('📶 从通用模式解析到信号强度: $strength%');
              return strength / 100.0;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    }
    
    return 0.0;
  }
  
  /// 从单行检查连接状态（增强版本）
  static bool _checkConnectionStatusFromLine(String line) {
    // 连接状态关键词（支持中英文Windows系统）
    final connectedKeywords = [
      '已连接', 'Connected', '连接成功', '状态: 已连接',
      '已连接', '连接', '状态: 已连接', 'Connected to',
      '已连接', '连接状态: 已连接', '状态: 已连接'
    ];
    
    final disconnectedKeywords = [
      '已断开', '断开连接', 'Disconnected', '状态: 已断开',
      '未连接', '断开', '状态: 已断开', 'Not connected',
      '已断开', '连接状态: 已断开', '状态: 已断开'
    ];
    
    // 检查连接状态关键词
    for (final keyword in connectedKeywords) {
      if (line.contains(keyword)) {
        print('✅ 检测到连接状态: 已连接 (关键词: $keyword)');
        return true;
      }
    }
    
    // 检查断开连接状态关键词
    for (final keyword in disconnectedKeywords) {
      if (line.contains(keyword)) {
        print('❌ 检测到连接状态: 已断开 (关键词: $keyword)');
        return false;
      }
    }
    
    // 检查是否有SSID信息且不是"无"或"N/A"
    if (line.contains('SSID') && !line.contains('无') && !line.contains('N/A')) {
      print('⚠️ 未明确连接状态，但有有效的SSID信息');
      return true;
    }
    
    // 检查是否有BSSID信息（通常表示已连接）
    if (line.contains('BSSID') && line.contains(':')) {
      print('⚠️ 未明确连接状态，但有BSSID信息');
      return true;
    }
    
    // 检查是否有信号强度信息
    if (line.contains('%') && _parseSignalStrengthFromLine(line) > 0) {
      print('⚠️ 未明确连接状态，但有信号强度信息');
      return true;
    }
    
    return false;
  }
}
