import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 网络接口类型
enum NetworkInterfaceType {
  wifi,        // WiFi网络
  ethernet,    // 有线以太网
  mobile,      // 移动网络/蜂窝网络
  virtual,     // 虚拟网络
  other,       // 其他类型
}

/// 网络接口信息
class NetworkInterfaceInfo {
  final String name;
  final NetworkInterfaceType type;
  final List<InternetAddress> addresses;
  final bool isUp;
  final bool supportsBroadcast;

  const NetworkInterfaceInfo({
    required this.name,
    required this.type,
    required this.addresses,
    required this.isUp,
    required this.supportsBroadcast,
  });

  /// 获取IPv4地址列表
  List<InternetAddress> get ipv4Addresses {
    return addresses.where((addr) => addr.type == InternetAddressType.IPv4).toList();
  }

  /// 获取IPv6地址列表
  List<InternetAddress> get ipv6Addresses {
    return addresses.where((addr) => addr.type == InternetAddressType.IPv6).toList();
  }

  /// 获取首选IPv4地址（如果有）
  InternetAddress? get preferredIpv4Address {
    final ipv4Addrs = ipv4Addresses;
    if (ipv4Addrs.isEmpty) return null;
    
    // 优先选择非回环地址
    final nonLoopback = ipv4Addrs.where((addr) => !addr.isLoopback).toList();
    return nonLoopback.isNotEmpty ? nonLoopback.first : ipv4Addrs.first;
  }

  @override
  String toString() {
    return 'NetworkInterfaceInfo(name: $name, type: $type, addresses: ${addresses.length}, isUp: $isUp)';
  }
}

/// 网络接口管理器
/// 负责检测和管理所有可用的网络接口，支持多网络环境
class NetworkInterfaceManager extends ChangeNotifier {
  static const Duration _refreshInterval = Duration(seconds: 5);
  
  final List<NetworkInterfaceInfo> _interfaces = [];
  Timer? _refreshTimer;
  bool _isMonitoring = false;

  List<NetworkInterfaceInfo> get interfaces => List.unmodifiable(_interfaces);
  
  /// 获取所有可用的网络接口（排除移动网络）
  List<NetworkInterfaceInfo> get availableInterfaces {
    return _interfaces.where((iface) => 
      iface.isUp && 
      iface.type != NetworkInterfaceType.mobile &&
      iface.preferredIpv4Address != null
    ).toList();
  }

  /// 获取WiFi网络接口
  List<NetworkInterfaceInfo> get wifiInterfaces {
    return _interfaces.where((iface) => 
      iface.isUp && 
      iface.type == NetworkInterfaceType.wifi &&
      iface.preferredIpv4Address != null
    ).toList();
  }

  /// 获取以太网接口
  List<NetworkInterfaceInfo> get ethernetInterfaces {
    return _interfaces.where((iface) => 
      iface.isUp && 
      iface.type == NetworkInterfaceType.ethernet &&
      iface.preferredIpv4Address != null
    ).toList();
  }

  /// 获取移动网络接口
  List<NetworkInterfaceInfo> get mobileInterfaces {
    return _interfaces.where((iface) => 
      iface.isUp && 
      iface.type == NetworkInterfaceType.mobile
    ).toList();
  }

  /// 初始化网络接口管理器
  Future<void> initialize() async {
    await _refreshInterfaces();
    _startMonitoring();
  }

