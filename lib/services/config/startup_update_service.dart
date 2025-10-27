import 'package:flutter/material.dart';
import 'package:yolighttransfer/util/version_check_parser.dart';
import 'package:yolighttransfer/widgets/update_dialog.dart';
import 'version_service.dart';
import 'package:flutter/services.dart';

/// 启动更新检查服务
class StartupUpdateService {
  static final StartupUpdateService _instance = StartupUpdateService._internal();
  
  bool _isChecking = false;
  bool _hasShownUpdateDialog = false;

  StartupUpdateService._internal();

  factory StartupUpdateService() {
    return _instance;
  }

  /// 在应用启动时检查更新
  /// 
  /// 如果发现更新，显示更新对话框
  /// 如果没有更新或检查失败，正常启动应用
  Future<void> checkForUpdatesOnStartup(BuildContext context) async {
    // 防止重复检查
    if (_isChecking || _hasShownUpdateDialog) {
      return;
    }

    // 检查配置是否启用启动更新检查
    final isEnabled = await _isStartupUpdateCheckEnabled();
    if (!isEnabled) {
      print('⚙️ 启动更新检查已禁用');
      return;
    }

    _isChecking = true;

    try {
      print('🔍 启动时检查更新...');
      
      final versionService = VersionService();
      final timeoutSeconds = await _getUpdateCheckTimeout();
      final versionResponse = await versionService.checkForUpdates(
        timeout: Duration(seconds: timeoutSeconds),
      );

      if (versionResponse.needsUpdate) {
        print('🔄 发现新版本: ${versionResponse.version}');
        
        // 使用 Future.microtask 确保在正确的上下文中显示对话框
        Future.microtask(() {
          _showUpdateDialog(context, versionResponse, versionService.fullVersion);
        });
      } else {
        print('✅ 当前已是最新版本');
      }
    } catch (e) {
      // 网络异常或其他错误，静默失败不影响正常启动
      print('⚠️ 启动更新检查失败: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// 显示更新对话框
  Future<void> _showUpdateDialog(
    BuildContext context,
    VersionCheckResponse versionResponse,
    String currentVersion,
  ) async {
    // 防止重复显示对话框
    if (_hasShownUpdateDialog) {
      return;
    }

    _hasShownUpdateDialog = true;

    await showUpdateDialog(
      context,
      versionResponse: versionResponse,
      currentVersion: currentVersion,
      onDownload: () {
        print('📥 用户点击下载按钮');
      },
      onCancel: () {
        print('❌ 用户选择暂不更新');
        _hasShownUpdateDialog = false; // 允许下次启动时再次显示
      },
    );
  }

  /// 重置状态（用于测试或特殊情况）
  void reset() {
    _isChecking = false;
    _hasShownUpdateDialog = false;
  }

  /// 获取检查状态
  bool get isChecking => _isChecking;

  /// 获取是否已显示更新对话框
  bool get hasShownUpdateDialog => _hasShownUpdateDialog;

  /// 检查是否启用启动更新检查
  Future<bool> _isStartupUpdateCheckEnabled() async {
    try {
      final configContent = await rootBundle.loadString('lib/config.yaml');
      final lines = configContent.split('\n');
      
      for (final line in lines) {
        if (line.contains('startupUpdateCheck:')) {
          final value = _extractYamlValue(line);
          return value.toLowerCase() == 'true';
        }
      }
      
      // 默认启用
      return true;
    } catch (e) {
      print('⚠️ 读取启动更新检查配置失败: $e，使用默认值 true');
      return true;
    }
  }

  /// 获取更新检查超时时间（秒）
  Future<int> _getUpdateCheckTimeout() async {
    try {
      final configContent = await rootBundle.loadString('lib/config.yaml');
      final lines = configContent.split('\n');
      
      for (final line in lines) {
        if (line.contains('updateCheckTimeout:')) {
          final value = _extractYamlValue(line);
          final timeout = int.tryParse(value) ?? 8;
          return timeout.clamp(3, 30); // 限制在3-30秒之间
        }
      }
      
      // 默认8秒
      return 8;
    } catch (e) {
      print('⚠️ 读取更新检查超时配置失败: $e，使用默认值 8');
      return 8;
    }
  }

  /// 从 YAML 行中提取值
  String _extractYamlValue(String line) {
    // 找到第一个冒号的位置
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return '';
    
    // 从冒号后面提取所有内容
    var value = line.substring(colonIndex + 1).trim();
    
    // 移除引号（单引号或双引号）
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }
    
    return value;
  }
}
