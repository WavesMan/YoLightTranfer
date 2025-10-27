import 'package:flutter/material.dart';
import 'package:yolighttransfer/widgets/file_receive_dialog.dart';
import 'package:yolighttransfer/services/notification/notification_service.dart';

/// 全局弹窗管理器
/// 负责管理文件接收确认弹窗的全局显示
class GlobalDialogManager {
  static final GlobalDialogManager _instance = GlobalDialogManager._internal();
  factory GlobalDialogManager() => _instance;
  GlobalDialogManager._internal();

  // 全局导航键，用于在任何地方显示弹窗
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // 传输请求队列
  final Map<String, _TransferRequest> _pendingRequests = {};

  // 传输超时时间（秒）
  static const int _transferTimeoutSeconds = 60;

  /// 获取全局导航键
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// 显示文件接收确认弹窗
  /// 如果应用在前台，直接显示弹窗
  /// 如果应用在后台，创建系统通知
  Future<bool> showFileReceiveDialog({
    required String requestId,
    required String senderDeviceName,
    required String fileName,
    required int fileSize,
  }) async {
    // 检查是否已有相同请求
    if (_pendingRequests.containsKey(requestId)) {
      return false;
    }

    final request = _TransferRequest(
      requestId: requestId,
      senderDeviceName: senderDeviceName,
      fileName: fileName,
      fileSize: fileSize,
      timestamp: DateTime.now(),
    );

    _pendingRequests[requestId] = request;

    // 设置超时定时器
    _setupTimeoutTimer(requestId);

    // 尝试显示弹窗
    return await _showDialog(request);
  }

  /// 设置传输超时定时器
  void _setupTimeoutTimer(String requestId) {
    Future.delayed(const Duration(seconds: _transferTimeoutSeconds), () {
      if (_pendingRequests.containsKey(requestId)) {
        // 超时，自动拒绝
        _pendingRequests.remove(requestId);
        print('传输请求 $requestId 已超时，自动拒绝');
      }
    });
  }

  /// 显示弹窗
  Future<bool> _showDialog(_TransferRequest request) async {
    try {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        print('无法获取导航状态，应用可能在后台，显示系统通知');
        // 显示系统通知
        await _showNotification(request);
        return false;
      }

      final result = await showDialog<bool>(
        context: navigator.context,
        builder: (context) => FileReceiveDialog(
          senderDeviceName: request.senderDeviceName,
          fileName: request.fileName,
          fileSize: request.fileSize,
          onAccept: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
          onDismiss: () => Navigator.of(context).pop(false),
        ),
      );

      // 清理请求
      _pendingRequests.remove(request.requestId);

      return result ?? false;
    } catch (e) {
      print('显示弹窗失败: $e');
      _pendingRequests.remove(request.requestId);
      return false;
    }
  }

  /// 显示系统通知
  Future<void> _showNotification(_TransferRequest request) async {
    try {
      await NotificationService().showFileTransferNotification(
        senderDeviceName: request.senderDeviceName,
        fileName: request.fileName,
        fileSize: request.fileSize,
        requestId: request.requestId,
      );
      print('已显示系统通知: ${request.fileName}');
    } catch (e) {
      print('显示系统通知失败: $e');
    }
  }

  /// 检查是否有待处理的传输请求
  bool hasPendingRequests() {
    return _pendingRequests.isNotEmpty;
  }

  /// 获取待处理请求数量
  int getPendingRequestCount() {
    return _pendingRequests.length;
  }

  /// 清理所有待处理请求
  void clearAllRequests() {
    _pendingRequests.clear();
  }
}

/// 传输请求数据类
class _TransferRequest {
  final String requestId;
  final String senderDeviceName;
  final String fileName;
  final int fileSize;
  final DateTime timestamp;

  _TransferRequest({
    required this.requestId,
    required this.senderDeviceName,
    required this.fileName,
    required this.fileSize,
    required this.timestamp,
  });
}
