import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yolighttransfer/models/transfer_state.dart';
import 'package:yolighttransfer/services/file/smart_hash_service.dart';

/// 传输恢复信息
class TransferRecoveryInfo {
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileHash;
  final int bytesTransferred;
  final DateTime startTime;
  final DateTime? lastUpdateTime;
  final TransferState lastState;
  final String? targetDeviceId;
  final String? sourceDeviceId;
  final Map<String, dynamic> additionalInfo;

  TransferRecoveryInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileHash,
    required this.bytesTransferred,
    required this.startTime,
    this.lastUpdateTime,
    required this.lastState,
    this.targetDeviceId,
    this.sourceDeviceId,
    this.additionalInfo = const {},
  });

  /// 转换为Map用于存储
  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'fileHash': fileHash,
      'bytesTransferred': bytesTransferred,
      'startTime': startTime.millisecondsSinceEpoch,
      'lastUpdateTime': lastUpdateTime?.millisecondsSinceEpoch,
      'lastState': lastState.toString(),
      'targetDeviceId': targetDeviceId,
      'sourceDeviceId': sourceDeviceId,
      'additionalInfo': additionalInfo,
    };
  }

  /// 从Map创建恢复信息
  factory TransferRecoveryInfo.fromMap(Map<String, dynamic> map) {
    return TransferRecoveryInfo(
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      fileHash: map['fileHash'] ?? '',
      bytesTransferred: map['bytesTransferred'] ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      lastUpdateTime: map['lastUpdateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdateTime'])
          : null,
      lastState: TransferState.values.firstWhere(
        (e) => e.toString() == map['lastState'],
        orElse: () => TransferState.pending,
      ),
      targetDeviceId: map['targetDeviceId'],
      sourceDeviceId: map['sourceDeviceId'],
      additionalInfo: Map<String, dynamic>.from(map['additionalInfo'] ?? {}),
    );
  }

  /// 获取传输进度百分比
  double get progressPercentage {
    if (fileSize == 0) return 0;
    return (bytesTransferred / fileSize * 100).clamp(0, 100).toDouble();
  }

  /// 获取剩余字节数
  int get remainingBytes {
    return fileSize - bytesTransferred;
  }

  /// 判断是否可以恢复传输
  bool get canResume {
    return bytesTransferred > 0 && 
           bytesTransferred < fileSize &&
           lastState.isInProgress;
  }

  /// 获取传输持续时间
  Duration get transferDuration {
    final endTime = lastUpdateTime ?? DateTime.now();
    return endTime.difference(startTime);
  }
}

/// 传输恢复服务：负责断点续传和错误恢复
class TransferRecoveryService {
  static const String _recoveryFileName = 'transfer_recovery.json';
  static const int _maxRecoveryEntries = 50;
  static const Duration _cleanupInterval = Duration(hours: 24);

  late String _recoveryFilePath;
  final Map<String, TransferRecoveryInfo> _recoveryInfo = {};
  bool _initialized = false;
  Timer? _cleanupTimer;

  /// 初始化恢复服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _recoveryFilePath = '${directory.path}/$_recoveryFileName';
      
      // 加载现有的恢复信息
      await _loadRecoveryInfo();
      
      // 启动清理定时器
      _startCleanupTimer();
      
