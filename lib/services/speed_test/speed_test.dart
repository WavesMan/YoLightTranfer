/// 快速HTTP测速系统
/// 
/// 完整的测速系统包含：
/// - SpeedTestService: 测速服务核心
/// - SpeedTestManager: 测速管理器
/// - SpeedTestClient: 测速客户端
/// - 集成ONNX模型推理
/// - 渐进式测速策略
/// 
/// 主要特性：
/// 1. 复用现有HTTP传输基础设施
/// 2. 渐进式测速（小包→中包→大包）
/// 3. AI驱动的网络质量评估
/// 4. 自动测速包清理
/// 5. 历史记录和统计分析

export 'speed_test_service.dart';
export 'speed_test_manager.dart';
export 'speed_test_client.dart';

/// 测速系统使用示例：
/// 
/// ```dart
/// // 1. 创建测速管理器
/// final speedTestManager = SpeedTestManager(
///   logManager: TransferLogManager(),
///   taskManager: TransferTaskManager(),
/// );
/// 
/// // 2. 启动测速
/// final result = await speedTestManager.startSpeedTest(
///   targetDevice: discoveredDevice,
/// );
/// 
/// // 3. 监听测速进度
/// speedTestManager.onStateChanged = (state) {
///   print('测速状态: $state');
/// };
/// 
/// speedTestManager.onTestCompleted = (testId, result) {
///   print('测速完成: ${result.bandwidthMbps} Mbps');
///   print('质量评分: ${result.qualityScore}');
///   print('热点推荐: ${result.shouldRecommendHotspot}');
/// };
/// 
/// // 4. 使用测速客户端
/// final speedTestClient = SpeedTestClient(
///   logManager: TransferLogManager(),
/// );
/// 
/// await speedTestClient.connectToDevice(discoveredDevice);
/// final metrics = await speedTestClient.getConnectionMetrics();
/// print('连接质量: $metrics');
