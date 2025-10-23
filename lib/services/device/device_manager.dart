import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yolighttransfer/models/device.dart' as ui;
import 'package:yolighttransfer/models/discovered_device.dart';

/// 发现设备的集中存储与管理，负责维护在线状态与排序。
class DeviceManager extends ChangeNotifier {
  DeviceManager({this.offlineAfterMs = 10000}) {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) => _cleanup());
  }

  final int offlineAfterMs;

  final Map<String, DiscoveredDevice> _devices = {};
  late final Timer _cleanupTimer;
  String? _selectedDeviceId;

  /// 根据收到的心跳新增或更新设备信息。
  void upsertFromHeartbeat(DiscoveredDevice d) {
    // 检查是否已存在该设备
    final existingDevice = _devices[d.id];
    
    // 如果设备已存在，保持原有的IP地址以避免IP闪变
    // 只有当设备是新增时才使用新的IP地址
    final deviceToUpdate = existingDevice != null 
        ? d.copyWith(ip: existingDevice.ip) // 保持原有IP
        : d;
    
    // // 记录设备更新信息
    // final isNew = existingDevice == null;
    // print('=== 设备管理器更新 ===');
    // print('${isNew ? '新增' : '更新'}设备: ${d.name} (${d.id})');
    // print('IP地址: ${deviceToUpdate.ip} ${isNew ? '' : '(保持稳定IP)'}');
    // print('系统: ${d.os}');
    // print('TCP端口: ${d.tcpPort}');
    // print('当前设备总数: ${_devices.length}');
    
    // 覆盖或插入设备；除 lastSeenMs 外，DiscoveredDevice 字段保持不可变。
    _devices[d.id] = deviceToUpdate;
    
    // 记录更新后的在线设备
    final onlineDevices = getOnlineDevices();
    // print('在线设备数量: ${onlineDevices.length}');
    for (final device in onlineDevices) {
      // print('  - ${device.name} (${device.ip})');
    }
    // print('==================');
    
    notifyListeners();
  }

  /// 返回当前在线的设备列表，按device_id稳定排序。
  List<DiscoveredDevice> getOnlineDevices() {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // // 添加详细调试日志
    // print('=== 在线设备检测 ===');
    // print('当前时间: $now');
    // print('离线阈值: $offlineAfterMs 毫秒');
    // print('设备总数: ${_devices.length}');
    
    final onlineDevices = <DiscoveredDevice>[];
    final offlineDevices = <DiscoveredDevice>[];
    
    _devices.values.forEach((device) {
      final timeDiff = now - device.lastSeenMs;
      final isOnline = timeDiff <= offlineAfterMs;
      
      if (isOnline) {
        onlineDevices.add(device);
        // print('✓ 在线设备: ${device.name} (${device.id}) - 最后心跳: ${device.lastSeenMs} (${timeDiff}ms前)');
      } else {
        offlineDevices.add(device);
        // print('✗ 离线设备: ${device.name} (${device.id}) - 最后心跳: ${device.lastSeenMs} (${timeDiff}ms前)');
      }
    });
    
    // print('在线设备数量: ${onlineDevices.length}');
    // print('离线设备数量: ${offlineDevices.length}');
    // print('==================');
    
    // 按device_id稳定排序，确保设备列表顺序固定
    onlineDevices.sort((a, b) {
      // 主要按device_id排序
      int idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      
      // 如果device_id相同（理论上不会发生），按设备名称排序
      return a.name.compareTo(b.name);
    });
    
    return onlineDevices;
  }

  /// 将网络层设备转换为 UI 层模型以便展示。
  List<ui.Device> getUiDevices() {
    final online = getOnlineDevices();
    return online.map(_toUiDevice).toList(growable: false);
  }

  /// 选择设备
  void selectDevice(String deviceId) {
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  /// 取消选择设备
  void deselectDevice() {
    _selectedDeviceId = null;
    notifyListeners();
  }

  /// 获取选中的设备
  DiscoveredDevice? get selectedDevice {
    if (_selectedDeviceId == null) return null;
    return _devices[_selectedDeviceId];
  }

  /// 检查设备是否被选中
  bool isDeviceSelected(String deviceId) {
    return _selectedDeviceId == deviceId;
  }

  /// 清理长时间离线的设备，避免内存占用持续增长。
  void _cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toRemove = <String>[];
    _devices.forEach((key, d) {
      if (now - d.lastSeenMs > offlineAfterMs * 6) {
        toRemove.add(key);
      }
    });
    for (final k in toRemove) {
      _devices.remove(k);
    }
    if (toRemove.isNotEmpty) notifyListeners();
  }

  @override
  void dispose() {
    _cleanupTimer.cancel();
    super.dispose();
  }

  ui.Device _toUiDevice(DiscoveredDevice d) {
    final type = _mapOsToDeviceType(d.os);
    final status = ui.DeviceStatus.online; // 已在上游过滤为在线
    final lastSeenText = _formatLastSeen(d.lastSeenMs);
    return ui.Device(
      name: d.name,
      type: type,
      ip: '${d.ip}:${d.tcpPort}',
      status: status,
      lastSeen: lastSeenText,
    );
  }

  ui.DeviceType _mapOsToDeviceType(String os) {
    switch (os.toLowerCase()) {
      case 'windows':
        return ui.DeviceType.windows;
      case 'android':
        return ui.DeviceType.android;
      case 'linux':
        return ui.DeviceType.linux;
      case 'macos':
      case 'ios':
        return ui.DeviceType.macos;
      case 'harmonyos':
        return ui.DeviceType.harmonyos;
      default:
        return ui.DeviceType.linux; // 中性配色/图标
    }
  }

  String _formatLastSeen(int lastSeenMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    if (diff < 1500) return '刚刚';
    if (diff < 60000) return '${(diff / 1000).floor()}秒前';
    if (diff < 3600000) return '${(diff / 60000).floor()}分钟前';
    return '${(diff / 3600000).floor()}小时前';
  }
}
