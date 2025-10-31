// 热点分享页面 - 重构版本
// 使用模块化组件架构

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_manager.dart';
import 'package:yolighttransfer/services/ai_network_quality_manager.dart';
import 'package:yolighttransfer/pages/hotspot/components/network_quality_card.dart';
import 'package:yolighttransfer/pages/hotspot/components/hotspot_status_card.dart';
import 'package:yolighttransfer/pages/hotspot/components/qr_code_card.dart';
import 'package:yolighttransfer/pages/hotspot/components/hotspot_info_card.dart';
import 'package:yolighttransfer/pages/hotspot/components/tutorial_card.dart';
import 'package:yolighttransfer/pages/hotspot/components/action_buttons.dart';
import 'package:yolighttransfer/pages/hotspot/utils/hotspot_permission_handler.dart';
import 'package:yolighttransfer/pages/hotspot/utils/hotspot_state_manager.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_state_provider.dart';

class HotspotShareScreen extends StatefulWidget {
  const HotspotShareScreen({super.key});

  @override
  State<HotspotShareScreen> createState() => _HotspotShareScreenState();
}

class _HotspotShareScreenState extends State<HotspotShareScreen> {
  final HotspotManager _hotspotManager = HotspotManagerFactory.create();
  Timer? _qualityTimer;

  @override
  void initState() {
    super.initState();
    print('=== HotspotShareScreen初始化 ===');
    print('平台: ${Platform.operatingSystem}');
    print('热点管理器: ${_hotspotManager.platformName}');
    
    _initializeHotspotState();
    _startQualityMonitoring();
  }

  /// 初始化热点状态
  void _initializeHotspotState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hotspotProvider = context.read<HotspotStateProvider>();
      
      // 如果还没有凭据，生成新的
      if (hotspotProvider.ssid.isEmpty) {
        hotspotProvider.regenerateCredentials();
      }
      
