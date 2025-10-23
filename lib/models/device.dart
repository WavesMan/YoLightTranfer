import 'package:flutter/material.dart';

enum DeviceType {
  windows,
  android,
  harmonyos,
  linux,
  macos,
}

extension DeviceTypeExtension on DeviceType {
  IconData get icon {
    switch (this) {
      case DeviceType.windows:
        return Icons.laptop_windows;
      case DeviceType.android:
        return Icons.phone_android;
      case DeviceType.harmonyos:
        return Icons.phone_android;
      case DeviceType.linux:
        return Icons.laptop_chromebook;
      case DeviceType.macos:
        return Icons.laptop_mac;
    }
  }

  Color get color {
    switch (this) {
      case DeviceType.windows:
        return const Color(0xFF0078D4);
      case DeviceType.android:
        return const Color(0xFF3DDC84);
      case DeviceType.harmonyos:
        return const Color(0xFFFF0000);
      case DeviceType.linux:
        return const Color(0xFFFCC624);
      case DeviceType.macos:
        return const Color(0xFF000000);
    }
  }
}

enum DeviceStatus {
  online,
  offline,
}

class Device {
  final String name;
  final DeviceType type;
  final String ip;
  final DeviceStatus status;
  final String lastSeen;

  Device({
    required this.name,
    required this.type,
    required this.ip,
    required this.status,
    required this.lastSeen,
  });
}
