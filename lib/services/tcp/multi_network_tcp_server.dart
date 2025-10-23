// 多网络TCP传输服务器
// 支持在多个网络接口上同时监听，适配移动网络环境

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:yolighttransfer/services/network/network_interface_manager.dart';

/// 多网络TCP服务器
/// 支持在多个网络接口上同时监听，适配移动网络环境
class MultiNetworkTcpServer {
  static const Duration _cleanupInterval = Duration(seconds: 30);

  final NetworkInterfaceManager _networkManager = NetworkInterfaceManager();
  
  // 多网络服务器套接字
  final List<ServerSocket> _servers = [];
  // 客户端连接
  final List<Socket> _clients = [];
  
  Timer? _cleanupTimer;
  bool _running = false;
  int _port;

  bool get isRunning => _running;
  bool get isSupported => !kIsWeb; // Web 端不支持 dart:io 套接字

  /// 客户端连接回调
  final void Function(Socket client, NetworkInterfaceInfo iface)? onClientConnected;
  
  /// 客户端断开回调
  final void Function(Socket client)? onClientDisconnected;
  
  /// 错误回调
  final void Function(Object error, NetworkInterfaceInfo iface)? onError;

  MultiNetworkTcpServer({
    required int port,
    this.onClientConnected,
    this.onClientDisconnected,
    this.onError,
  }) : _port = port;

  /// 启动多网络TCP服务器
  Future<void> start() async {
    if (!isSupported) return;
    if (_running) return;

    // 初始化网络接口管理器
    await _networkManager.initialize();

    // 在所有可用网络接口上启动服务器
    await _startMultiNetworkServers();

    // 启动清理定时器
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanupStaleConnections());

    _running = true;
    print('多网络TCP服务器已启动，在 ${_servers.length} 个网络接口上监听端口 $_port');
  }

  /// 在所有可用网络接口上启动服务器
  Future<void> _startMultiNetworkServers() async {
    final availableInterfaces = _networkManager.availableInterfaces;
    
    for (final iface in availableInterfaces) {
      try {
        // 获取网络接口的IPv4地址
        final ipAddress = iface.preferredIpv4Address;
        if (ipAddress == null) {
          print('网络接口 ${iface.name} 没有有效的IPv4地址，跳过');
          continue;
        }

        // 在网络接口上绑定TCP服务器
        final server = await ServerSocket.bind(ipAddress, _port);
        
        server.listen(
          (client) => _handleNewClient(client, iface),
          onError: (error) => _handleServerError(error, iface),
          onDone: () => _handleServerDone(iface),
        );
        
        _servers.add(server);
        print('在网络接口 ${iface.name} (${iface.type}) ${ipAddress.address}:$_port 上启动TCP服务器');
      } catch (e) {
        print('在网络接口 ${iface.name} 上启动TCP服务器失败: $e');
        onError?.call(e, iface);
      }
    }
  }

  /// 处理新客户端连接
  void _handleNewClient(Socket client, NetworkInterfaceInfo iface) {
    _clients.add(client);
    
    print('新客户端连接来自 ${client.remoteAddress.address}:${client.remotePort} '
          '通过网络接口 ${iface.name} (${iface.type})');
    
    // 设置客户端断开处理
    client.done.then((_) {
      _handleClientDisconnected(client);
    }).catchError((error) {
      _handleClientError(client, error);
    });

    // 调用连接回调
    onClientConnected?.call(client, iface);
  }

  /// 处理客户端断开
  void _handleClientDisconnected(Socket client) {
    _clients.remove(client);
    print('客户端 ${client.remoteAddress.address}:${client.remotePort} 已断开');
    onClientDisconnected?.call(client);
  }

  /// 处理客户端错误
  void _handleClientError(Socket client, Object error) {
    print('客户端 ${client.remoteAddress.address}:${client.remotePort} 错误: $error');
    _clients.remove(client);
    client.close();
  }

  /// 处理服务器错误
  void _handleServerError(Object error, NetworkInterfaceInfo iface) {
    print('网络接口 ${iface.name} TCP服务器错误: $error');
    onError?.call(error, iface);
  }

  /// 处理服务器完成
  void _handleServerDone(NetworkInterfaceInfo iface) {
    print('网络接口 ${iface.name} TCP服务器已关闭');
    // 服务器关闭时自动从列表中移除
  }

  /// 清理过期的连接
  void _cleanupStaleConnections() {
    final staleClients = <Socket>[];
    
    for (final client in _clients) {
      // 检查客户端是否已断开
      try {
        // 尝试发送一个空数据包来检测连接状态
        client.add([]);
      } catch (e) {
        // 如果发送失败，说明连接已断开
        staleClients.add(client);
      }
    }
    
    for (final client in staleClients) {
      _clients.remove(client);
      client.close();
    }
    
    if (staleClients.isNotEmpty) {
      print('清理了 ${staleClients.length} 个过期的客户端连接');
    }
  }

  /// 停止多网络TCP服务器
  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // 关闭所有客户端连接
    for (final client in List<Socket>.from(_clients)) {
      await client.close();
    }
    _clients.clear();

    // 关闭所有服务器
    for (final server in _servers) {
      await server.close();
    }
    _servers.clear();

    _networkManager.stopMonitoring();
    _running = false;
    print('多网络TCP服务器已停止');
  }

  /// 获取当前服务器状态
  Map<String, dynamic> getServerStatus() {
    return {
      'running': _running,
      'servers': _servers.length,
      'clients': _clients.length,
      'port': _port,
      'availableInterfaces': _networkManager.availableInterfaces.length,
      'wifiInterfaces': _networkManager.wifiInterfaces.length,
      'ethernetInterfaces': _networkManager.ethernetInterfaces.length,
    };
  }

  /// 获取所有监听的地址
  List<String> getListeningAddresses() {
    final addresses = <String>[];
    
    for (final server in _servers) {
      final address = server.address;
      if (address is InternetAddress) {
        addresses.add('${address.address}:$_port');
      }
    }
    
    return addresses;
  }

  /// 广播数据到所有客户端
  void broadcastToAllClients(List<int> data) {
    final disconnectedClients = <Socket>[];
    
    for (final client in _clients) {
      try {
        client.add(data);
      } catch (e) {
        print('向客户端 ${client.remoteAddress.address} 广播失败: $e');
        disconnectedClients.add(client);
      }
    }
    
    // 清理断开的客户端
    for (final client in disconnectedClients) {
      _clients.remove(client);
      client.close();
    }
  }

  /// 设置服务器端口（需要重启服务器）
  Future<void> setPort(int newPort) async {
    if (_port == newPort) return;
    
    final wasRunning = _running;
    if (wasRunning) {
      await stop();
    }
    
    _port = newPort;
    
    if (wasRunning) {
      await start();
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _networkManager.dispose();
  }
}
