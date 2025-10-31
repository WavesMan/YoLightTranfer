// 网络数据收集器测试
import 'package:flutter_test/flutter_test.dart';
import 'package:yolighttransfer/services/network_data_collector.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';

// Mock 配置服务
class MockConfigService extends AppConfigService {
  final Map<String, dynamic> _storage = {};

  @override
  T get<T>(String key, [T? defaultValue]) {
    return _storage[key] as T? ?? defaultValue!;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    _storage[key] = value;
  }

  @override
  bool contains(String key) {
    return _storage.containsKey(key);
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}

void main() {
  group('NetworkDataCollector Tests', () {
    late MockConfigService mockConfigService;
    late NetworkDataCollector dataCollector;
    late NetworkQualityAnalyzer mockNetworkAnalyzer;
    late AINetworkAdvisor mockAiAdvisor;

    setUp(() {
      mockConfigService = MockConfigService();
      
      // 创建模拟对象
      mockNetworkAnalyzer = NetworkQualityAnalyzer('127.0.0.1', 8080);
      mockAiAdvisor = AINetworkAdvisor(
        networkAnalyzer: mockNetworkAnalyzer,
        configService: mockConfigService,
      );

      dataCollector = NetworkDataCollector(
        networkAnalyzer: mockNetworkAnalyzer,
        aiAdvisor: mockAiAdvisor,
        configService: mockConfigService,
      );
    });

    test('DataCollectionConfig 序列化和反序列化', () {
      final config = DataCollectionConfig(
        enabled: true,
        apiEndpoint: 'https://api.test.com/data',
        batchSize: 25,
        uploadInterval: Duration(minutes: 15),
        includeLocation: true,
        anonymizeData: false,
      );

      final json = config.toJson();
      final restoredConfig = DataCollectionConfig.fromJson(json);

      expect(restoredConfig.enabled, true);
      expect(restoredConfig.apiEndpoint, 'https://api.test.com/data');
      expect(restoredConfig.batchSize, 25);
      expect(restoredConfig.uploadInterval.inMinutes, 15);
      expect(restoredConfig.includeLocation, true);
      expect(restoredConfig.anonymizeData, false);
    });

    test('NetworkDataSample 序列化和反序列化', () {
      final networkQuality = NetworkQuality(
        bandwidthMbps: 50.5,
        packetLossRate: 2.3,
        avgDelayMs: 45.0,
        timestamp: DateTime.now(),
      );

      final sample = NetworkDataSample(
        sessionId: 'test_session_123',
        deviceId: 'hashed_device_id',
        appVersion: '1.0.0',
        platform: 'android',
        osVersion: 'Android 12',
        deviceModel: 'Test Device',
        screenResolution: '1080x1920',
        batteryLevel: 80,
        networkType: 'wifi',
        ssid: 'test_ssid',
        bssid: 'test_bssid',
        ipAddress: '192.168.1.100',
        signalStrength: -60,
        networkQuality: networkQuality,
        aiDecision: null,
        userAccepted: false,
        timestamp: DateTime.now(),
        location: 'Test Location',
        dataVersion: '1.0.0',
      );

      final json = sample.toJson();
      final restoredSample = NetworkDataSample.fromJson(json);

      expect(restoredSample.sessionId, 'test_session_123');
      expect(restoredSample.deviceId, 'hashed_device_id');
      expect(restoredSample.appVersion, '1.0.0');
      expect(restoredSample.platform, 'android');
      expect(restoredSample.networkQuality.bandwidthMbps, 50.5);
      expect(restoredSample.networkQuality.packetLossRate, 2.3);
      expect(restoredSample.networkQuality.avgDelayMs, 45.0);
      expect(restoredSample.userAccepted, false);
    });

    test('数据收集器初始配置', () {
      expect(dataCollector.config.enabled, false);
      expect(dataCollector.config.apiEndpoint, 'https://api.example.com/network-data');
      expect(dataCollector.config.batchSize, 50);
      expect(dataCollector.config.uploadInterval.inMinutes, 30);
      expect(dataCollector.config.includeLocation, false);
      expect(dataCollector.config.anonymizeData, true);
    });

    test('更新数据收集配置', () {
      final newConfig = DataCollectionConfig(
        enabled: true,
        apiEndpoint: 'https://new-api.test.com/data',
        batchSize: 20,
        uploadInterval: Duration(minutes: 10),
        includeLocation: true,
        anonymizeData: false,
      );

      dataCollector.updateConfig(newConfig);

      expect(dataCollector.config.enabled, true);
      expect(dataCollector.config.apiEndpoint, 'https://new-api.test.com/data');
      expect(dataCollector.config.batchSize, 20);
      expect(dataCollector.config.uploadInterval.inMinutes, 10);
      expect(dataCollector.config.includeLocation, true);
      expect(dataCollector.config.anonymizeData, false);
    });

    test('获取统计信息', () {
      final stats = dataCollector.getStats();

      expect(stats['enabled'], false);
      expect(stats['pending_samples'], 0);
      expect(stats['failed_samples'], 0);
      expect(stats['current_session'], isNull);
      expect(stats['total_collected'], 0);
    });

    test('开始和结束会话', () {
      dataCollector.startSession();
      
      final stats = dataCollector.getStats();
      expect(stats['current_session'], isNotNull);
      
      dataCollector.endSession();
      
      final finalStats = dataCollector.getStats();
      expect(finalStats['current_session'], isNull);
    });

    test('清空所有数据', () {
      dataCollector.clearAllData();
      
      final stats = dataCollector.getStats();
      expect(stats['pending_samples'], 0);
      expect(stats['failed_samples'], 0);
      expect(stats['current_session'], isNull);
    });

    // 注：私有方法的测试需要更复杂的模拟设置
    // 在实际项目中建议使用mocktail等库进行完整的单元测试
  });

  // 注：DataUploadService的测试需要更复杂的模拟设置
  // 在实际项目中建议使用mocktail等库进行完整的单元测试
}
