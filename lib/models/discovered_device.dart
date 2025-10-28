class DiscoveredDevice {
  final String id;
  final String name;
  final String os;
  final String ip; // IPv4 地址
  final int httpPort; // HTTP 端口
  final String transportMethod; // 传输方式：HTTP
  int lastSeenMs; // 最后一次收到心跳的时间（毫秒时间戳）
  final String? networkInterface; // 网络接口名称
  final String? networkType; // 网络类型

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.os,
    required this.ip,
    required this.httpPort,
    required this.lastSeenMs,
    this.transportMethod = 'HTTP',
    this.networkInterface,
    this.networkType,
  });

  factory DiscoveredDevice.fromBroadcast(Map<String, dynamic> json, String ip) {
    // 使用当前时间作为最后心跳时间，不依赖设备发送的时间戳
    // 这样可以避免不同设备时间戳格式不一致的问题
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 调试日志：记录接收到的时间戳信息
    final receivedTimestamp = (json['Timestamp'] as num?)?.toInt();
    if (receivedTimestamp != null) {
      // print('接收到设备时间戳: $receivedTimestamp, 当前时间: $now, 时间差: ${now - receivedTimestamp}ms');
    }
    
    // 获取传输方式和对应的端口
    final transportMethod = json['Transport_Method'] as String? ?? 'HTTP';
    final httpPort = (json['HTTP_Port'] as num?)?.toInt() ?? 30071;
    
    // 兼容性处理：旧版本可能没有 Network_Interfaces 字段
    String? networkInterface;
    String? networkType;
    
    // 尝试从 Network_Interfaces 对象中获取网络接口信息
    final networkInterfaces = json['Network_Interfaces'] as Map<String, dynamic>?;
    if (networkInterfaces != null && networkInterfaces.isNotEmpty) {
      // 获取第一个网络接口的信息
      final firstInterfaceKey = networkInterfaces.keys.first;
      final firstInterface = networkInterfaces[firstInterfaceKey] as Map<String, dynamic>?;
      if (firstInterface != null) {
        networkInterface = firstInterfaceKey;
        networkType = firstInterface['type'] as String?;
      }
    }
    
    // 如果从 Network_Interfaces 没有获取到信息，尝试从旧字段获取
    if (networkInterface == null) {
      networkInterface = json['Network_Interface'] as String?;
      networkType = json['Network_Type'] as String?;
    }
    
    return DiscoveredDevice(
      id: json['Device_ID'] as String,
      name: json['Device_Name'] as String? ?? 'Unknown',
      os: json['Device_OS'] as String? ?? 'unknown',
      ip: ip,
      httpPort: httpPort,
      transportMethod: transportMethod,
      lastSeenMs: now, // 总是使用当前时间，确保时间戳正确
      networkInterface: networkInterface,
      networkType: networkType,
    );
  }

  /// 创建带有网络接口信息的副本
  DiscoveredDevice copyWith({
    String? id,
    String? name,
    String? os,
    String? ip,
    int? httpPort,
    String? transportMethod,
    int? lastSeenMs,
    String? networkInterface,
    String? networkType,
  }) {
    return DiscoveredDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      os: os ?? this.os,
      ip: ip ?? this.ip,
      httpPort: httpPort ?? this.httpPort,
      transportMethod: transportMethod ?? this.transportMethod,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      networkInterface: networkInterface ?? this.networkInterface,
      networkType: networkType ?? this.networkType,
    );
  }

  Map<String, dynamic> toJson() => {
        'Device_ID': id,
        'Device_Name': name,
        'Device_OS': os,
        'IP': ip,
        'HTTP_Port': httpPort,
        'Transport_Method': transportMethod,
        'Timestamp': lastSeenMs,
        if (networkInterface != null) 'Network_Interface': networkInterface,
        if (networkType != null) 'Network_Type': networkType,
      };

  @override
  String toString() {
    return 'DiscoveredDevice(id: $id, name: $name, os: $os, ip: $ip, httpPort: $httpPort, transportMethod: $transportMethod, networkInterface: $networkInterface, networkType: $networkType)';
  }
}
