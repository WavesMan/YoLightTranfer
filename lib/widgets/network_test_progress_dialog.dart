import 'package:flutter/material.dart';
import 'package:yolighttransfer/services/network_testing/gateway_bandwidth_tester.dart';

/// 网络测速进度弹窗
class NetworkTestProgressDialog extends StatefulWidget {
  final Stream<BandwidthProgress> progressStream;
  final String gatewayIp;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const NetworkTestProgressDialog({
    Key? key,
    required this.progressStream,
    required this.gatewayIp,
    this.onComplete,
    this.onCancel,
  }) : super(key: key);

  @override
  _NetworkTestProgressDialogState createState() => _NetworkTestProgressDialogState();
}

class _NetworkTestProgressDialogState extends State<NetworkTestProgressDialog> {
  BandwidthProgress? _currentProgress;
  bool _isTesting = true;

  @override
  void initState() {
    super.initState();
    _listenToProgress();
  }

  void _listenToProgress() {
    widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
        });

        // 测试完成
        if (progress.phase == Phase.finished) {
          _isTesting = false;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && widget.onComplete != null) {
              widget.onComplete!();
            }
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    });
  }

  String _getPhaseText(Phase phase) {
    switch (phase) {
      case Phase.fastJudge:
        return '快速检测中...';
      case Phase.extended:
        return '扩展测试中...';
      case Phase.finished:
        return '测试完成';
    }
  }

  String _getPhaseDescription(Phase phase) {
    switch (phase) {
      case Phase.fastJudge:
        return '正在快速检测网络质量（2秒内完成）';
      case Phase.extended:
        return '网络质量较好，正在精确测量（最多10秒）';
      case Phase.finished:
        return '网络测速已完成';
    }
  }

  Color _getPhaseColor(Phase phase) {
    switch (phase) {
      case Phase.fastJudge:
        return Colors.orange;
      case Phase.extended:
        return Colors.blue;
      case Phase.finished:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.speed,
            color: _currentProgress?.phase == Phase.finished 
                ? Colors.green 
                : Colors.blue,
          ),
          const SizedBox(width: 12),
          Text(
            '网关网络测速',
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网关信息
            Text(
              '网关地址: ${widget.gatewayIp}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            // 测速进度
            if (_currentProgress != null) ...[
              // 阶段指示器
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getPhaseColor(_currentProgress!.phase),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPhaseText(_currentProgress!.phase),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 阶段描述
              Text(
                _getPhaseDescription(_currentProgress!.phase),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),

              // 进度条
              LinearProgressIndicator(
                value: _currentProgress!.phase == Phase.finished 
                    ? 1.0 
                    : _currentProgress!.elapsedMs / 10000.0,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                color: _getPhaseColor(_currentProgress!.phase),
              ),
              const SizedBox(height: 8),

              // 进度文本
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已耗时: ${(_currentProgress!.elapsedMs / 1000).toStringAsFixed(1)}秒',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '剩余: ${(10 - _currentProgress!.elapsedMs / 1000).toStringAsFixed(1)}秒',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 实时速度
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '实时速度:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${_currentProgress!.instSpeedMbps.toStringAsFixed(2)} Mbps',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              // 最终结果
              if (_currentProgress!.phase == Phase.finished && _currentProgress!.bandwidthMbps != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _currentProgress!.bandwidthMbps! > 1.0
                        ? (isDark ? Colors.green[900]!.withOpacity(0.2) : Colors.green[50])
                        : (isDark ? Colors.orange[900]!.withOpacity(0.2) : Colors.orange[50]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentProgress!.bandwidthMbps! > 1.0
                          ? Colors.green
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _currentProgress!.bandwidthMbps! > 1.0 
                                ? Icons.check_circle 
                                : Icons.warning,
                            color: _currentProgress!.bandwidthMbps! > 1.0 
                                ? Colors.green 
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentProgress!.bandwidthMbps! > 1.0 
                                ? '网络质量良好' 
                                : '网络质量较差',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _currentProgress!.bandwidthMbps! > 1.0 
                                  ? Colors.green 
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '最终带宽: ${_currentProgress!.bandwidthMbps!.toStringAsFixed(2)} Mbps',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // 初始加载状态
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在初始化测速...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isTesting) ...[
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('取消'),
          ),
        ] else ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onComplete != null) {
                widget.onComplete!();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ],
    );
  }
}
