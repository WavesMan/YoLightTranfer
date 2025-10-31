// 网络数据收集服务
// 负责采集用户设备局域网网络参数并上载到指定API接口
// 为AI模型训练提供数据养料

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';

/// 网络数据样本模型
class NetworkDataSample {
  final String sessionId;        // 会话ID
  final String deviceId;         // 设备唯一标识（哈希处理）
  final String appVersion;       // 应用版本
  final String platform;         // 平台 (android/ios/windows)
  final String osVersion;        // 操作系统版本
  final String deviceModel;      // 设备型号
  final String screenResolution; // 屏幕分辨率
  final int batteryLevel;        // 电池电量（0-100）
  final String networkType;      // 网络类型 (wifi/cellular)
  final String? ssid;            // WiFi名称（脱敏）
  final String? bssid;           // BSSID（脱敏）
  final String? ipAddress;       // IP地址（脱敏）
  final int signalStrength;      // 信号强度（dBm）
  final NetworkQuality networkQuality; // 网络质量数据
  final AIRecommendation? aiDecision; // AI决策结果
  final bool userAccepted;       // 用户是否接受推荐
  final DateTime timestamp;      // 采集时间
  final String? location;        // 地理位置（可选）
  final String dataVersion;      // 数据格式版本

  NetworkDataSample({
    required this.sessionId,
    required this.deviceId,
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.screenResolution,
    required this.batteryLevel,
    required this.networkType,
    this.ssid,
    this.bssid,
    this.ipAddress,
    required this.signalStrength,
    required this.networkQuality,
    this.aiDecision,
    required this.userAccepted,
    required this.timestamp,
    this.location,
    this.dataVersion = '1.0.0',
  });

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'device_id': deviceId,
      'app_version': appVersion,
      'platform': platform,
      'os_version': osVersion,
      'device_model': deviceModel,
      'screen_resolution': screenResolution,
      'battery_level': batteryLevel,
      'network_type': networkType,
      'ssid': ssid,
      'bssid': bssid,
      'ip_address': ipAddress,
      'signal_strength': signalStrength,
      'network_quality': {
        'bandwidth_mbps': networkQuality.bandwidthMbps,
        'packet_loss_rate': networkQuality.packetLossRate,
        'avg_delay_ms': networkQuality.avgDelayMs,
        'timestamp': networkQuality.timestamp.toIso8601String(),
      },
      'ai_decision': aiDecision?.toJson(),
      'user_accepted': userAccepted,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'data_version': dataVersion,
    };
  }

  /// 从JSON解析
  factory NetworkDataSample.fromJson(Map<String, dynamic> json) {
    return NetworkDataSample(
      sessionId: json['session_id'],
      deviceId: json['device_id'],
      appVersion: json['app_version'],
      platform: json['platform'],
      osVersion: json['os_version'],
      deviceModel: json['device_model'],
      screenResolution: json['screen_resolution'],
      batteryLevel: json['battery_level'],
      networkType: json['network_type'],
      ssid: json['ssid'],
      bssid: json['bssid'],
      ipAddress: json['ip_address'],
      signalStrength: json['signal_strength'],
      networkQuality: NetworkQuality(
        bandwidthMbps: json['network_quality']['bandwidth_mbps'],
        packetLossRate: json['network_quality']['packet_loss_rate'],
        avgDelayMs: json['network_quality']['avg_delay_ms'],
        timestamp: DateTime.parse(json['network_quality']['timestamp']),
      ),
      aiDecision: json['ai_decision'] != null 
          ? AIRecommendationParser.fromJson(json['ai_decision'])
          : null,
      userAccepted: json['user_accepted'],
      timestamp: DateTime.parse(json['timestamp']),
      location: json['location'],
      dataVersion: json['data_version'] ?? '1.0.0',
    );
  }
}