  /// 刷新网络接口信息
  Future<void> _refreshInterfaces() async {
    if (kIsWeb) {
      // Web平台不支持网络接口检测
      return;
    }

    try {
      final systemInterfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );

      final newInterfaces = <NetworkInterfaceInfo>[];
      
      // 记录网络接口检测结果
      // print('=== 网络接口检测结果 ===');
      // print('检测到 ${systemInterfaces.length} 个网络接口');
      
      for (final iface in systemInterfaces) {
        final type = _classifyInterfaceType(iface);
        final info = NetworkInterfaceInfo(
          name: iface.name,
          type: type,
          addresses: iface.addresses,
          isUp: true, // 假设所有检测到的接口都是活动的
          supportsBroadcast: type != NetworkInterfaceType.mobile,
        );
        newInterfaces.add(info);
        
        // 详细记录每个接口的信息
        final ipv4Addrs = info.ipv4Addresses;
        final preferredIp = info.preferredIpv4Address?.address ?? '无IPv4地址';
        // print('接口: ${iface.name} | 类型: ${type.toString()} | IPv4地址: $preferredIp | 支持广播: ${info.supportsBroadcast}');
        if (ipv4Addrs.isNotEmpty) {
          for (final addr in ipv4Addrs) {
            // print('  - ${addr.address} (${addr.type})');
          }
        }
      }
      
      // print('可用接口: ${availableInterfaces.length} 个');
      // print('WiFi接口: ${wifiInterfaces.length} 个');
      // print('以太网接口: ${ethernetInterfaces.length} 个');
      // print('移动网络接口: ${mobileInterfaces.length} 个');
      // print('========================');

      _interfaces.clear();
      _interfaces.addAll(newInterfaces);
      notifyListeners();
    } catch (e) {
      // print('刷新网络接口失败: $e');
    }
  }

  /// 分类网络接口类型
  NetworkInterfaceType _classifyInterfaceType(NetworkInterface iface) {
    final name = iface.name.toLowerCase();
    
    // Windows特定网络接口检测
    if (Platform.isWindows) {
      final windowsType = _classifyWindowsInterface(name);
      if (windowsType != NetworkInterfaceType.other) {
        return windowsType;
      }
    }
    
    // Android特定网络接口检测
    if (Platform.isAndroid) {
      final androidType = _classifyAndroidInterface(name);
      if (androidType != NetworkInterfaceType.other) {
        return androidType;
      }
    }
    
    // 移动网络检测
    if (_isMobileInterface(name)) {
      return NetworkInterfaceType.mobile;
    }
    
    // WiFi网络检测
    if (_isWifiInterface(name)) {
      return NetworkInterfaceType.wifi;
    }
    
    // 以太网检测
    if (_isEthernetInterface(name)) {
      return NetworkInterfaceType.ethernet;
    }
    
    // 虚拟网络检测
    if (_isVirtualInterface(name)) {
      return NetworkInterfaceType.virtual;
    }
    
    return NetworkInterfaceType.other;
  }

  /// Android平台特定的网络接口分类
  NetworkInterfaceType _classifyAndroidInterface(String interfaceName) {
    // Android WiFi接口
    final androidWifiPatterns = [
      'wlan', 'wifi', 'p2p'
    ];
    if (androidWifiPatterns.any((pattern) => interfaceName.contains(pattern))) {
      return NetworkInterfaceType.wifi;
    }
    
    // Android移动网络接口
    final androidMobilePatterns = [
      'rmnet', 'pdp', 'uwbr', 'ccmni', 'ccci'
    ];
    if (androidMobilePatterns.any((pattern) => interfaceName.contains(pattern))) {
      return NetworkInterfaceType.mobile;
    }
    
    // Android以太网接口
    final androidEthernetPatterns = [
      'eth', 'usb', 'rndis'
    ];
    if (androidEthernetPatterns.any((pattern) => interfaceName.contains(pattern))) {
      return NetworkInterfaceType.ethernet;
    }
    
    return NetworkInterfaceType.other;
  }

  /// Windows平台特定的网络接口分类
  NetworkInterfaceType _classifyWindowsInterface(String interfaceName) {
    // Windows WiFi接口
    final windowsWifiPatterns = [
      'wi-fi', 'wireless', 'wlan', '802.11', 'microsoft wi-fi direct'
    ];
    if (windowsWifiPatterns.any((pattern) => interfaceName.contains(pattern))) {
      return NetworkInterfaceType.wifi;
    }
    
    // Windows以太网接口
    final windowsEthernetPatterns = [
      'ethernet', 'local area connection', 'lan', 'intel', 'realtek', 'broadcom'
    ];
    if (windowsEthernetPatterns.any((pattern) => interfaceName.contains(pattern))) {
      return NetworkInterfaceType.ethernet;
    }
    
    // Windows虚拟网络接口（需要特殊处理）
    final windowsVirtualPatterns = [
      'virtualbox', 'vmware', 'hyper-v', 'vpn', 'tap-windows', 'wireguard'
    ];
    if (windowsVirtualPatterns.any((pattern) => interfaceName.contains(pattern))) {
      // 对于VPN和虚拟网络，根据实际情况决定是否支持广播
      return NetworkInterfaceType.virtual;
    }
    
    // Windows蓝牙网络接口
    if (interfaceName.contains('bluetooth')) {
      return NetworkInterfaceType.mobile;
    }
    
    return NetworkInterfaceType.other;
  }

  /// 检测是否为移动网络接口
  bool _isMobileInterface(String interfaceName) {
    final mobilePatterns = [
      'cellular', 'wwan', 'rmnet', 'pdp', 'mobile', '3g', '4g', '5g', 'lte'
    ];
    
    return mobilePatterns.any((pattern) => interfaceName.contains(pattern));
  }

  /// 检测是否为WiFi接口
  bool _isWifiInterface(String interfaceName) {
    final wifiPatterns = [
      'wlan', 'wifi', 'wireless', 'wi-fi', 'ath', 'wlp'
    ];
    
    return wifiPatterns.any((pattern) => interfaceName.contains(pattern));
  }

  /// 检测是否为以太网接口
  bool _isEthernetInterface(String interfaceName) {
    final ethernetPatterns = [
      'eth', 'en', 'ethernet', 'lan', 'local area connection'
    ];
    
    return ethernetPatterns.any((pattern) => interfaceName.contains(pattern));
  }

  /// 检测是否为虚拟接口
  bool _isVirtualInterface(String interfaceName) {
    final virtualPatterns = [
      'veth', 'docker', 'br-', 'virbr', 'vbox', 'vmware', 'virtual', 'tap', 'tun'
    ];
    
    return virtualPatterns.any((pattern) => interfaceName.contains(pattern));
  }

  /// 启动网络接口监控
  void _startMonitoring() {
    if (_isMonitoring) return;
    
    _refreshTimer = Timer.periodic(_refreshInterval, (_) async {
      await _refreshInterfaces();
    });
    
    _isMonitoring = true;
  }

  /// 停止网络接口监控
  void stopMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isMonitoring = false;
  }

  /// 获取最佳网络接口（按优先级排序）
  NetworkInterfaceInfo? getBestInterface() {
    final available = availableInterfaces;
    if (available.isEmpty) return null;

    // 优先级：WiFi > 以太网 > 其他
    final wifi = wifiInterfaces;
    if (wifi.isNotEmpty) return wifi.first;

    final ethernet = ethernetInterfaces;
    if (ethernet.isNotEmpty) return ethernet.first;

    return available.first;
  }

  /// 获取所有可用的IPv4广播地址
  List<InternetAddress> getBroadcastAddresses() {
    final broadcastAddrs = <InternetAddress>[];
    
    // 首先添加全局广播地址
    broadcastAddrs.add(InternetAddress('255.255.255.255'));
    
    // 然后为每个网络接口计算子网特定的广播地址
    for (final iface in availableInterfaces) {
      if (iface.supportsBroadcast) {
        final subnetBroadcasts = _calculateSubnetBroadcastAddresses(iface);
        broadcastAddrs.addAll(subnetBroadcasts);
      }
    }
    
    // 去重
    final uniqueAddrs = <String, InternetAddress>{};
    for (final addr in broadcastAddrs) {
      uniqueAddrs[addr.address] = addr;
    }
    
    // print('计算出的广播地址: ${uniqueAddrs.values.map((a) => a.address).toList()}');
    return uniqueAddrs.values.toList();
  }

  /// 计算子网特定的广播地址
  List<InternetAddress> _calculateSubnetBroadcastAddresses(NetworkInterfaceInfo iface) {
    final broadcastAddrs = <InternetAddress>[];
    
    for (final addr in iface.ipv4Addresses) {
      try {
        // 解析IP地址和子网掩码
        final ipParts = addr.address.split('.');
        if (ipParts.length != 4) continue;
        
        // 假设标准子网掩码（根据实际情况可能需要更复杂的计算）
        // 这里我们使用常见的子网掩码
        final subnetMasks = ['255.255.255.0', '255.255.0.0', '255.0.0.0'];
        
        for (final mask in subnetMasks) {
          final broadcastAddr = _calculateBroadcastAddress(addr.address, mask);
          if (broadcastAddr != null) {
            broadcastAddrs.add(InternetAddress(broadcastAddr));
          }
        }
      } catch (e) {
        print('计算子网广播地址失败: $e');
      }
    }
    
    return broadcastAddrs;
  }

  /// 根据IP地址和子网掩码计算广播地址
  String? _calculateBroadcastAddress(String ip, String subnetMask) {
    try {
      final ipParts = ip.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();
      
      if (ipParts.length != 4 || maskParts.length != 4) return null;
      
      // 计算网络地址
      final networkParts = <int>[];
      for (int i = 0; i < 4; i++) {
        networkParts.add(ipParts[i] & maskParts[i]);
      }
      
      // 计算广播地址（网络地址 + 反掩码）
      final broadcastParts = <int>[];
      for (int i = 0; i < 4; i++) {
        broadcastParts.add(networkParts[i] | (~maskParts[i] & 0xFF));
      }
      
      return broadcastParts.join('.');
    } catch (e) {
      print('计算广播地址失败: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _interfaces.clear();
  }
}
