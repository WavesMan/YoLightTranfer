// 多网络UDP发现与心跳广播/监听服务
// 支持在多个网络接口上同时监听和广播，适配移动网络环境

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  String? _currentDeviceName;
  int? _currentHttpPort;
  String? _currentTransportMethod;
  
  // 网络变化检测
  int _lastInterfaceCount = 0;
  
  // wlan接口监听
  Map<String, _WlanInterfaceState> _lastWlanInterfaces = {};
  
  // 网络连接状态监听
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _lastWifiSsid;
  Timer? _networkChangeTimer;

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

    // 保存启动参数用于重启
    _currentDeviceName = deviceName;
    _currentHttpPort = httpPort;
    _currentTransportMethod = transportMethod;

    // 初始化网络接口管理器
    await _networkManager.initialize();
    _selfDeviceId = await DeviceIdUtil.getOrCreateId();

    // 在所有可用网络接口上启动监听和广播
    await _startMultiNetworkListeners();
    await _startMultiNetworkBroadcasters();

    // 记录初始网络接口数量
    _lastInterfaceCount = _networkManager.availableInterfaces.length;

    // 启动网络连接状态监听
    _startConnectivityMonitoring();

    // 获取当前WiFi SSID
    await _updateCurrentWifiSsid();

    // 周期性发送心跳
    _broadcastTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendMultiNetworkHeartbeat(
        deviceName: deviceName,
        httpPort: httpPort,
        transportMethod: transportMethod,
      );
      
      // 检查网络接口变化
      _checkNetworkInterfaceChanges();
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
    print('=== 开始在所有网络接口上启动UDP监听 ===');
    print('可用网络接口数量: ${availableInterfaces.length}');
    
    for (final iface in availableInterfaces) {
      try {
        print('处理网络接口: ${iface.name}, 类型: ${iface.type}');
        print('接口状态: isUp=${iface.isUp}, supportsBroadcast=${iface.supportsBroadcast}');
        
        // 打印所有IP地址
        for (final addr in iface.addresses) {
          print('  IP地址: ${addr.address} (${addr.type})');
        }
        
        // 打印首选IPv4地址
        final preferredIp = iface.preferredIpv4Address;
        if (preferredIp != null) {
          print('  首选IPv4地址: ${preferredIp.address}');
        } else {
          print('  无IPv4地址');
        }
        
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
        print('✅ 在网络接口 ${iface.name} (${iface.type}) 上启动UDP监听成功');
      } catch (e) {
        print('❌ 在网络接口 ${iface.name} 上启动监听失败: $e');
      }
    }
    print('=== UDP监听启动完成 ===');
  }

  /// 在所有可用网络接口上启动广播器
  Future<void> _startMultiNetworkBroadcasters() async {
    final availableInterfaces = _networkManager.availableInterfaces;
    print('=== 开始在所有网络接口上启动UDP广播 ===');
    
    for (final iface in availableInterfaces) {
      try {
        print('处理网络接口: ${iface.name}, 类型: ${iface.type}');
        
        // 获取绑定地址
        final bindAddress = iface.preferredIpv4Address ?? InternetAddress.anyIPv4;
        print('  绑定地址: ${bindAddress.address}');
        
        // 在每个网络接口上绑定广播器
        final broadcaster = await RawDatagramSocket.bind(
          bindAddress,
          0, // 系统分配端口
        );
        
        broadcaster.broadcastEnabled = true;
        _broadcasters.add(broadcaster);
        print('✅ 在网络接口 ${iface.name} (${iface.type}) 上启动UDP广播成功');
      } catch (e) {
        print('❌ 在网络接口 ${iface.name} 上启动广播失败: $e');
      }
    }
    print('=== UDP广播启动完成 ===');
  }

  /// 停止多网络发现服务
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _networkChangeTimer?.cancel();
    _networkChangeTimer = null;

    // 停止网络连接状态监听
    _stopConnectivityMonitoring();

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
    _lastInterfaceCount = 0;
    _lastWifiSsid = null;
    print('多网络UDP发现服务已停止');
  }

  /// 重启多网络发现服务
  Future<void> restart() async {
    if (!_running) return;
    
    print('检测到网络环境变化，正在重启UDP发现服务...');
    
    // 停止当前服务
    await stop();
    
    // 等待网络稳定
    await Future.delayed(Duration(seconds: 2));
    
    // 重新启动服务
    if (_currentDeviceName != null && _currentHttpPort != null) {
      await start(
        deviceName: _currentDeviceName!,
        httpPort: _currentHttpPort!,
        transportMethod: _currentTransportMethod ?? 'HTTP',
      );
    }
  }

  /// 检查网络接口变化
  void _checkNetworkInterfaceChanges() {
    // 检查wlan接口变化
    _checkWlanInterfaceChanges();
  }

  /// 检查wlan接口变化
  void _checkWlanInterfaceChanges() {
    try {
      final currentWlanInterfaces = _getWlanInterfaces();
      
      // 比较当前和上一次的wlan接口状态
      if (_hasWlanInterfaceChanged(currentWlanInterfaces)) {
        print('=== 检测到wlan接口变化 ===');
        print('上一次wlan接口: ${_lastWlanInterfaces.keys.join(", ")}');
        print('当前wlan接口: ${currentWlanInterfaces.keys.join(", ")}');
        
        // 打印详细的接口变化信息
        for (final name in currentWlanInterfaces.keys) {
          final prev = _lastWlanInterfaces[name];
          final curr = currentWlanInterfaces[name];
          
          if (prev == null) {
            print('  ✅ 新增接口: $name (IP: ${curr?.ip ?? "无"})');
          } else if (prev.ip != curr?.ip) {
            print('  🔄 接口 $name IP变化: ${prev.ip} -> ${curr?.ip}');
          } else if (prev.isUp != curr?.isUp) {
            print('  🔄 接口 $name 状态变化: ${prev.isUp} -> ${curr?.isUp}');
          }
        }
        
        for (final name in _lastWlanInterfaces.keys) {
          if (!currentWlanInterfaces.containsKey(name)) {
            print('  ❌ 删除接口: $name');
          }
        }
        
        // 更新记录
        _lastWlanInterfaces = currentWlanInterfaces;
        
        // 触发UDP发现重启
        if (_running) {
          print('触发UDP发现重启');
          restart();
        }
        print('=== wlan接口检查完成 ===');
      }
    } catch (e) {
      print('检查wlan接口变化失败: $e');
    }
  }

  /// 获取所有wlan*接口及其状态
  Map<String, _WlanInterfaceState> _getWlanInterfaces() {
    final wlanInterfaces = <String, _WlanInterfaceState>{};
    
    for (final iface in _networkManager.availableInterfaces) {
      final name = iface.name.toLowerCase();
      
      // 只关注wlan*接口
      if (name.startsWith('wlan')) {
        wlanInterfaces[iface.name] = _WlanInterfaceState(
          ip: iface.preferredIpv4Address?.address,
          isUp: iface.isUp,
        );
      }
    }
    
    return wlanInterfaces;
  }

  /// 判断wlan接口是否发生变化
  bool _hasWlanInterfaceChanged(Map<String, _WlanInterfaceState> current) {
    // 检查接口数量是否变化
    if (current.length != _lastWlanInterfaces.length) {
      return true;
    }
    
    // 检查接口名称是否变化
    if (current.keys.toSet() != _lastWlanInterfaces.keys.toSet()) {
      return true;
    }
    
    // 检查接口状态是否变化（IP或isUp）
    for (final name in current.keys) {
      final prev = _lastWlanInterfaces[name];
      final curr = current[name];
      
      if (prev == null || prev != curr) {
        return true;
      }
    }
    
    return false;
  }

  /// 启动网络连接状态监听
  void _startConnectivityMonitoring() {
    print('启动网络连接状态监听...');
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      print('网络连接状态变化: $results');
      
      // 检查是否有WiFi连接或热点接口
      final hasWifi = results.contains(ConnectivityResult.wifi);
      final hasMobile = results.contains(ConnectivityResult.mobile);
      
      print('WiFi连接: $hasWifi, 移动网络: $hasMobile');
      
      // 如果有WiFi连接，检查SSID变化
      if (hasWifi) {
        print('检测到WiFi网络连接变化，检查SSID变化...');
        _handleWifiConnectivityChange();
      }
      // 如果有移动网络但没有WiFi，可能是LocalOnlyHotspot
      // LocalOnlyHotspot会被识别为mobile网络，但我们需要检查是否有热点接口
      else if (hasMobile) {
        print('检测到移动网络连接变化，检查是否为热点接口...');
        _handleMobileConnectivityChange();
      }
    });
  }

  /// 停止网络连接状态监听
  void _stopConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// 处理WiFi连接变化
  void _handleWifiConnectivityChange() async {
    // 取消之前的定时器
    _networkChangeTimer?.cancel();
    
    // 延迟检查，等待网络稳定
    _networkChangeTimer = Timer(Duration(seconds: 3), () async {
      await _checkWifiSsidChange();
    });
  }

  /// 处理移动网络连接变化（可能是LocalOnlyHotspot）
  void _handleMobileConnectivityChange() async {
    // 取消之前的定时器
    _networkChangeTimer?.cancel();
    
    // 延迟检查，等待网络稳定
    _networkChangeTimer = Timer(Duration(seconds: 3), () async {
      await _checkHotspotInterfaceChange();
    });
  }

  /// 检查热点接口变化
  Future<void> _checkHotspotInterfaceChange() async {
    try {
      print('=== 检查热点接口变化 ===');
      final allInterfaces = _networkManager.availableInterfaces;
      print('所有可用接口数量: ${allInterfaces.length}');
      
      // 打印所有接口信息
      for (final iface in allInterfaces) {
        print('接口: ${iface.name}, 类型: ${iface.type}, IP: ${iface.preferredIpv4Address?.address ?? "无"}');
      }
      
      // 检查是否有新的热点接口
      final hotspotInterfaces = allInterfaces
          .where((iface) => _isHotspotInterface(iface))
          .toList();
      
      print('检测到热点接口数量: ${hotspotInterfaces.length}');
      
      if (hotspotInterfaces.isNotEmpty) {
        print('✅ 检测到热点接口: ${hotspotInterfaces.map((i) => i.name).join(", ")}');
        
        // 如果有热点接口，触发UDP发现重启
        if (_running) {
          print('检测到热点接口变化，触发UDP发现重启');
          await restart();
        }
      } else {
        print('⚠️ 未检测到热点接口');
      }
      print('=== 热点接口检查完成 ===');
    } catch (e) {
      print('❌ 检查热点接口变化失败: $e');
    }
  }

  /// 判断是否为热点接口
  bool _isHotspotInterface(NetworkInterfaceInfo iface) {
    // LocalOnlyHotspot通常使用wlan0或wlan1接口
    // 特征：接口名称包含wlan，但没有分配IP地址或IP地址为192.168.43.x
    final name = iface.name.toLowerCase();
    final ipv4 = iface.preferredIpv4Address;
    
    print('检查接口 $name: IP=${ipv4?.address ?? "无"}, isUp=${iface.isUp}');
    
    // 检查是否为wlan接口
    if (name.contains('wlan')) {
      // 检查是否为热点接口（无IP或IP为192.168.43.x）
      if (ipv4 == null) {
        print('  ✅ 接口 $name 无IPv4地址，判定为热点接口');
        return true;
      }
      
      // 检查是否为热点IP段
      if (ipv4.address.startsWith('192.168.43.')) {
        print('  ✅ 接口 $name 使用热点IP段 ${ipv4.address}，判定为热点接口');
        return true;
      }
      
      // 检查是否为其他热点IP段（某些设备可能使用不同的IP段）
      if (ipv4.address.startsWith('192.168.49.') || 
          ipv4.address.startsWith('192.168.50.') ||
          ipv4.address.startsWith('10.0.')) {
        print('  ✅ 接口 $name 使用其他热点IP段 ${ipv4.address}，判定为热点接口');
        return true;
      }
    }
    
    return false;
  }

  /// 检查WiFi SSID变化
  Future<void> _checkWifiSsidChange() async {
    try {
      final currentSsid = await _getCurrentWifiSsid();
      
      if (currentSsid != null && currentSsid != _lastWifiSsid) {
        print('检测到WiFi SSID变化: $_lastWifiSsid -> $currentSsid，触发UDP发现重启');
        _lastWifiSsid = currentSsid;
        
        // 重启UDP发现服务
        if (_running) {
          await restart();
        }
      } else if (currentSsid != null) {
        // SSID没有变化，但网络可能已经稳定，更新记录
        _lastWifiSsid = currentSsid;
      }
    } catch (e) {
      print('检查WiFi SSID变化失败: $e');
    }
  }

  /// 获取当前WiFi SSID
  Future<String?> _getCurrentWifiSsid() async {
    try {
      if (Platform.isAndroid) {
        // 对于Android，我们可以通过NetworkInterfaceManager获取当前连接的WiFi信息
        final wifiInterfaces = _networkManager.wifiInterfaces;
        print('检测到WiFi接口数量: ${wifiInterfaces.length}');
        
        if (wifiInterfaces.isNotEmpty) {
          for (final iface in wifiInterfaces) {
            print('WiFi接口: ${iface.name}, 类型: ${iface.type}, IP: ${iface.preferredIpv4Address?.address}');
          }
          
          final wifiInterface = wifiInterfaces.first;
          // 这里我们假设第一个WiFi接口就是当前连接的接口
          // 在实际应用中，可能需要更精确的检测逻辑
          return wifiInterface.name;
        }
      }
      return null;
    } catch (e) {
      print('获取当前WiFi SSID失败: $e');
      return null;
    }
  }

  /// 更新当前WiFi SSID
  Future<void> _updateCurrentWifiSsid() async {
    _lastWifiSsid = await _getCurrentWifiSsid();
    if (_lastWifiSsid != null) {
      print('当前WiFi SSID: $_lastWifiSsid');
    }
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

/// wlan接口状态信息
class _WlanInterfaceState {
  final String? ip;
  final bool isUp;

  _WlanInterfaceState({
    required this.ip,
    required this.isUp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _WlanInterfaceState &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          isUp == other.isUp;

  @override
  int get hashCode => ip.hashCode ^ isUp.hashCode;

  @override
  String toString() => '_WlanInterfaceState(ip: $ip, isUp: $isUp)';
}
