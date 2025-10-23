// 网络状态监控服务
// 提供多网络环境的实时状态信息

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/services/network/network_interface_manager.dart';

/// 网络状态信息
class NetworkStatus {
  final bool isRunning;
  final int availableInterfaces;
  final int wifiInterfaces;
  final int ethernetInterfaces;
  final int mobileInterfaces;
  final int listeners;
  final int broadcasters;
  final List<String> listeningAddresses;

  const NetworkStatus({
    required this.isRunning,
    required this.availableInterfaces,
    required this.wifiInterfaces,
    required this.ethernetInterfaces,
    required this.mobileInterfaces,
    required this.listeners,
    required this.broadcasters,
    required this.listeningAddresses,
  });

  @override
  String toString() {
    return 'NetworkStatus(running: $isRunning, '
           'available: $availableInterfaces, '
           'wifi: $wifiInterfaces, '
           'ethernet: $ethernetInterfaces, '
           'mobile: $mobileInterfaces, '
           'listeners: $listeners, '
           'broadcasters: $broadcasters)';
  }
}

/// 网络状态监控服务
class NetworkStatusService extends ChangeNotifier {
  static const Duration _updateInterval = Duration(seconds: 3);

  final NetworkInterfaceManager _networkManager = NetworkInterfaceManager();
  Timer? _updateTimer;
  NetworkStatus _currentStatus = const NetworkStatus(
    isRunning: false,
    availableInterfaces: 0,
    wifiInterfaces: 0,
    ethernetInterfaces: 0,
    mobileInterfaces: 0,
    listeners: 0,
    broadcasters: 0,
    listeningAddresses: [],
  );

  NetworkStatus get currentStatus => _currentStatus;

  /// UDP发现服务状态（由外部设置）
  Map<String, dynamic>? _udpDiscoveryStatus;
  
  /// TCP服务器状态（由外部设置）
  Map<String, dynamic>? _tcpServerStatus;

  /// 启动网络状态监控
  Future<void> startMonitoring() async {
    await _networkManager.initialize();
    
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      _updateNetworkStatus();
    });
    
    // 立即更新一次状态
    _updateNetworkStatus();
  }

  /// 停止网络状态监控
  void stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _networkManager.stopMonitoring();
  }

  /// 更新网络状态
  void _updateNetworkStatus() {
    final newStatus = NetworkStatus(
      isRunning: _udpDiscoveryStatus?['running'] == true || 
                 _tcpServerStatus?['running'] == true,
      availableInterfaces: _networkManager.availableInterfaces.length,
      wifiInterfaces: _networkManager.wifiInterfaces.length,
      ethernetInterfaces: _networkManager.ethernetInterfaces.length,
      mobileInterfaces: _networkManager.mobileInterfaces.length,
      listeners: _udpDiscoveryStatus?['listeners'] ?? 0,
      broadcasters: _udpDiscoveryStatus?['broadcasters'] ?? 0,
      listeningAddresses: _tcpServerStatus?['listeningAddresses'] ?? [],
    );

    if (_currentStatus.toString() != newStatus.toString()) {
      _currentStatus = newStatus;
      notifyListeners();
    }
  }

  /// 设置UDP发现服务状态
  void setUdpDiscoveryStatus(Map<String, dynamic> status) {
    _udpDiscoveryStatus = status;
    _updateNetworkStatus();
  }

  /// 设置TCP服务器状态
  void setTcpServerStatus(Map<String, dynamic> status) {
    _tcpServerStatus = status;
    _updateNetworkStatus();
  }

  /// 获取网络状态摘要
  String getStatusSummary() {
    final status = _currentStatus;
    
    if (!status.isRunning) {
      return '网络服务未运行';
    }

    final parts = <String>[];
    
    if (status.availableInterfaces > 0) {
      parts.add('${status.availableInterfaces}个可用接口');
    }
    
    if (status.wifiInterfaces > 0) {
      parts.add('${status.wifiInterfaces}个WiFi');
    }
    
    if (status.ethernetInterfaces > 0) {
      parts.add('${status.ethernetInterfaces}个以太网');
    }
    
    if (status.mobileInterfaces > 0) {
      parts.add('${status.mobileInterfaces}个移动网络');
    }
    
    if (status.listeners > 0) {
      parts.add('${status.listeners}个监听器');
    }
    
    if (status.broadcasters > 0) {
      parts.add('${status.broadcasters}个广播器');
    }

    return parts.isEmpty ? '网络服务运行中' : parts.join('，');
  }

  /// 获取详细的网络接口信息
  List<Map<String, dynamic>> getDetailedInterfaceInfo() {
    final interfaces = _networkManager.interfaces;
    final detailedInfo = <Map<String, dynamic>>[];

    for (final iface in interfaces) {
      final info = <String, dynamic>{
        'name': iface.name,
        'type': iface.type.toString().split('.').last,
        'isUp': iface.isUp,
        'supportsBroadcast': iface.supportsBroadcast,
        'ipAddresses': iface.addresses.map((addr) => addr.address).toList(),
        'preferredIpv4': iface.preferredIpv4Address?.address,
      };
      detailedInfo.add(info);
    }

    return detailedInfo;
  }

  /// 检查是否有多网络环境
  bool get hasMultipleNetworks {
    return _networkManager.availableInterfaces.length > 1;
  }

  /// 检查是否有移动网络
  bool get hasMobileNetwork {
    return _networkManager.mobileInterfaces.isNotEmpty;
  }

  /// 检查最佳网络类型
  String get bestNetworkType {
    final wifi = _networkManager.wifiInterfaces;
    if (wifi.isNotEmpty) return 'WiFi';
    
    final ethernet = _networkManager.ethernetInterfaces;
    if (ethernet.isNotEmpty) return '以太网';
    
    final available = _networkManager.availableInterfaces;
    if (available.isNotEmpty) return '其他网络';
    
    return '无可用网络';
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _networkManager.dispose();
  }
}
