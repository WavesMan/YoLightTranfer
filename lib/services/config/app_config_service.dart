import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 应用配置服务：管理应用的各种配置选项
class AppConfigService {
  static const String _configFileName = 'app_config.json';
  static const Duration _saveDebounceDelay = Duration(milliseconds: 500);

  late String _configFilePath;
  final Map<String, dynamic> _config = {};
  bool _initialized = false;
  bool _needsSave = false;
  DateTime? _lastSaveTime;

  /// 配置键常量
  static const String enableTransferLogPage = 'enableTransferLogPage';
  static const String enableDebugMode = 'enableDebugMode';
  static const String enableAutoSave = 'enableAutoSave';
  static const String defaultSavePath = 'defaultSavePath';
  static const String maxLogEntries = 'maxLogEntries';
  static const String enableFileVerification = 'enableFileVerification';
  static const String enableTransferRecovery = 'enableTransferRecovery';
  static const String connectionTimeout = 'connectionTimeout';
  // static const String transferChunkSize = 'transferChunkSize';

  /// 默认配置值
  static const Map<String, dynamic> _defaultConfig = {
    enableTransferLogPage: false,      // 启用传输日志页面
    enableDebugMode: false,           // 调试模式
    enableAutoSave: false,             // 自动保存
    defaultSavePath: '',              // 默认保存路径
    maxLogEntries: 100,              // 最大日志条目数
    enableFileVerification: true,     // 启用文件校验
    enableTransferRecovery: true,     // 启用传输恢复
    connectionTimeout: 60000,         // 连接超时时间（毫秒）
    // transferChunkSize: 65536,         // 传输分片大小（字节）
  };

  /// 初始化配置服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _configFilePath = '${directory.path}/$_configFileName';
      
      // 加载现有配置
      await _loadConfig();
      
      _initialized = true;
      print('应用配置服务初始化完成，配置文件: $_configFilePath');
    } catch (e) {
      print('应用配置服务初始化失败: $e');
      // 使用默认配置
      _config.addAll(_defaultConfig);
      _initialized = true;
    }
  }

  /// 获取配置值
  T get<T>(String key, [T? defaultValue]) {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    final value = _config[key] ?? defaultValue ?? _defaultConfig[key];
    
    // 类型转换
    if (value is T) {
      return value;
    }
    
    // 特殊类型处理
    if (T == int && value is String) {
      return int.tryParse(value) as T? ?? defaultValue as T;
    }
    if (T == bool && value is String) {
      return (value.toLowerCase() == 'true') as T;
    }
    if (T == double && value is String) {
      return double.tryParse(value) as T? ?? defaultValue as T;
    }
    
    return value as T;
  }

  /// 设置配置值
  Future<void> set<T>(String key, T value) async {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    _config[key] = value;
    _needsSave = true;
    
    // 延迟保存，避免频繁IO操作
    _scheduleSave();
  }

  /// 检查配置是否存在
  bool has(String key) {
    return _config.containsKey(key);
  }

  /// 删除配置项
  Future<void> remove(String key) async {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    _config.remove(key);
    _needsSave = true;
    _scheduleSave();
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    _config.clear();
    _config.addAll(_defaultConfig);
    _needsSave = true;
    await _saveConfig();
  }

  /// 获取所有配置
  Map<String, dynamic> getAll() {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    return Map<String, dynamic>.from(_config);
  }

  /// 导出配置到文件
  Future<String> exportConfig(String filePath) async {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    try {
      final file = File(filePath);
      await file.writeAsString(jsonEncode(_config));
      return filePath;
    } catch (e) {
      throw Exception('导出配置失败: $e');
    }
  }

  /// 从文件导入配置
  Future<void> importConfig(String filePath) async {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('配置文件不存在: $filePath');
      }

      final content = await file.readAsString();
      final importedConfig = jsonDecode(content) as Map<String, dynamic>;
      
      _config.clear();
      _config.addAll(importedConfig);
      _needsSave = true;
      await _saveConfig();
    } catch (e) {
      throw Exception('导入配置失败: $e');
    }
  }

  /// 获取配置统计信息
  Map<String, dynamic> getStatistics() {
    if (!_initialized) {
      throw StateError('配置服务未初始化，请先调用 initialize()');
    }

    return {
      'totalConfigs': _config.length,
      'defaultConfigs': _defaultConfig.length,
      'customConfigs': _config.length - _defaultConfig.length,
      'configFilePath': _configFilePath,
      'lastSaveTime': _lastSaveTime?.toIso8601String(),
    };
  }

  // 私有方法

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final file = File(_configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final loadedConfig = jsonDecode(content) as Map<String, dynamic>;
        
        _config.clear();
        _config.addAll(loadedConfig);
        print('加载了 ${_config.length} 个配置项');
      } else {
        // 使用默认配置
        _config.addAll(_defaultConfig);
        await _saveConfig();
        print('创建默认配置文件');
      }
    } catch (e) {
      print('加载配置失败: $e');
      // 使用默认配置
      _config.addAll(_defaultConfig);
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_needsSave) return;

    try {
      final file = File(_configFilePath);
      await file.writeAsString(jsonEncode(_config));
      _needsSave = false;
      _lastSaveTime = DateTime.now();
      print('配置已保存到: $_configFilePath');
    } catch (e) {
      print('保存配置失败: $e');
    }
  }

  /// 延迟保存
  void _scheduleSave() {
    Future.delayed(_saveDebounceDelay, () async {
      if (_needsSave) {
        await _saveConfig();
      }
    });
  }
}

/// 配置键扩展方法
extension AppConfigKeys on String {
  /// 获取配置描述
  String get configDescription {
    switch (this) {
      case AppConfigService.enableTransferLogPage:
        return '启用传输日志页面';
      case AppConfigService.enableDebugMode:
        return '启用调试模式';
      case AppConfigService.enableAutoSave:
        return '启用自动保存';
      case AppConfigService.defaultSavePath:
        return '默认保存路径';
      case AppConfigService.maxLogEntries:
        return '最大日志条目数';
      case AppConfigService.enableFileVerification:
        return '启用文件校验';
      case AppConfigService.enableTransferRecovery:
        return '启用传输恢复';
      case AppConfigService.connectionTimeout:
        return '连接超时时间';
      // case AppConfigService.transferChunkSize:
      //   return '传输分片大小';
      default:
        return this;
    }
  }

  /// 获取配置类型
  String get configType {
    switch (this) {
      case AppConfigService.enableTransferLogPage:
      case AppConfigService.enableDebugMode:
      case AppConfigService.enableAutoSave:
      case AppConfigService.enableFileVerification:
      case AppConfigService.enableTransferRecovery:
        return '布尔值';
      case AppConfigService.maxLogEntries:
      case AppConfigService.connectionTimeout:
      // case AppConfigService.transferChunkSize:
        return '整数';
      case AppConfigService.defaultSavePath:
        return '字符串';
      default:
        return '未知';
    }
  }
}