/// AI推荐结果的JSON扩展
extension AIRecommendationJson on AIRecommendation {
  Map<String, dynamic> toJson() {
    return {
      'should_recommend_hotspot': shouldRecommendHotspot,
      'reason': reason,
      'network_quality': {
        'bandwidth_mbps': networkQuality.bandwidthMbps,
        'packet_loss_rate': networkQuality.packetLossRate,
        'avg_delay_ms': networkQuality.avgDelayMs,
        'timestamp': networkQuality.timestamp.toIso8601String(),
      },
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// AI推荐结果的JSON解析辅助类
class AIRecommendationParser {
  static AIRecommendation fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      shouldRecommendHotspot: json['should_recommend_hotspot'],
      reason: json['reason'],
      networkQuality: NetworkQuality(
        bandwidthMbps: json['network_quality']['bandwidth_mbps'],
        packetLossRate: json['network_quality']['packet_loss_rate'],
        avgDelayMs: json['network_quality']['avg_delay_ms'],
        timestamp: DateTime.parse(json['network_quality']['timestamp']),
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// 数据收集配置
class DataCollectionConfig {
  final bool enabled;                    // 是否启用数据收集
  final String apiEndpoint;             // API端点
  final int batchSize;                  // 批量上传大小
  final Duration uploadInterval;        // 上传间隔
  final bool includeLocation;           // 是否包含地理位置
  final bool anonymizeData;             // 是否匿名化数据

  const DataCollectionConfig({
    this.enabled = false,
    this.apiEndpoint = 'https://api.example.com/network-data',
    this.batchSize = 50,
    this.uploadInterval = const Duration(minutes: 30),
    this.includeLocation = false,
    this.anonymizeData = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'api_endpoint': apiEndpoint,
      'batch_size': batchSize,
      'upload_interval': uploadInterval.inMinutes,
      'include_location': includeLocation,
      'anonymize_data': anonymizeData,
    };
  }

  factory DataCollectionConfig.fromJson(Map<String, dynamic> json) {
    return DataCollectionConfig(
      enabled: json['enabled'] ?? false,
      apiEndpoint: json['api_endpoint'] ?? 'https://api.example.com/network-data',
      batchSize: json['batch_size'] ?? 50,
      uploadInterval: Duration(minutes: json['upload_interval'] ?? 30),
      includeLocation: json['include_location'] ?? false,
      anonymizeData: json['anonymize_data'] ?? true,
    );
  }
}

/// 网络数据收集器
class NetworkDataCollector {
  final NetworkQualityAnalyzer _networkAnalyzer;
  final AINetworkAdvisor _aiAdvisor;
  final AppConfigService _configService;
  
  late DataCollectionConfig _config;
  final List<NetworkDataSample> _pendingSamples = [];
  final List<NetworkDataSample> _failedSamples = [];
  String? _currentSessionId;
  
  // 设备信息缓存
  String? _cachedDeviceId;
  String? _cachedPlatform;
  String? _cachedOsVersion;
  String? _cachedDeviceModel;

  NetworkDataCollector({
    required NetworkQualityAnalyzer networkAnalyzer,
    required AINetworkAdvisor aiAdvisor,
    required AppConfigService configService,
  }) : _networkAnalyzer = networkAnalyzer,
       _aiAdvisor = aiAdvisor,
       _configService = configService {
    _loadConfig();
    _initializeDeviceInfo();
  }

  /// 加载配置
  void _loadConfig() {
    final configJson = _configService.get<Map<String, dynamic>>('data_collection_config');
    if (configJson != null) {
      _config = DataCollectionConfig.fromJson(configJson);
    } else {
      _config = DataCollectionConfig();
    }
  }

  /// 初始化设备信息（使用真实设备信息）
  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final battery = Battery();
      final connectivity = Connectivity();
      
      // 获取平台特定的设备信息
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedPlatform = 'android';
        _cachedOsVersion = 'Android ${androidInfo.version.release}';
        _cachedDeviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _cachedDeviceId = _hashDeviceId(androidInfo.id ?? 'unknown');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedPlatform = 'ios';
        _cachedOsVersion = 'iOS ${iosInfo.systemVersion}';
        _cachedDeviceModel = '${iosInfo.name} ${iosInfo.model}';
        _cachedDeviceId = _hashDeviceId(iosInfo.identifierForVendor ?? 'unknown');
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cachedPlatform = 'windows';
        _cachedOsVersion = 'Windows ${windowsInfo.computerName}';
        _cachedDeviceModel = windowsInfo.computerName;
        _cachedDeviceId = _hashDeviceId(windowsInfo.deviceId);
      } else {
        _setDefaultDeviceInfo();
      }
      
      print('📱 设备信息初始化完成: $_cachedPlatform, $_cachedDeviceModel');
      
    } catch (e) {
      print('❌ 设备信息初始化失败: $e');
      _setDefaultDeviceInfo();
    }
  }

  /// 设置默认设备信息
  void _setDefaultDeviceInfo() {
    _cachedPlatform = Platform.operatingSystem;
    _cachedOsVersion = Platform.operatingSystemVersion;
    _cachedDeviceModel = 'Unknown';
    _cachedDeviceId = _hashDeviceId('default-${DateTime.now().millisecondsSinceEpoch}');
  }

  /// 哈希处理设备ID（隐私保护）
  String _hashDeviceId(String rawId) {
    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 脱敏网络信息
  String? _anonymizeNetworkInfo(String? info) {
    if (info == null || !_config.anonymizeData) return info;
    
    // 对SSID、BSSID、IP进行简单脱敏
    final bytes = utf8.encode(info);
    final digest = sha256.convert(bytes);
    return '${digest.toString().substring(0, 8)}';
  }

  /// 开始新的数据收集会话
  void startSession() {
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}_${_cachedDeviceId?.substring(0, 8)}';
    print('📊 开始数据收集会话: $_currentSessionId');
  }

  /// 收集网络数据样本
  Future<NetworkDataSample?> collectSample({
    bool includeAIDecision = true,
    bool userAccepted = false,
  }) async {
    if (!_config.enabled || _currentSessionId == null) {
      return null;
    }

    try {
      // 1. 收集网络质量数据
      final networkQuality = await _networkAnalyzer.measureNetworkQuality();
      
      // 2. 获取AI决策（可选）
      AIRecommendation? aiDecision;
      if (includeAIDecision) {
        aiDecision = await _aiAdvisor.shouldRecommendHotspotWith(networkQuality);
      }

      // 3. 收集真实设备信息
      final battery = Battery();
      final connectivity = Connectivity();
      
      final batteryLevel = await battery.batteryLevel;
      final connectivityResult = await connectivity.checkConnectivity();
      
      // 获取网络类型
      String networkType = 'unknown';
      switch (connectivityResult) {
        case ConnectivityResult.wifi:
          networkType = 'wifi';
          break;
        case ConnectivityResult.mobile:
          networkType = 'cellular';
          break;
        case ConnectivityResult.ethernet:
          networkType = 'ethernet';
          break;
        default:
          networkType = 'unknown';
      }

      // 4. 创建数据样本
      final sample = NetworkDataSample(
        sessionId: _currentSessionId!,
        deviceId: _cachedDeviceId ?? 'unknown',
        appVersion: '1.0.0', // 可以从配置中获取真实版本号
        platform: _cachedPlatform ?? 'unknown',
        osVersion: _cachedOsVersion ?? 'unknown',
        deviceModel: _cachedDeviceModel ?? 'unknown',
        screenResolution: 'unknown', // 可以集成flutter_screenutil获取真实分辨率
        batteryLevel: batteryLevel,
        networkType: networkType,
        ssid: _anonymizeNetworkInfo('real_ssid'), // 可以集成wifi_info_flutter获取真实SSID
        bssid: _anonymizeNetworkInfo('real_bssid'), // 可以集成wifi_info_flutter获取真实BSSID
        ipAddress: _anonymizeNetworkInfo('real_ip'), // 可以集成network_info_plus获取真实IP
        signalStrength: -60, // 可以集成wifi_info_flutter获取真实信号强度
        networkQuality: networkQuality,
        aiDecision: aiDecision,
        userAccepted: userAccepted,
        timestamp: DateTime.now(),
        location: _config.includeLocation ? 'unknown' : null,
      );

      // 5. 添加到待上传队列
      _pendingSamples.add(sample);
      
      // 6. 检查是否需要批量上传
      if (_pendingSamples.length >= _config.batchSize) {
        await _uploadPendingSamples();
      }

      print('📊 收集网络数据样本: ${sample.networkQuality}');
      return sample;

    } catch (e) {
      print('❌ 数据收集失败: $e');
      return null;
    }
  }

  /// 上传待处理样本
  Future<void> _uploadPendingSamples() async {
    if (_pendingSamples.isEmpty) return;

    try {
      final samplesToUpload = List<NetworkDataSample>.from(_pendingSamples);
      _pendingSamples.clear();

      // 转换为JSON格式
      final jsonData = {
        'samples': samplesToUpload.map((sample) => sample.toJson()).toList(),
        'upload_timestamp': DateTime.now().toIso8601String(),
        'batch_id': 'batch_${DateTime.now().millisecondsSinceEpoch}',
      };

      // 创建HTTP客户端
      final client = HttpClient();
      
      // 创建请求
      final request = await client.postUrl(Uri.parse(_config.apiEndpoint));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('User-Agent', 'YoLightTransfer/1.0.0');
      
      // 发送数据
      final jsonString = jsonEncode(jsonData);
      request.write(jsonString);
      
      // 获取响应
      final response = await request.close();
      
      if (response.statusCode == 200) {
        print('✅ 成功上传 ${samplesToUpload.length} 个数据样本');
      } else {
        print('❌ 数据上传失败，状态码: ${response.statusCode}');
        // 上传失败，添加到失败队列
        _failedSamples.addAll(samplesToUpload);
      }
      
      client.close();
      
    } catch (e) {
      print('❌ 数据上传异常: $e');
      // 上传异常，添加到失败队列
      _failedSamples.addAll(_pendingSamples);
      _pendingSamples.clear();
    }
  }

  /// 重试失败的上传
  Future<void> retryFailedUploads() async {
    if (_failedSamples.isEmpty) return;
    
    final failedSamples = List<NetworkDataSample>.from(_failedSamples);
    _failedSamples.clear();
    _pendingSamples.addAll(failedSamples);
    
    await _uploadPendingSamples();
  }

  /// 手动触发上传
  Future<void> triggerUpload() async {
    await _uploadPendingSamples();
  }

  /// 更新配置
  void updateConfig(DataCollectionConfig newConfig) {
    _config = newConfig;
    // 保存到配置服务
    _configService.set('data_collection_config', newConfig.toJson());
  }

  /// 获取当前配置
  DataCollectionConfig get config => _config;

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'enabled': _config.enabled,
      'pending_samples': _pendingSamples.length,
      'failed_samples': _failedSamples.length,
      'current_session': _currentSessionId,
      'total_collected': _pendingSamples.length + _failedSamples.length,
    };
  }

  /// 清空所有数据
  void clearAllData() {
    _pendingSamples.clear();
    _failedSamples.clear();
    _currentSessionId = null;
  }

  /// 结束当前会话
  void endSession() {
    // 上传剩余数据
    _uploadPendingSamples();
    _currentSessionId = null;
    print('📊 结束数据收集会话');
  }
}
