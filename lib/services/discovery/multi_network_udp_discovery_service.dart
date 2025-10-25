// 多网络UDP发现与心跳广播/监听服务
// 支持在多个网络接口上同时监听和广播，适配移动网络环境

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/services/device/device_id_util.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/services/device/device_name_service.dart';
import 'package:yolighttransfer/services/network/network_interface_manager.dart';

/// 多网络UDP发现服务
/// 支持在多个网络接口上同时监听和广播，适配移动网络环境
class MultiNetworkUdpDiscoveryService {
  MultiNetworkUdpDiscoveryService(this._deviceManager);

  static const int discoveryPort = 7431;
  static const Duration heartbeatInterval = Duration(seconds: 2);

  final DeviceManager _deviceManager;
  final NetworkInterfaceManager _networkManager = NetworkInterfaceManager();

  // 多网络监听器
  final List<RawDatagramSocket> _listeners = [];
  // 多网络广播器
  final List<RawDatagramSocket> _broadcasters = [];
  
  Timer? _broadcastTimer;
  bool _running = false;
  String? _selfDeviceId;

  bool get isRunning => _running;
  bool get isSupported => !kIsWeb; // Web 端不支持 dart:io 套接字

  /// 启动多网络发现服务
  Future<void> start({
    required String deviceName,
    required int httpPort,
    String transportMethod = 'HTTP',
  }) async {
    if (!isSupported) return;
    if (_running) return;

    // 初始化网络接口管理器
    await _networkManager.initialize();
    _selfDeviceId = await DeviceIdUtil.getOrCreateId();

    // 在所有可用网络接口上启动监听和广播
    await _startMultiNetworkListeners();
    await _startMultiNetworkBroadcasters();

    // 周期性发送心跳
    _broadcastTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendMultiNetworkHeartbeat(
        deviceName: deviceName,
        httpPort: httpPort,
        transportMethod: transportMethod,
      );
    });

    // 立即发送一次心跳，加速首轮发现
    _sendMultiNetworkHeartbeat(
      deviceName: deviceName,
      httpPort: httpPort,
      transportMethod: transportMethod,
    );

    _running = true;
    print('多网络UDP发现服务已启动，在 ${_listeners.length} 个网络接口上监听');
  }

  /// 在所有可用网络接口上启动监听器
  Future<void> _startMultiNetworkListeners() async {
    final availableInterfaces = _networkManager.availableInterfaces;
    
    for (final iface in availableInterfaces) {
      try {
        // 在每个网络接口上绑定监听器
        final listener = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
          reuseAddress: true,
          reusePort: !Platform.isWindows,
        );
        
        listener.listen(
          (event) => _onSocketEvent(event, iface),
          onError: (error) => _onListenerError(error, iface),
          onDone: () => _onListenerDone(iface),
        );
        
        _listeners.add(listener);
        print('在网络接口 ${iface.name} (${iface.type}) 上启动UDP监听');
      } catch (e) {
        print('在网络接口 ${iface.name} 上启动监听失败: $e');
      }
    }
  }

  /// 在所有可用网络接口上启动广播器
  Future<void> _startMultiNetworkBroadcasters() async {
    final availableInterfaces = _networkManager.availableInterfaces;
    
    for (final iface in availableInterfaces) {
      try {
        // 在每个网络接口上绑定广播器
        final broadcaster = await RawDatagramSocket.bind(
          iface.preferredIpv4Address ?? InternetAddress.anyIPv4,
          0, // 系统分配端口
        );
        
        broadcaster.broadcastEnabled = true;
        _broadcasters.add(broadcaster);
        print('在网络接口 ${iface.name} (${iface.type}) 上启动UDP广播');
      } catch (e) {
        print('在网络接口 ${iface.name} 上启动广播失败: $e');
      }
    }
  }

  /// 停止多网络发现服务
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    // 关闭所有监听器
    for (final listener in _listeners) {
      listener.close();
    }
    _listeners.clear();

    // 关闭所有广播器
    for (final broadcaster in _broadcasters) {
      broadcaster.close();
    }
    _broadcasters.clear();

    _networkManager.stopMonitoring();
    _running = false;
    print('多网络UDP发现服务已停止');
  }

  /// 在多网络上发送心跳
  void _sendMultiNetworkHeartbeat({
    required String deviceName,
    required int httpPort,
    String transportMethod = 'HTTP',
  }) {
    if (_broadcasters.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = jsonEncode({
      'Device_ID': _selfDeviceId,
      'Device_OS': _platformOs(),
      'Device_Name': deviceName,
      'Transport_Method': transportMethod,
      'HTTP_Port': httpPort,
      'Timestamp': now,
      'Network_Interfaces': _getNetworkInterfaceInfo(),
    });

    final encodedData = utf8.encode(data);
    final broadcastAddresses = _networkManager.getBroadcastAddresses();

    // // 记录广播信息
    // print('=== UDP广播信息 ===');
    // print('广播器数量: ${_broadcasters.length}');
    // print('广播地址数量: ${broadcastAddresses.length}');
    // print('设备名称: $deviceName');
    // print('TCP端口: $tcpPort');
    // print('设备ID: $_selfDeviceId');

    // 在每个广播器上发送心跳
    int totalSent = 0;
    for (final broadcaster in _broadcasters) {
      for (final broadcastAddr in broadcastAddresses) {
        try {
          final result = broadcaster.send(encodedData, broadcastAddr, discoveryPort);
          if (result > 0) {
            totalSent++;
            // print('✓ 成功发送心跳到 ${broadcastAddr.address}:$discoveryPort');
          } else {
            // print('✗ 发送心跳失败到 ${broadcastAddr.address}:$discoveryPort');
          }
        } catch (e) {
          // print('✗ 发送心跳异常到 ${broadcastAddr.address}:$discoveryPort: $e');
        }
      }
    }
    
    // print('总计发送: $totalSent 个心跳包');
    // print('==================');
  }

  /// 获取网络接口信息用于心跳包
  Map<String, dynamic> _getNetworkInterfaceInfo() {
    final interfaces = _networkManager.availableInterfaces;
    final interfaceInfo = <String, dynamic>{};
    
    for (final iface in interfaces) {
      final ip = iface.preferredIpv4Address?.address;
      if (ip != null) {
        interfaceInfo[iface.name] = {
          'type': iface.type.toString(),
          'ip': ip,
        };
      }
    }
    
    return interfaceInfo;
  }

  /// 处理套接字事件
  void _onSocketEvent(RawSocketEvent event, NetworkInterfaceInfo iface) {
    if (event != RawSocketEvent.read) return;
    
    for (final listener in _listeners) {
      final dg = listener.receive();
      if (dg == null || dg.data.isEmpty) continue;
      
      try {
        final msg = utf8.decode(dg.data);
        final map = jsonDecode(msg);
        final dev = DiscoveredDevice.fromBroadcast(map, dg.address.address);

        // 记录接收到的UDP包信息
        // print('=== UDP接收信息 ===');
        // print('接收到心跳包来自: ${dg.address.address}');
        // print('设备ID: ${dev.id}');
        // print('设备名称: ${dev.name}');
        // print('设备系统: ${dev.os}');
        // print('TCP端口: ${dev.tcpPort}');
        // print('网络接口: ${iface.name}');
        // print('==================');

        // 忽略自身发送的心跳包
        if (dev.id == _selfDeviceId) {
          // print('忽略自身心跳包');
          continue;
        }

        // 添加网络接口信息到设备
        final enhancedDev = dev.copyWith(
          networkInterface: iface.name,
          networkType: iface.type.toString(),
        );

        // 通知设备管理器更新/插入设备
        _deviceManager.upsertFromHeartbeat(enhancedDev);
        // print('✓ 成功处理设备: ${dev.name}');
      } catch (e) {
        // print('✗ 处理UDP包失败: $e');
        // 忽略格式错误的报文
      }
    }
  }

  /// 处理监听器错误
  void _onListenerError(Object error, NetworkInterfaceInfo iface) {
    print('网络接口 ${iface.name} 监听错误: $error');
  }

  /// 处理监听器完成
  void _onListenerDone(NetworkInterfaceInfo iface) {
    print('网络接口 ${iface.name} 监听器已关闭');
    // 监听器关闭时自动从列表中移除
  }

  /// 获取平台操作系统信息
  String _platformOs() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem; // 可能值：windows、android、ios、linux、macos
    } catch (_) {
      return 'unknown';
    }
  }

  /// 获取当前网络状态信息
  Map<String, dynamic> getNetworkStatus() {
    return {
      'running': _running,
      'listeners': _listeners.length,
      'broadcasters': _broadcasters.length,
      'availableInterfaces': _networkManager.availableInterfaces.length,
      'wifiInterfaces': _networkManager.wifiInterfaces.length,
      'ethernetInterfaces': _networkManager.ethernetInterfaces.length,
      'mobileInterfaces': _networkManager.mobileInterfaces.length,
    };
  }

  /// 释放资源
  void dispose() {
    stop();
    _networkManager.dispose();
  }
}
