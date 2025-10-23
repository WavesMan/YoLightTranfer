/// TCP协议基础类
/// 包含共享的_JsonLinePeer类和其他基础定义

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// JSON行协议封装器
class JsonLinePeer {
  final Socket socket;
  final StreamController<Map<String, dynamic>> _ctrl = StreamController();
  final StringBuffer _lineBuf = StringBuffer();
  late final StreamSubscription<List<int>> _sub;

  JsonLinePeer(Socket socket) : socket = socket {
    _sub = socket.listen(_onData, onError: _ctrl.addError, onDone: _ctrl.close);
  }

  Stream<Map<String, dynamic>> get frames => _ctrl.stream;

  void send(Map<String, dynamic> json) {
    final data = jsonEncode(json);
    socket.add(utf8.encode(data));
    socket.add([10]); // 换行符 \n 分隔一帧
  }

  void _onData(List<int> data) {
    final text = utf8.decode(data);
    for (final ch in text.split('')) {
      if (ch == '\n') {
        final line = _lineBuf.toString();
        _lineBuf.clear();
        if (line.trim().isEmpty) continue;
        try {
          final obj = jsonDecode(line);
          if (obj is Map<String, dynamic>) {
            _ctrl.add(obj);
          }
        } catch (_) {
          // 忽略格式错误的行
        }
      } else {
        _lineBuf.write(ch);
      }
    }
  }

  Future<void> dispose() async {
    await _sub.cancel();
    socket.destroy();
  }
}