      _initialized = true;
      print('传输恢复服务初始化完成，恢复文件: $_recoveryFilePath');
    } catch (e) {
      print('传输恢复服务初始化失败: $e');
    }
  }

  /// 保存传输恢复信息
  Future<void> saveRecoveryInfo(TransferRecoveryInfo info) async {
    if (!_initialized) await initialize();

    try {
      _recoveryInfo[info.fileName] = info;
      await _saveRecoveryInfo();
      
      print('保存传输恢复信息: ${info.fileName} (${info.bytesTransferred}/${info.fileSize} bytes)');
    } catch (e) {
      print('保存传输恢复信息失败: $e');
    }
  }

  /// 获取传输恢复信息
  TransferRecoveryInfo? getRecoveryInfo(String fileName) {
    return _recoveryInfo[fileName];
  }

  /// 获取所有可恢复的传输
  List<TransferRecoveryInfo> getResumableTransfers() {
    return _recoveryInfo.values
        .where((info) => info.canResume)
        .toList();
  }

  /// 删除传输恢复信息
  Future<void> removeRecoveryInfo(String fileName) async {
    if (!_initialized) await initialize();

    try {
      _recoveryInfo.remove(fileName);
      await _saveRecoveryInfo();
      
      print('删除传输恢复信息: $fileName');
    } catch (e) {
      print('删除传输恢复信息失败: $e');
    }
  }

  /// 清除所有恢复信息
  Future<void> clearAllRecoveryInfo() async {
    if (!_initialized) await initialize();

    try {
      _recoveryInfo.clear();
      await _saveRecoveryInfo();
      
      print('清除所有传输恢复信息');
    } catch (e) {
      print('清除所有传输恢复信息失败: $e');
    }
  }

  /// 验证文件完整性
  Future<bool> verifyFileIntegrity(TransferRecoveryInfo info) async {
    try {
      // 检查文件是否存在
      final file = File(info.filePath);
      if (!await file.exists()) {
        print('文件不存在: ${info.filePath}');
        return false;
      }

      // 检查文件大小
      final actualFileSize = await file.length();
      if (actualFileSize != info.bytesTransferred) {
        print('文件大小不匹配: 预期 ${info.bytesTransferred}, 实际 $actualFileSize');
        return false;
      }

      // 验证文件哈希（如果文件较大，可以跳过或使用增量验证）
      if (info.bytesTransferred > 0 && info.bytesTransferred < 10 * 1024 * 1024) {
        final actualHash = await SmartHashService.calculateFileHash(info.filePath);
        if (actualHash != info.fileHash) {
          print('文件哈希不匹配: 预期 ${info.fileHash}, 实际 $actualHash');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('验证文件完整性失败: $e');
      return false;
    }
  }

  /// 创建恢复信息
  TransferRecoveryInfo createRecoveryInfo({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String fileHash,
    required int bytesTransferred,
    required TransferState lastState,
    String? targetDeviceId,
    String? sourceDeviceId,
    Map<String, dynamic>? additionalInfo,
  }) {
    return TransferRecoveryInfo(
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      fileHash: fileHash,
      bytesTransferred: bytesTransferred,
      startTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
      lastState: lastState,
      targetDeviceId: targetDeviceId,
      sourceDeviceId: sourceDeviceId,
      additionalInfo: additionalInfo ?? {},
    );
  }

  /// 更新传输进度
  Future<void> updateTransferProgress({
    required String fileName,
    required int bytesTransferred,
    required TransferState state,
  }) async {
    if (!_initialized) await initialize();

    final info = _recoveryInfo[fileName];
    if (info != null) {
      final updatedInfo = TransferRecoveryInfo(
        fileName: info.fileName,
        filePath: info.filePath,
        fileSize: info.fileSize,
        fileHash: info.fileHash,
        bytesTransferred: bytesTransferred,
        startTime: info.startTime,
        lastUpdateTime: DateTime.now(),
        lastState: state,
        targetDeviceId: info.targetDeviceId,
        sourceDeviceId: info.sourceDeviceId,
        additionalInfo: info.additionalInfo,
      );

      await saveRecoveryInfo(updatedInfo);
    }
  }

  /// 获取传输统计信息
  Map<String, dynamic> getStatistics() {
    final totalTransfers = _recoveryInfo.length;
    final resumableTransfers = getResumableTransfers().length;
    final completedTransfers = _recoveryInfo.values
        .where((info) => info.lastState == TransferState.completed)
        .length;
    final failedTransfers = _recoveryInfo.values
        .where((info) => info.lastState == TransferState.failed)
        .length;

    int totalBytes = 0;
    int transferredBytes = 0;
    for (final info in _recoveryInfo.values) {
      totalBytes += info.fileSize;
      transferredBytes += info.bytesTransferred;
    }

    return {
      'totalTransfers': totalTransfers,
      'resumableTransfers': resumableTransfers,
      'completedTransfers': completedTransfers,
      'failedTransfers': failedTransfers,
      'totalBytes': totalBytes,
      'transferredBytes': transferredBytes,
      'recoveryRate': totalTransfers > 0 ? (resumableTransfers / totalTransfers * 100).toStringAsFixed(1) : '0.0',
    };
  }

  /// 清理过期的恢复信息
  Future<void> cleanupExpiredRecoveryInfo() async {
    if (!_initialized) await initialize();

    try {
      final now = DateTime.now();
      final expiredEntries = _recoveryInfo.entries
          .where((entry) {
            final info = entry.value;
            final age = now.difference(info.lastUpdateTime ?? info.startTime);
            return age > _cleanupInterval || 
                   info.lastState.isCompleted;
          })
          .toList();

      for (final entry in expiredEntries) {
        _recoveryInfo.remove(entry.key);
      }

      if (expiredEntries.isNotEmpty) {
        await _saveRecoveryInfo();
        print('清理了 ${expiredEntries.length} 个过期的恢复信息');
      }
    } catch (e) {
      print('清理过期恢复信息失败: $e');
    }
  }

  // 私有方法

  /// 加载恢复信息
  Future<void> _loadRecoveryInfo() async {
    try {
      final file = File(_recoveryFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        
        if (data is Map) {
          _recoveryInfo.clear();
          for (final entry in data.entries) {
            try {
              final info = TransferRecoveryInfo.fromMap(Map<String, dynamic>.from(entry.value));
              _recoveryInfo[entry.key] = info;
            } catch (e) {
              print('解析恢复信息条目失败: $e');
            }
          }
          print('加载了 ${_recoveryInfo.length} 个传输恢复信息');
        }
      }
    } catch (e) {
      print('加载传输恢复信息失败: $e');
    }
  }

  /// 保存恢复信息
  Future<void> _saveRecoveryInfo() async {
    try {
      final data = <String, dynamic>{};
      for (final entry in _recoveryInfo.entries) {
        data[entry.key] = entry.value.toMap();
      }

      final file = File(_recoveryFilePath);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('保存传输恢复信息失败: $e');
    }
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      cleanupExpiredRecoveryInfo();
    });
  }

  /// 停止清理定时器
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}
