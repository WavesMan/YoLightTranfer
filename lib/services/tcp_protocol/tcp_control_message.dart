/// TCP 控制协议消息定义
/// 按照技术文档规范定义所有控制操作类型

import 'dart:convert';

/// TCP 控制协议操作类型
enum TcpControlOp {
  cancel,    // 取消任务
  progress,  // 传输进度报告
  ping,      // 心跳包
  pong,      // 心跳回应
  ack,       // 普通确认响应
  error,     // 异常通知
}

/// TCP 控制消息基类
class TcpControlMessage {
  final TcpControlOp op;
  final String transferId;
  final Map<String, dynamic>? extra;

  TcpControlMessage({
    required this.op,
    required this.transferId,
    this.extra,
  });

  /// 将消息转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'op': _opToString(op),
      'transferId': transferId,
      if (extra != null) 'extra': extra,
    };
  }

  /// 将JSON转换为控制消息
  static TcpControlMessage fromJson(Map<String, dynamic> json) {
    final op = _stringToOp(json['op'] as String?);
    final transferId = json['transferId'] as String? ?? '';
    final extra = json['extra'] as Map<String, dynamic>?;

    return TcpControlMessage(
      op: op,
      transferId: transferId,
      extra: extra,
    );
  }

  /// 将消息序列化为JSON字符串（带换行符）
  String toJsonString() {
    return '${jsonEncode(toJson())}\n';
  }

  /// 从JSON字符串解析控制消息
  static TcpControlMessage? fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 操作类型转字符串
  static String _opToString(TcpControlOp op) {
    switch (op) {
      case TcpControlOp.cancel:
        return 'CANCEL';
      case TcpControlOp.progress:
        return 'PROGRESS';
      case TcpControlOp.ping:
        return 'PING';
      case TcpControlOp.pong:
        return 'PONG';
      case TcpControlOp.ack:
        return 'ACK';
      case TcpControlOp.error:
        return 'ERROR';
    }
  }

  /// 字符串转操作类型
  static TcpControlOp _stringToOp(String? opString) {
    switch (opString?.toUpperCase()) {
      case 'CANCEL':
        return TcpControlOp.cancel;
      case 'PROGRESS':
        return TcpControlOp.progress;
      case 'PING':
        return TcpControlOp.ping;
      case 'PONG':
        return TcpControlOp.pong;
      case 'ACK':
        return TcpControlOp.ack;
      case 'ERROR':
        return TcpControlOp.error;
      default:
        return TcpControlOp.error; // 未知操作类型视为错误
    }
  }

  @override
  String toString() {
    return 'TcpControlMessage{op: $op, transferId: $transferId, extra: $extra}';
  }
}

/// 取消任务消息
class CancelMessage extends TcpControlMessage {
  CancelMessage({
    required String transferId,
    Map<String, dynamic>? extra,
  }) : super(
          op: TcpControlOp.cancel,
          transferId: transferId,
          extra: extra,
        );
}

/// 进度报告消息
class ProgressMessage extends TcpControlMessage {
  final int transferred;
  final int total;

  ProgressMessage({
    required String transferId,
    required this.transferred,
    required this.total,
    Map<String, dynamic>? extra,
  }) : super(
          op: TcpControlOp.progress,
          transferId: transferId,
          extra: {
            'transferred': transferred,
            'total': total,
            if (extra != null) ...extra,
          },
        );

  /// 从基类消息创建进度消息
  factory ProgressMessage.fromBase(TcpControlMessage base) {
    final extra = base.extra ?? {};
    return ProgressMessage(
      transferId: base.transferId,
      transferred: extra['transferred'] as int? ?? 0,
      total: extra['total'] as int? ?? 0,
      extra: extra,
    );
  }
}

/// 心跳消息
class PingMessage extends TcpControlMessage {
  PingMessage() : super(
          op: TcpControlOp.ping,
          transferId: 'ping',
        );
}

/// 心跳回应消息
class PongMessage extends TcpControlMessage {
  PongMessage() : super(
          op: TcpControlOp.pong,
          transferId: 'pong',
        );
}

/// 确认响应消息
class AckMessage extends TcpControlMessage {
  AckMessage({
    required String transferId,
    Map<String, dynamic>? extra,
  }) : super(
          op: TcpControlOp.ack,
          transferId: transferId,
          extra: extra,
        );
}

/// 错误通知消息
class ErrorMessage extends TcpControlMessage {
  final String errorMessage;

  ErrorMessage({
    required String transferId,
    required this.errorMessage,
    Map<String, dynamic>? extra,
  }) : super(
          op: TcpControlOp.error,
          transferId: transferId,
          extra: {
            'message': errorMessage,
            if (extra != null) ...extra,
          },
        );

  /// 从基类消息创建错误消息
  factory ErrorMessage.fromBase(TcpControlMessage base) {
    final extra = base.extra ?? {};
    return ErrorMessage(
      transferId: base.transferId,
      errorMessage: extra['message'] as String? ?? 'Unknown error',
      extra: extra,
    );
  }
}
