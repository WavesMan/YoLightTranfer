/// 文件传输状态枚举
enum TransferState {
  pending,      // 等待确认
  accepted,     // 已接受
  transferring, // 传输中
  verifying,    // 校验中
  completed,    // 已完成
  failed,       // 失败
  cancelled     // 已取消
}

/// 传输状态扩展方法
extension TransferStateExtension on TransferState {
  /// 获取状态文本描述
  String get text {
    switch (this) {
      case TransferState.pending:
        return '等待确认';
      case TransferState.accepted:
        return '已接受';
      case TransferState.transferring:
        return '传输中';
      case TransferState.verifying:
        return '校验中';
      case TransferState.completed:
        return '已完成';
      case TransferState.failed:
        return '失败';
      case TransferState.cancelled:
        return '已取消';
    }
  }

  /// 获取状态图标
  String get icon {
    switch (this) {
      case TransferState.pending:
        return '⏳';
      case TransferState.accepted:
        return '✅';
      case TransferState.transferring:
        return '🔄';
      case TransferState.verifying:
        return '🔍';
      case TransferState.completed:
        return '🎉';
      case TransferState.failed:
        return '❌';
      case TransferState.cancelled:
        return '🚫';
    }
  }

  /// 获取状态颜色（用于UI）
  String get color {
    switch (this) {
      case TransferState.pending:
        return 'grey';
      case TransferState.accepted:
        return 'blue';
      case TransferState.transferring:
        return 'orange';
      case TransferState.verifying:
        return 'purple';
      case TransferState.completed:
        return 'green';
      case TransferState.failed:
        return 'red';
      case TransferState.cancelled:
        return 'darkGrey';
    }
  }

  /// 判断是否为进行中状态
  bool get isInProgress {
    return this == TransferState.pending ||
           this == TransferState.accepted ||
           this == TransferState.transferring ||
           this == TransferState.verifying;
  }

  /// 判断是否为完成状态
  bool get isCompleted {
    return this == TransferState.completed ||
           this == TransferState.failed ||
           this == TransferState.cancelled;
  }
}

/// 网络连接质量枚举
enum ConnectionQuality {
  excellent, // 优秀
  good,      // 良好
  fair,      // 一般
  poor,      // 较差
  disconnected // 断开
}

/// 连接质量扩展方法
extension ConnectionQualityExtension on ConnectionQuality {
  /// 获取质量文本描述
  String get text {
    switch (this) {
      case ConnectionQuality.excellent:
        return '优秀';
      case ConnectionQuality.good:
        return '良好';
      case ConnectionQuality.fair:
        return '一般';
      case ConnectionQuality.poor:
        return '较差';
      case ConnectionQuality.disconnected:
        return '断开';
    }
  }

  /// 获取质量图标
  String get icon {
    switch (this) {
      case ConnectionQuality.excellent:
        return '🟢';
      case ConnectionQuality.good:
        return '🟡';
      case ConnectionQuality.fair:
        return '🟠';
      case ConnectionQuality.poor:
        return '🔴';
      case ConnectionQuality.disconnected:
        return '⚫';
    }
  }
}

/// 文件校验结果枚举
enum FileVerificationResult {
  pending,    // 等待校验
  success,    // 校验成功
  failed,     // 校验失败
  skipped     // 跳过校验
}

/// 文件校验结果扩展方法
extension FileVerificationResultExtension on FileVerificationResult {
  /// 获取结果文本描述
  String get text {
    switch (this) {
      case FileVerificationResult.pending:
        return '等待校验';
      case FileVerificationResult.success:
        return '校验成功';
      case FileVerificationResult.failed:
        return '校验失败';
      case FileVerificationResult.skipped:
        return '跳过校验';
    }
  }

  /// 获取结果图标
  String get icon {
    switch (this) {
      case FileVerificationResult.pending:
        return '⏳';
      case FileVerificationResult.success:
        return '✅';
      case FileVerificationResult.failed:
        return '❌';
      case FileVerificationResult.skipped:
        return '⏭️';
    }
  }
}
