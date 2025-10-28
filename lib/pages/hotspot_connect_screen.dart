// 热点连接页面 - 重构版本
// 使用模块化组件架构

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yolighttransfer/services/hotspot/hotspot_manager.dart';
import 'package:yolighttransfer/pages/hotspot/connect/components/platform_info_card.dart';
import 'package:yolighttransfer/pages/hotspot/connect/components/connection_status_card.dart';
import 'package:yolighttransfer/pages/hotspot/connect/components/input_form.dart';
import 'package:yolighttransfer/pages/hotspot/connect/components/scanner_view.dart';
import 'package:yolighttransfer/pages/hotspot/connect/components/action_buttons.dart';
import 'package:yolighttransfer/pages/hotspot/connect/utils/qr_code_parser.dart';
import 'package:yolighttransfer/pages/hotspot/connect/utils/connection_manager.dart';

class HotspotConnectScreen extends StatefulWidget {
  const HotspotConnectScreen({super.key});

  @override
  State<HotspotConnectScreen> createState() => _HotspotConnectScreenState();
}

class _HotspotConnectScreenState extends State<HotspotConnectScreen> {
  final HotspotManager _hotspotManager = HotspotManagerFactory.create();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  late ConnectionManager _connectionManager;
  
  bool _isConnecting = false;
  bool _showScanner = false;
  bool _isConnected = false;
  String _connectedSsid = '';
  double _signalStrength = 0.0;
  MobileScannerController? _scannerController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    print('=== HotspotConnectScreen初始化 ===');
    print('平台: ${Platform.operatingSystem}');
    
    // 初始化连接管理器
    _connectionManager = ConnectionManager(
      hotspotManager: _hotspotManager,
      showSuccess: _showSuccess,
      showError: _showError,
    );
    
    // 只在支持的平台上初始化扫描器
    if (Platform.isAndroid || Platform.isIOS) {
      print('✅ 初始化移动扫描器');
      try {
        _scannerController = MobileScannerController();
        print('✅ 扫描器控制器创建成功');
      } catch (e, stack) {
        print('❌ 扫描器控制器创建失败: $e');
        print('堆栈: $stack');
      }
    } else {
      print('⚠️ 当前平台不支持扫码功能，跳过扫描器初始化');
    }
    
    // 启动连接状态检查
    _startStatusMonitoring();
  }

  @override
  void dispose() {
    // 停止状态监控定时器
    _statusTimer?.cancel();
    
    // 安全地停止和释放扫描器
    if (_scannerController != null) {
      try {
        _scannerController?.stop();
      } catch (e) {
        // 忽略插件缺失错误
        print('扫描器停止失败: $e');
      }
      _scannerController?.dispose();
    }
    super.dispose();
  }

  /// 启动连接状态监控
  void _startStatusMonitoring() {
    print('启动连接状态监控...');
    
    // 立即检查一次状态
    _checkConnectionStatus();
    
    // 每5秒检查一次连接状态
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectionStatus();
    });
  }

  /// 检查连接状态
  Future<void> _checkConnectionStatus() async {
    final status = await _connectionManager.checkConnectionStatus();
    
    if (status != null && mounted) {
      setState(() {
        _isConnected = status.isConnected;
        _connectedSsid = status.ssid;
        _signalStrength = status.signalStrength;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('连接热点'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (Platform.isAndroid && !_showScanner)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _toggleScanner,
              tooltip: '扫描QR码',
            ),
        ],
      ),
      body: _showScanner ? _buildScannerView() : _buildInputView(),
    );
  }

  /// 扫码视图
  Widget _buildScannerView() {
    return ScannerView(
      scannerController: _scannerController,
      showScanner: _showScanner,
      onBarcodeDetected: _onBarcodeDetected,
      onToggleScanner: _toggleScanner,
      onToggleFlash: _toggleFlash,
    );
  }

  /// 输入视图
  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 平台信息卡片
          const PlatformInfoCard(),
          const SizedBox(height: 24),
          
          // 连接状态显示
          ConnectionStatusCard(
            isConnected: _isConnected,
            connectedSsid: _connectedSsid,
            signalStrength: _signalStrength,
          ),
          
          // 输入表单
          InputForm(
            ssidController: _ssidController,
            passwordController: _passwordController,
            isConnecting: _isConnecting,
            isConnected: _isConnected,
            onConnect: _connectToHotspot,
          ),
          
          // 扫码操作按钮
          ActionButtons(
            showScanner: _showScanner,
            onToggleScanner: _toggleScanner,
          ),
        ],
      ),
    );
  }

  /// 切换扫码视图
  void _toggleScanner() {
    setState(() {
      _showScanner = !_showScanner;
    });
  }

  /// 切换闪光灯
  void _toggleFlash() {
    if (_scannerController != null) {
      _scannerController!.toggleTorch();
    }
  }

  /// 扫码检测回调
  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    print('=== 扫码检测回调 ===');
    print('检测到条码数量: ${barcodes.length}');
    
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      print('条码类型: ${barcode.type}');
      print('rawValue: ${barcode.rawValue}');
      print('displayValue: ${barcode.displayValue}');
      
      // 优先使用rawValue，如果为空则使用displayValue
      final qrData = barcode.rawValue ?? barcode.displayValue;
      print('最终QR码数据: $qrData');
      
      if (qrData != null && qrData.isNotEmpty) {
        _parseQrCode(qrData);
      } else {
        print('❌ QR码数据为空');
        _showError('QR码数据为空，请重新扫描');
      }
    }
  }

  /// 解析QR码数据
  void _parseQrCode(String qrData) {
    print('=== 开始解析QR码 ===');
    print('原始QR码数据: $qrData');
    
    final result = QRCodeParser.parseWiFiQRCode(qrData);
    
    print('解析结果:');
    print('  success: ${result.success}');
    print('  ssid: ${result.ssid}');
    print('  password: ${result.password}');
    print('  encryptionType: ${result.encryptionType}');
    print('  error: ${result.error}');
    
    if (result.success) {
      // 自动填充并连接
      setState(() {
        _ssidController.text = result.ssid!;
        _passwordController.text = result.password!;
        _showScanner = false;
      });
      
      print('✅ QR码解析成功');
      print('  SSID: ${result.ssid}');
      print('  密码长度: ${result.password!.length}');
      print('  准备连接热点');
      
      // 延迟连接，让用户看到填充结果
      Future.delayed(const Duration(milliseconds: 500), () {
        _connectToHotspot();
      });
    } else {
      print('❌ QR码解析失败: ${result.error}');
      _showError(result.error!);
    }
  }

  /// 连接到热点
  Future<void> _connectToHotspot() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();
    
    final success = await _connectionManager.connectToHotspot(
      ssid: ssid,
      password: password,
      onConnecting: () => setState(() => _isConnecting = true),
      onConnected: () => setState(() => _isConnecting = false),
    );
    
    if (success) {
      // 连接成功后检查状态
      await _checkConnectionStatus();
    } else {
      setState(() => _isConnecting = false);
    }
  }


  /// 显示成功消息
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 显示错误消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
