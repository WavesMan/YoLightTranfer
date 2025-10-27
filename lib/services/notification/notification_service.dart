import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知服务
/// 负责在应用后台时显示文件传输通知
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelId = 'file_transfer_channel';
  static const String _channelName = '文件传输通知';
  static const String _channelDescription = '文件传输请求和状态通知';

  late FlutterLocalNotificationsPlugin _notifications;

  /// 初始化通知服务
  Future<void> initialize() async {
    _notifications = FlutterLocalNotificationsPlugin();

    // 初始化设置
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // 创建通知渠道（仅Android）
    await _createNotificationChannel();
  }

  /// 创建通知渠道
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  /// 显示文件传输请求通知
  Future<void> showFileTransferNotification({
    required String senderDeviceName,
    required String fileName,
    required int fileSize,
    required String requestId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: '文件传输请求',
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final fileSizeFormatted = _formatBytes(fileSize);

    await _notifications.show(
      requestId.hashCode,
      '文件传输请求',
      '来自 $senderDeviceName 的文件: $fileName ($fileSizeFormatted)',
      details,
      payload: requestId,
    );
  }

  /// 处理通知点击
  void _onNotificationResponse(NotificationResponse response) {
    // 当用户点击通知时，可以唤醒应用并处理传输请求
    // 这里可以添加逻辑来唤醒应用并显示确认弹窗
    print('通知被点击: ${response.payload}');
  }

  /// 格式化文件大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
