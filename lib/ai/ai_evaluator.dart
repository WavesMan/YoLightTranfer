import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// 轻量AI评估器（可选 TFLite）
/// - 若模型不可用，使用手写阈值回退
class AiEvaluator {
  dynamic _interpreter; // 动态类型，避免在无依赖平台报错
  bool _initialized = false;
  bool _loadTfliteTried = false;

  Future<void> init() async {
    if (_initialized || _loadTfliteTried) return;
    _loadTfliteTried = true;
    try {
      // 延迟加载 tflite_flutter，避免在不支持的平台崩溃
      // ignore: avoid_dynamic_calls
      final tflite = await _loadTfliteFlutter();
      if (tflite == null) {
        _initialized = true; // 标记为已初始化（走阈值分支）
        return;
      }
      final data = await rootBundle.load('assets/model/net_quality.tflite');
      // ignore: avoid_dynamic_calls
      _interpreter = tflite.Interpreter.fromBuffer(data.buffer);
      _initialized = true;
    } catch (_) {
      // 模型或依赖不可用，回退到手写阈值
      _interpreter = null;
      _initialized = true;
    }
  }

  /// 对输入特征进行评估
  EvaluatedResult evaluate(List<double> features) {
    if (!_initialized || _interpreter == null) {
      return _heuristic(features);
    }
    try {
      final input = Float32List.fromList(features);
      final output = Float32List(3);
      // ignore: avoid_dynamic_calls
      _interpreter.run(input.buffer, output.buffer);
      final probs = _softmax(output);
      final maxIdx = _argmax(probs);
      final cls = _mapIdxToClass(maxIdx);
      final conf = probs[maxIdx];
      if (conf < 0.6) {
        // 置信度过低，回退到阈值
        return _heuristic(features);
      }
      return EvaluatedResult(
        label: cls,
        confidence: conf,
      );
    } catch (_) {
      return _heuristic(features);
    }
  }

  Future<dynamic> _loadTfliteFlutter() async {
    try {
      // 动态导入包，避免构建期依赖问题
      // 运行时反射式加载不可行，这里直接返回 null 以便在未集成依赖时安全回退
      // 实际工程启用 tflite_flutter 依赖后，此处可直接 `import 'package:tflite_flutter/tflite_flutter.dart';`
      return null;
    } catch (_) {
      return null;
    }
  }

  List<double> _softmax(Float32List logits) {
    final m = logits.reduce(max);
    final exps = List<double>.generate(logits.length, (i) => mathExp(logits[i] - m));
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  int _argmax(List<double> arr) {
    var idx = 0;
    var best = arr[0];
    for (int i = 1; i < arr.length; i++) {
      if (arr[i] > best) { best = arr[i]; idx = i; }
    }
    return idx;
  }

  String _mapIdxToClass(int i) {
    switch (i) {
      case 0: return 'good';
      case 1: return 'fair';
      case 2: return 'weak';
      default: return 'fair';
    }
  }

  /// 手写阈值回退
  EvaluatedResult _heuristic(List<double> features) {
    // features: [bandwidth, avg_delay, loss_rate, peer_cnt, platform_one_hot..., signal(optional)]
    final bandwidth = features[0];
    final avgDelay = features[1];
    final loss = features[2];

    String label;
    if (bandwidth >= 10 && avgDelay <= 60 && loss <= 2) {
      label = 'good';
    } else if (bandwidth >= 2 && avgDelay <= 120 && loss <= 5) {
      label = 'fair';
    } else {
      label = 'weak';
    }
    final confidence = 0.7; // 经验值
    return EvaluatedResult(label: label, confidence: confidence);
  }
}

class EvaluatedResult {
  final String label; // good|fair|weak
  final double confidence; // 0~1
  const EvaluatedResult({required this.label, required this.confidence});
}

// 避免引入 dart:math 的 e 的冲突，手写指数
double mathExp(double x) => MathE.powE(x);

class MathE {
  static double powE(double x) => exp(x);
}
