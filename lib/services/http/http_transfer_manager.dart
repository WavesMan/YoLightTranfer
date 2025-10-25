import 'dart:async';

import 'package:yolighttransfer/models/discovered_device.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/services/http/http_transfer_client.dart';
import 'package:yolighttransfer/services/http/http_transfer_server.dart';
import 'package:yolighttransfer/services/http/http_protocol_handler.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';

/// HTTP 传输管理器
/// 统一管理 HTTP 文件传输的客户端和服务器
class HttpTransferManager {
  final TransferLogManager _logManager;
  final TransferTaskManager? _taskManager;

  HttpTransferServer? _server;
  HttpTransferClient? _client;

  // 传输回调
  void Function(String fileName, int uploadedBytes, int totalBytes)? onProgress;
  void Function(String message)? onLog;
  
  // 文件接收确认回调
  Future<bool> Function(String senderDeviceName, String fileName, int fileSize)? onReceiveConfirmation;

  HttpTransferManager({
    required TransferLogManager logManager,
    TransferTaskManager? taskManager,
  })  : _logManager = logManager,
        _taskManager = taskManager;

  /// 启动 HTTP 服务器（接收端）
  Future<bool> startServer({
    required int port,
    required String uploadDir,
    DiscoveredDevice? sourceDevice,
  }) async {
    try {
      _server = HttpTransferServer(
        port: port,
        uploadDir: uploadDir,
        logManager: _logManager,
        taskManager: _taskManager,
        sourceDevice: sourceDevice,
      );
      
      // 设置文件接收确认回调
      _server!.onReceiveConfirmation = onReceiveConfirmation;
      
      await _server!.start();
      _log('✅ HTTP 服务器启动成功，端口: $port');
      return true;
    } catch (e) {
      _log('❌ HTTP 服务器启动失败: $e');
      return false;
    }
  }

  /// 停止 HTTP 服务器
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.stop();
      _server = null;
      _log('✅ HTTP 服务器已停止');
    }
  }

  /// 初始化 HTTP 客户端（发送端）
  void initClient({
    required String serverIp,
    required int serverPort,
  }) {
    _client = HttpTransferClient(
      serverIp: serverIp,
      serverPort: serverPort,
      logManager: _logManager,
    );
    _client!.onProgress = (uploadedBytes, totalBytes) {
      onProgress?.call('', uploadedBytes, totalBytes);
    };
    _client!.onLog = _log;
    _log('✅ HTTP 客户端已初始化: $serverIp:$serverPort');
  }

  /// 上传文件到远程设备
  Future<bool> uploadFile({
    required String filePath,
    required String fileName,
    required DiscoveredDevice targetDevice,
  }) async {
    if (_client == null) {
      _log('❌ HTTP 客户端未初始化');
      return false;
    }

    try {
      _log('📤 开始上传文件: $fileName 到 ${targetDevice.name}');

      // 记录传输日志
      _logManager.addInfoLog(
        message: '开始上传文件: $fileName 到 ${targetDevice.name}',
        fileName: fileName,
        device: targetDevice,
      );

      // 执行上传
      final success = await _client!.uploadFile(
        filePath: filePath,
        fileName: fileName,
      );

      if (success) {
        _log('✅ 文件上传成功: $fileName');
        _logManager.addInfoLog(
          message: '文件上传成功: $fileName',
          fileName: fileName,
          device: targetDevice,
        );
      } else {
        _log('❌ 文件上传失败: $fileName');
        _logManager.addErrorLog(
          type: TransferLogType.send,
          fileName: fileName,
          error: '文件上传失败: $fileName',
          targetDevice: targetDevice,
        );
      }

      return success;
    } catch (e) {
      _log('❌ 上传异常: $e');
      _logManager.addErrorLog(
        type: TransferLogType.send,
        fileName: fileName,
        error: '上传异常: $e',
        targetDevice: targetDevice,
      );
      return false;
    }
  }

  /// 查询上传状态
  Future<Map<String, dynamic>?> queryUploadStatus({
    required String fileName,
  }) async {
    if (_client == null) {
      _log('❌ HTTP 客户端未初始化');
      return null;
    }

    try {
      final status = await _client!.queryStatus(fileName);
      if (status != null && HttpProtocolHandler.isValidStatusResponse(status)) {
        final progress = HttpProtocolHandler.getUploadProgress(status);
        _log('📊 上传状态: $fileName - ${progress.toStringAsFixed(2)}%');
        return status;
      }
      return null;
    } catch (e) {
      _log('❌ 查询状态失败: $e');
      return null;
    }
  }

  /// 获取服务器状态
  bool get isServerRunning => _server?.isRunning ?? false;

  /// 获取客户端状态
  bool get isClientInitialized => _client != null;

  /// 记录日志
  void _log(String message) {
    print(message);
    onLog?.call(message);
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopServer();
    _client = null;
  }
}
