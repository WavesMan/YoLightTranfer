import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yolighttransfer/util/version_check_parser.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  
  late String _version;
  late String _buildNumber;
  bool _initialized = false;

  VersionService._internal();

  factory VersionService() {
    return _instance;
  }

  /// 初始化版本信息
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final configContent = await rootBundle.loadString('lib/config.yaml');
      
      // 简单的 YAML 解析（只解析我们需要的字段）
      final lines = configContent.split('\n');
      for (final line in lines) {
        if (line.contains('version:') && !line.contains('checkUpdateUrl')) {
          _version = _extractYamlValue(line);
        } else if (line.contains('buildNumber:')) {
          _buildNumber = _extractYamlValue(line);
        }
      }
      
      _initialized = true;
      print('✅ 版本信息加载成功: $_version (Build $_buildNumber)');
    } catch (e) {
      print('⚠️ 版本信息加载失败: $e，使用默认值');
      _version = '1.0.0';
      _buildNumber = '1';
      _initialized = true;
    }
  }

  /// 获取应用版本号
  String get version => _version;

  /// 获取构建号
  String get buildNumber => _buildNumber;

  /// 获取完整版本字符串 (e.g., "1.0.0+1")
  String get fullVersion => '$_version+$_buildNumber';

  /// 获取显示用的版本字符串 (e.g., "v1.0.0 (Build 1)")
  String get displayVersion => 'v$_version (Build $_buildNumber)';

  /// 检查更新
  /// 
  /// 从配置的 URL 获取最新版本信息，并与当前版本比较
  /// 返回 VersionCheckResponse 对象，包含是否需要更新等信息
  Future<VersionCheckResponse> checkForUpdates({
    String? customUrl,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // 获取检查更新 URL
      final checkUrl = customUrl ?? await _getCheckUpdateUrl();
      
      if (checkUrl == null || checkUrl.isEmpty) {
        throw Exception('未配置版本检查 URL');
      }

      print('🔍 正在检查更新: $checkUrl');

      // 发送 HTTP 请求
      final response = await http
          .get(Uri.parse(checkUrl))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('版本检查失败: HTTP ${response.statusCode}');
      }

      // 解析响应
      final versionResponse = VersionCheckParser.parseResponse(
        response.body,
        fullVersion,
      );

      print('✅ 版本检查完成: $versionResponse');
      return versionResponse;
    } catch (e) {
      print('❌ 版本检查异常: $e');
      rethrow;
    }
  }

  /// 从配置文件获取检查更新 URL
  Future<String?> _getCheckUpdateUrl() async {
    try {
      final configContent = await rootBundle.loadString('lib/config.yaml');
      final lines = configContent.split('\n');
      
      for (final line in lines) {
        if (line.contains('checkUpdateUrl:')) {
          final url = _extractYamlValue(line);
          return url.isNotEmpty ? url : null;
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ 获取检查更新 URL 失败: $e');
      return null;
    }
  }

  /// 从 YAML 行中提取值（处理 URL 中的冒号）
  String _extractYamlValue(String line) {
    // 找到第一个冒号的位置
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return '';
    
    // 从冒号后面提取所有内容
    var value = line.substring(colonIndex + 1).trim();
    
    // 移除引号（单引号或双引号）
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }
    
    return value;
  }

  /// 获取关于软件的文本内容
  Future<String> getAboutText() async {
    try {
      final configContent = await rootBundle.loadString('lib/config.yaml');
      final lines = configContent.split('\n');
      
      bool inAboutSection = false;
      final aboutLines = <String>[];
      
      for (final line in lines) {
        // 检查是否进入 about 部分
        if (line.startsWith('about:')) {
          inAboutSection = true;
          // 检查是否在同一行有内容（about: 内容）
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1) {
            var value = line.substring(colonIndex + 1).trim();
            // 如果是 | 符号，表示多行字符串开始
            if (value == '|') {
              continue;
            } else if (value.isNotEmpty) {
              aboutLines.add(value);
            }
          }
          continue;
        }
        
        // 如果在 about 部分，继续收集行
        if (inAboutSection) {
          // 检查是否到达下一个顶级字段（不以空格开头）
          if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
            break;
          }
          
          // 移除前导空格（YAML 缩进）
          if (line.startsWith('  ')) {
            aboutLines.add(line.substring(2));
          } else if (line.isEmpty) {
            aboutLines.add('');
          }
        }
      }
      
      // 移除末尾的空行
      while (aboutLines.isNotEmpty && aboutLines.last.isEmpty) {
        aboutLines.removeLast();
      }
      
      return aboutLines.join('\n');
    } catch (e) {
      print('⚠️ 获取关于软件文本失败: $e');
      return '关于软件\n\n无法加载关于信息';
    }
  }
}
