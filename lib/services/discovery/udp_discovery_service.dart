// UDP 发现与心跳广播/监听服务
// 运行平台：移动端/桌面端（依赖 dart:io），Web 端禁用。

import 'dart:async';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:flutter/foundation.dart';

// 关于 dart:io 导入说明：这些文件在 Web 构建中不会被引入，
// 但仍保留此导入；请确保不要在 Web 端使用本服务。
import 'dart:io';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/device/device_id_util.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/services/device/device_name_service.dart';
import 'package:yolighttransfer/services/network/network_interface_manager.dart';

class UdpDiscoveryService {
  UdpDiscoveryService(this._deviceManager);

  static const int discoveryPort = 7431;
  static const Duration heartbeatInterval = Duration(seconds: 2);

  final DeviceManager _deviceManager;

  RawDatagramSocket? _broadcaster;
  RawDatagramSocket? _listener;
  Timer? _broadcastTimer;
  bool _running = false;
  String? _selfDeviceId;

  bool get isRunning => _running;
  bool get isSupported => !kIsWeb; // Web 端不支持 dart:io 套接字

  Future<void> start({
    required String deviceName,
    required int tcpPort,
    int? httpPort,
    String transportMethod = 'TCP',
  }) async {
    if (!isSupported) return;
    if (_running) return;

    _selfDeviceId = await DeviceIdUtil.getOrCreateId();

    // 启动广播套接字（用于发送心跳）
    _broadcaster = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcaster!.broadcastEnabled = true;

    // 启动监听套接字（用于接收心跳）
    _listener = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: !Platform.isWindows, // Windows不支持reusePort
    );
    _listener!.listen(_onSocketEvent, onError: (_) {}, onDone: _onListenerDone);

    // 周期性发送心跳
    _broadcastTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat(
        deviceName: deviceName,
        tcpPort: tcpPort,
        httpPort: httpPort,
        transportMethod: transportMethod,
      );
    });

    // 立即发送一次心跳，加速首轮发现
    _sendHeartbeat(
      deviceName: deviceName,
      tcpPort: tcpPort,
      httpPort: httpPort,
      transportMethod: transportMethod,
    );

    _running = true;
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcaster?.close();
    _broadcaster = null;
    _listener?.close();
    _listener = null;
    _running = false;
  }

  void _sendHeartbeat({
    required String deviceName,
    required int tcpPort,
    int? httpPort,
    String transportMethod = 'TCP',
  }) {
    final socket = _broadcaster;
    final id = _selfDeviceId;
    if (socket == null || id == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = jsonEncode({
      'Device_ID': id,
      'Device_OS': _platformOs(),
      'Device_Name': deviceName,
      'Transport_Method': transportMethod,
      'TCP_Port': tcpPort,
      if (httpPort != null) 'HTTP_Port': httpPort,
      'Timestamp': now,
    });

    // IPv4 广播地址
    final broadcastAddr = InternetAddress('255.255.255.255');
    socket.send(utf8.encode(data), broadcastAddr, discoveryPort);
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _listener;
    if (socket == null) return;
    final dg = socket.receive();
    if (dg == null || dg.data.isEmpty) return;
    try {
      final msg = utf8.decode(dg.data);
      final map = jsonDecode(msg);
      final dev = DiscoveredDevice.fromBroadcast(map, dg.address.address);

      // 忽略自身发送的心跳包
      if (dev.id == _selfDeviceId) return;

      // 通知设备管理器更新/插入设备
      _deviceManager.upsertFromHeartbeat(dev);
    } catch (_) {
      // 忽略格式错误的报文
    }
  }

  void _onListenerDone() {
    _listener = null;
  }

  String _platformOs() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem; // 可能值：windows、android、ios、linux、macos
    } catch (_) {
      return 'unknown';
    }
  }
}