      // 恢复热点状态（查询系统实际状态）
      await hotspotProvider.restoreState(_hotspotManager);
    });
  }

  @override
  void dispose() {
    _qualityTimer?.cancel();
    super.dispose();
  }


  /// 启动网络质量监控
  void _startQualityMonitoring() {
    _qualityTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hotspotProvider = context.watch<HotspotStateProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('热点分享'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 网络质量卡片
            NetworkQualityCard(
              onManualDetection: _startManualDetection,
            ),
            const SizedBox(height: 16),
            
            // Windows平台：显示热点开启教程卡片
            if (Platform.isWindows)
              const TutorialCard()
            else
            // 其他平台：显示热点状态卡片
            HotspotStatusCard(
              isHotspotRunning: hotspotProvider.isHotspotRunning,
              isLoading: hotspotProvider.isLoading,
              platformName: _hotspotManager.platformName,
              onToggleHotspot: (value) => _toggleHotspot(),
            ),
            
            // Windows平台不显示QR码和热点信息
            if (!Platform.isWindows && hotspotProvider.isHotspotRunning) ...[
              const SizedBox(height: 16),
              QRCodeCard(
                ssid: hotspotProvider.ssid,
                password: hotspotProvider.password,
              ),
              const SizedBox(height: 16),
              HotspotInfoCard(
                ssid: hotspotProvider.ssid,
                password: hotspotProvider.password,
                isLoading: hotspotProvider.isLoading,
                isSystemGenerated: hotspotProvider.isSystemGenerated,
                onCopyInfo: _copyHotspotInfo,
                onRegenerateCredentials: hotspotProvider.isSystemGenerated ? null : _regenerateCredentials,
              ),
            ],
            
            // 操作按钮
            ActionButtons(
              isHotspotRunning: hotspotProvider.isHotspotRunning,
              isLoading: hotspotProvider.isLoading,
              onToggleHotspot: _toggleHotspot,
            ),
          ],
        ),
      ),
    );
  }

  /// 开启热点
  Future<void> _startHotspot() async {
    final hotspotProvider = context.read<HotspotStateProvider>();
    
    print('=== 尝试开启热点 ===');
    print('平台: ${Platform.operatingSystem}');
    print('SSID: ${hotspotProvider.ssid}');
    print('热点管理器: ${_hotspotManager.platformName}');
    
    hotspotProvider.setLoading(true);
    
    try {
      // 检查并请求必要的权限
      final hasPermission = await HotspotPermissionHandler.checkAndRequestPermissions(context);
      if (!hasPermission) {
        HotspotStateManager.showSnackBar(context, '缺少必要的权限，无法创建热点');
        hotspotProvider.setLoading(false);
        return;
      }
      
      final success = await _hotspotManager.createHotspot(
        ssid: hotspotProvider.ssid,
        password: hotspotProvider.password,
      );
      
      print('热点开启结果: $success');
      
      if (success) {
        hotspotProvider.setHotspotRunning(true);
        HotspotStateManager.showSnackBar(context, '热点已开启');
        
        // 如果是Android平台，尝试获取系统实际生成的热点信息
        if (Platform.isAndroid) {
          await _getActualHotspotInfo();
        }
      } else {
        HotspotStateManager.showSnackBar(context, '热点开启失败');
        if (Platform.isWindows) {
          print('⚠️ Windows平台热点开启失败，可能需要管理员权限');
        }
      }
    } catch (e, stack) {
      print('❌ 热点开启异常: $e');
      print('堆栈: $stack');
      HotspotStateManager.showSnackBar(context, '热点开启异常: $e');
    } finally {
      hotspotProvider.setLoading(false);
    }
  }

  /// 停止热点
  Future<void> _stopHotspot() async {
    final hotspotProvider = context.read<HotspotStateProvider>();
    
    hotspotProvider.setLoading(true);
    
    try {
      final success = await _hotspotManager.stopHotspot();
      
      if (success) {
        hotspotProvider.setHotspotRunning(false);
        hotspotProvider.clearSystemGeneratedInfo();
        HotspotStateManager.showSnackBar(context, '热点已关闭');
      } else {
        HotspotStateManager.showSnackBar(context, '热点关闭失败');
      }
    } catch (e) {
      HotspotStateManager.showSnackBar(context, '热点关闭异常: $e');
    } finally {
      hotspotProvider.setLoading(false);
    }
  }

  /// 切换热点状态
  Future<void> _toggleHotspot() async {
    final hotspotProvider = context.read<HotspotStateProvider>();
    if (hotspotProvider.isHotspotRunning) {
      await _stopHotspot();
    } else {
      await _startHotspot();
    }
  }

  /// 重新生成凭据
  void _regenerateCredentials() {
    final hotspotProvider = context.read<HotspotStateProvider>();
    hotspotProvider.regenerateCredentials();
    HotspotStateManager.showSnackBar(context, '热点凭据已重新生成');
  }

  /// 复制热点信息
  void _copyHotspotInfo() async {
    final hotspotProvider = context.read<HotspotStateProvider>();
    final info = 'SSID: ${hotspotProvider.ssid}\n密码: ${hotspotProvider.password}';
    
    try {
      await Clipboard.setData(ClipboardData(text: info));
      HotspotStateManager.showSnackBar(context, '热点信息已复制到剪贴板');
    } catch (e) {
      HotspotStateManager.showSnackBar(context, '复制失败: $e');
    }
  }

  /// 手动开始网络质量检测
  Future<void> _startManualDetection() async {
    final qualityManager = Provider.of<AINetworkQualityManager>(context, listen: false);
    await qualityManager.startDetection(forceRefresh: true);
  }

  /// 获取系统实际生成的热点信息
  Future<void> _getActualHotspotInfo() async {
    final hotspotProvider = context.read<HotspotStateProvider>();
    
    try {
      print('=== 尝试获取系统实际热点信息 ===');
      
      // 等待Android端的LocalOnlyHotspot回调完成
      // 通常需要500-1000ms的延迟
      await Future.delayed(const Duration(milliseconds: 800));
      
      final actualInfo = await _hotspotManager.getActualHotspotInfo();
      
      if (actualInfo != null) {
        print('✅ 获取到系统实际热点信息: SSID=${actualInfo.ssid}, 密码长度=${actualInfo.password.length}');
        
        // 更新实际热点信息状态
        hotspotProvider.setSystemGeneratedInfo(
          ssid: actualInfo.ssid,
          password: actualInfo.password,
        );
        
        // 显示实际热点信息给用户
        HotspotStateManager.showActualHotspotInfoDialog(
          context,
          actualSsid: actualInfo.ssid,
          actualPassword: actualInfo.password,
        );
      } else {
        print('⚠️ 未获取到系统实际热点信息');
        hotspotProvider.clearSystemGeneratedInfo();
      }
    } catch (e) {
      print('❌ 获取实际热点信息失败: $e');
      hotspotProvider.clearSystemGeneratedInfo();
    }
  }
}
