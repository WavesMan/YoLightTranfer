/// QR码解析工具类
class QRCodeParser {
  /// 解析WiFi QR码
  /// WiFi QR码格式: WIFI:S:<SSID>;T:<加密类型>;P:<密码>;;
  static QRParseResult parseWiFiQRCode(String qrData) {
    try {
      print('=== QR码解析器调试 ===');
      print('输入数据: $qrData');
      print('数据长度: ${qrData.length}');
      
      if (!qrData.startsWith('WIFI:')) {
        return QRParseResult.error('不是有效的WiFi QR码');
      }

      // 移除WIFI:前缀
      final dataWithoutPrefix = qrData.substring(5);
      print('移除前缀后: $dataWithoutPrefix');
      
      final parts = dataWithoutPrefix.split(';');
      print('分割后的部分数: ${parts.length}');
      for (int i = 0; i < parts.length; i++) {
        print('  parts[$i]: "${parts[i]}"');
      }
      
      String? ssid;
      String? password;
      String? encryptionType;

      for (final part in parts) {
        if (part.isEmpty) continue; // 跳过空字符串
        
        if (part.startsWith('S:')) {
          ssid = part.substring(2);
          print('✅ 提取SSID: $ssid');
        } else if (part.startsWith('P:')) {
          password = part.substring(2);
          print('✅ 提取密码: ${password?.length}字符');
        } else if (part.startsWith('T:')) {
          encryptionType = part.substring(2);
          print('✅ 提取加密类型: $encryptionType');
        }
      }

      print('最终结果:');
      print('  ssid: $ssid');
      print('  password: $password');
      print('  encryptionType: $encryptionType');
      
      if (ssid == null || password == null) {
        print('❌ 缺少SSID或密码');
        return QRParseResult.error('QR码格式不正确，缺少SSID或密码');
      }

      // 验证加密类型
      if (encryptionType != null && encryptionType != 'WPA' && encryptionType != 'WEP') {
        return QRParseResult.error('不支持的加密类型: $encryptionType');
      }

      print('✅ QR码解析成功');
      return QRParseResult.success(
        ssid: ssid,
        password: password,
        encryptionType: encryptionType ?? 'WPA',
      );
    } catch (e, stack) {
      print('❌ QR码解析异常: $e');
      print('堆栈: $stack');
      return QRParseResult.error('QR码解析失败: $e');
    }
  }

  /// 验证SSID和密码格式
  static ValidationResult validateCredentials(String ssid, String password) {
    if (ssid.isEmpty || password.isEmpty) {
      return ValidationResult.error('SSID和密码不能为空');
    }

    if (ssid.length < 1 || ssid.length > 32) {
      return ValidationResult.error('SSID长度应在1-32个字符之间');
    }

    if (password.length < 8 || password.length > 63) {
      return ValidationResult.error('密码长度应在8-63个字符之间');
    }

    return ValidationResult.success();
  }
}

/// QR码解析结果
class QRParseResult {
  final bool success;
  final String? ssid;
  final String? password;
  final String? encryptionType;
  final String? error;

  QRParseResult.success({
    required this.ssid,
    required this.password,
    this.encryptionType,
  })  : success = true,
        error = null;

  QRParseResult.error(this.error)
      : success = false,
        ssid = null,
        password = null,
        encryptionType = null;
}

/// 验证结果
class ValidationResult {
  final bool success;
  final String? error;

  ValidationResult.success()
      : success = true,
        error = null;

  ValidationResult.error(this.error) : success = false;
}
