import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/models/discovered_device.dart';

/// 传输日志管理器：负责记录、存储和查询文件传输日志
class TransferLogManager extends ChangeNotifier {
  static const String _logFileName = 'transfer_logs.json';
  static const int _maxLogs = 1000; // 最大日志数量
  
  final List<TransferLog> _logs = [];
  late String _logFilePath;
  bool _initialized = false;

  List<TransferLog> get logs => List.unmodifiable(_logs);
  List<TransferLog> get sendLogs => _logs.where((log) => log.type == TransferLogType.send).toList();
  List<TransferLog> get receiveLogs => _logs.where((log) => log.type == TransferLogType.receive).toList();
  List<TransferLog> get errorLogs => _logs.where((log) => log.type == TransferLogType.error).toList();
  List<TransferLog> get hashLogs => _logs.where((log) => log.type == TransferLogType.hash).toList();
  List<TransferLog> get networkLogs => _logs.where((log) => log.type == TransferLogType.network).toList();
  List<TransferLog> get tcpLogs => _logs.where((log) => log.type == TransferLogType.tcp).toList();

  /// 初始化日志管理器
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFilePath = '${directory.path}/$_logFileName';
      
      // 加载现有日志
      await _loadLogs();
      
      _initialized = true;
      print('传输日志管理器初始化完成，日志文件: $_logFilePath');
    } catch (e) {
      print('传输日志管理器初始化失败: $e');
    }
  }

  /// 添加发送文件开始日志
  void addSendStartLog({
    required String fileName,
    required int fileSize,
    required String filePath,
    required DiscoveredDevice targetDevice,
  }) {
    final log = TransferLog.sendStart(
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      targetDevice: targetDevice,
    );
    _addLog(log);
  }

  /// 添加接收文件开始日志
  void addReceiveStartLog({
    required String fileName,
    required int fileSize,
    required String savePath,
    required DiscoveredDevice sourceDevice,
  }) {
    final log = TransferLog.receiveStart(
      fileName: fileName,
      fileSize: fileSize,
      savePath: savePath,
      sourceDevice: sourceDevice,
    );
    _addLog(log);
  }

  /// 添加传输进度日志
  void addProgressLog({
    required String logId,
    required TransferLogType type,
    required String fileName,
    required int progress,
    String? transferSpeed,
    String? estimatedTime,
  }) {
    final log = TransferLog.progress(
      id: logId,
      type: type,
      fileName: fileName,
      progress: progress,
      transferSpeed: transferSpeed,
      estimatedTime: estimatedTime,
    );
    _addLog(log);
  }

  /// 更新传输进度日志（不添加新日志，只更新现有日志）
  void updateProgressLog({
    required String fileName,
    required int progress,
    String? transferSpeed,
    String? estimatedTime,
  }) {
    // 查找该文件的进度日志
    final logIndex = _logs.indexWhere((log) => 
      log.fileName == fileName && 
      (log.type == TransferLogType.send || log.type == TransferLogType.receive) &&
      log.progress != null
    );
    
    if (logIndex != -1) {
      // 更新现有日志
      final oldLog = _logs[logIndex];
      final updatedLog = TransferLog.progress(
        id: oldLog.id,
        type: oldLog.type,
        fileName: fileName,
        progress: progress,
        transferSpeed: transferSpeed,
        estimatedTime: estimatedTime,
      );
      _logs[logIndex] = updatedLog;
      
      // 保存到文件并通知监听器
      _saveLogs();
      notifyListeners();
      
      // 打印更新信息到控制台
      print('📊 更新进度: $fileName - $progress% ${transferSpeed != null ? '($transferSpeed)' : ''}');
    }
  }

  /// 添加传输完成日志
  void addCompleteLog({
    required String logId,
    required TransferLogType type,
    required String fileName,
    required int fileSize,
    String? filePath,
    String? savePath,
    DiscoveredDevice? targetDevice,
    DiscoveredDevice? sourceDevice,
  }) {
    final log = TransferLog.complete(
      id: logId,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      savePath: savePath,
      targetDevice: targetDevice,
      sourceDevice: sourceDevice,
    );
    _addLog(log);
  }

  /// 添加传输错误日志
  void addErrorLog({
    required TransferLogType type,
    required String fileName,
    required String error,
    DiscoveredDevice? targetDevice,
    DiscoveredDevice? sourceDevice,
  }) {
    final log = TransferLog.error(
      type: type,
      fileName: fileName,
      error: error,
      targetDevice: targetDevice,
      sourceDevice: sourceDevice,
    );
    _addLog(log);
  }

  /// 添加信息日志
  void addInfoLog({
    required String message,
    String? fileName,
    DiscoveredDevice? device,
  }) {
    final log = TransferLog.info(
      message: message,
      fileName: fileName,
      device: device,
    );
    _addLog(log);
  }

  /// 添加TCP连接流程日志
  void addTcpLog({
    required String message,
    String? fileName,
    String? clientAddress,
    int? fileSize,
    int? bytesTransferred,
    int? progress,
    String? transferSpeed,
  }) {
    final log = TransferLog.tcp(
      message: message,
      fileName: fileName,
      clientAddress: clientAddress,
      fileSize: fileSize,
      bytesTransferred: bytesTransferred,
      progress: progress,
      transferSpeed: transferSpeed,
    );
    _addLog(log);
  }

  /// 添加哈希校验日志
  void addHashLog({
    required String message,
    required String fileName,
    String? expectedHash,
    String? actualHash,
    bool? hashValid,
    int? progress,
  }) {
    final log = TransferLog.hash(
      message: message,
      fileName: fileName,
      expectedHash: expectedHash,
      actualHash: actualHash,
      hashValid: hashValid,
      progress: progress,
    );
    _addLog(log);
  }

  /// 添加网络状态日志
  void addNetworkLog({
    required String message,
    String? clientAddress,
    String? networkType,
    String? connectionState,
    int? latency,
    int? packetLoss,
  }) {
    final log = TransferLog.network(
      message: message,
      clientAddress: clientAddress,
      networkType: networkType,
      connectionState: connectionState,
      latency: latency,
      packetLoss: packetLoss,
    );
    _addLog(log);
  }

  /// 通用添加日志方法
  void addLog(TransferLog log) {
    _addLog(log);
  }

  /// 添加日志到列表并保存
  void _addLog(TransferLog log) {
    _logs.insert(0, log); // 新日志插入到开头
    
    // 限制日志数量
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }
    
    // 保存到文件
    _saveLogs();
    
    // 通知监听器
    notifyListeners();
    
    // 打印日志到控制台
    print('=== 传输日志 ===');
    print('类型: ${log.typeText}');
    print('文件: ${log.fileName}');
    print('消息: ${log.message}');
    print('时间: ${log.timestamp}');
    if (log.progress != null) {
      print('进度: ${log.progress}%');
    }
    if (log.error != null) {
      print('错误: ${log.error}');
    }
    print('================');
  }

  /// 根据文件名查找相关日志
  List<TransferLog> findLogsByFileName(String fileName) {
    return _logs.where((log) => log.fileName == fileName).toList();
  }

  /// 根据设备查找相关日志
  List<TransferLog> findLogsByDevice(DiscoveredDevice device) {
    return _logs.where((log) => 
      (log.targetDevice?.id == device.id) || 
      (log.sourceDevice?.id == device.id)
    ).toList();
  }

  /// 根据类型查找日志
  List<TransferLog> findLogsByType(TransferLogType type) {
    return _logs.where((log) => log.type == type).toList();
  }

  /// 根据时间范围查找日志
  List<TransferLog> findLogsByTimeRange(DateTime start, DateTime end) {
    return _logs.where((log) => 
      log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }

  /// 搜索日志
  List<TransferLog> searchLogs(String keyword) {
    return _logs.where((log) => 
      log.fileName.toLowerCase().contains(keyword.toLowerCase()) ||
      log.message.toLowerCase().contains(keyword.toLowerCase()) ||
      log.deviceName.toLowerCase().contains(keyword.toLowerCase()) ||
      (log.error?.toLowerCase().contains(keyword.toLowerCase()) ?? false)
    ).toList();
  }

  /// 清空所有日志
  Future<void> clearAllLogs() async {
    _logs.clear();
    await _saveLogs();
    notifyListeners();
  }

  /// 导出日志到指定路径
  Future<String> exportLogsToPath(String savePath) async {
    final exportData = {
      'exportTime': DateTime.now().millisecondsSinceEpoch,
      'totalLogs': _logs.length,
      'logs': _logs.map((log) => log.toMap()).toList(),
    };
    
    final file = File(savePath);
    await file.writeAsString(jsonEncode(exportData));
    
    return savePath;
  }

  /// 获取默认导出文件名
  String getDefaultExportFileName() {
    final now = DateTime.now();
    final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'transfer_logs_$formattedDate.json';
  }

  /// 加载日志文件
  Future<void> _loadLogs() async {
    try {
      final file = File(_logFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        
        if (data is List) {
          _logs.clear();
          for (final item in data) {
            try {
              final log = TransferLog.fromMap(Map<String, dynamic>.from(item));
              _logs.add(log);
            } catch (e) {
              print('解析日志条目失败: $e');
            }
          }
          print('加载了 ${_logs.length} 条传输日志');
        }
      }
    } catch (e) {
      print('加载传输日志失败: $e');
    }
  }

  /// 保存日志到文件
  Future<void> _saveLogs() async {
    try {
      final data = _logs.map((log) => log.toMap()).toList();
      final file = File(_logFilePath);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('保存传输日志失败: $e');
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    
    final recentLogs = _logs.where((log) => log.timestamp.isAfter(weekAgo)).toList();
    final sendCount = recentLogs.where((log) => log.type == TransferLogType.send).length;
    final receiveCount = recentLogs.where((log) => log.type == TransferLogType.receive).length;
    final errorCount = recentLogs.where((log) => log.type == TransferLogType.error).length;
    final successCount = recentLogs.where((log) => log.success).length;
    
    return {
      'totalLogs': _logs.length,
      'recentLogs': recentLogs.length,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'errorCount': errorCount,
      'successCount': successCount,
      'successRate': recentLogs.isNotEmpty ? (successCount / recentLogs.length * 100).toStringAsFixed(1) : '0.0',
    };
  }
}
