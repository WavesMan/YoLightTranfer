import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/widgets/network_test_progress_dialog.dart';
import 'package:yolighttransfer/ai/ai_network_advisor.dart';
import 'package:yolighttransfer/ai/network_quality_analyzer.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AINetworkAdvisor _aiAdvisor;
  late NetworkQualityAnalyzer _networkAnalyzer;
  late AppConfigService _configService;
  bool _isTestingGateway = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    // 这里需要根据实际的项目结构来初始化服务
    // 暂时使用占位符，实际项目中需要注入正确的依赖
    _configService = AppConfigService();
    _networkAnalyzer = NetworkQualityAnalyzer('192.168.1.1', 80);
    _aiAdvisor = AINetworkAdvisor(
      networkAnalyzer: _networkAnalyzer,
      configService: _configService,
    );
  }

  /// 开始网关测速
  void _startGatewaySpeedTest() {
    setState(() {
      _isTestingGateway = true;
    });

    // 获取默认网关IP（这里使用示例IP，实际项目中需要获取真实网关IP）
    final gatewayIp = '192.168.1.1';

    // 获取测速进度流
    final progressStream = _aiAdvisor.measureGatewayBandwidth(gatewayIp);

    // 显示测速进度弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NetworkTestProgressDialog(
        progressStream: progressStream,
        gatewayIp: gatewayIp,
        onComplete: () {
          setState(() {
            _isTestingGateway = false;
          });
          Navigator.of(context).pop();
        },
        onCancel: () {
          setState(() {
            _isTestingGateway = false;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备设置
          Text(
            '设备设置',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 6, // 增强阴影效果
            shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.cardBorderRadius,
            ),
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: '我的设备',
                    decoration: const InputDecoration(
                      labelText: '设备名称',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    initialValue: '7431',
                    decoration: const InputDecoration(
                      labelText: 'TCP端口',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 传输设置
          Text(
            '传输设置',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 6, // 增强阴影效果
            shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.cardBorderRadius,
            ),
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: '1MB',
                    items: const [
                      DropdownMenuItem(value: '1MB', child: Text('1MB')),
                      DropdownMenuItem(value: '2MB', child: Text('2MB')),
                      DropdownMenuItem(value: '4MB', child: Text('4MB')),
                      DropdownMenuItem(value: '8MB', child: Text('8MB')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '分片大小',
                    ),
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: AppSpacing.m),
                  DropdownButtonFormField<String>(
                    value: '30秒',
                    items: const [
                      DropdownMenuItem(value: '10秒', child: Text('10秒')),
                      DropdownMenuItem(value: '20秒', child: Text('20秒')),
                      DropdownMenuItem(value: '30秒', child: Text('30秒')),
                      DropdownMenuItem(value: '60秒', child: Text('60秒')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '超时时间',
                    ),
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    title: const Text('自动接收'),
                    value: true,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 网络设置
          Text(
            '网络设置',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 6, // 增强阴影效果
            shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.cardBorderRadius,
            ),
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: '7431',
                    decoration: const InputDecoration(
                      labelText: '广播端口',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    initialValue: '5秒',
                    decoration: const InputDecoration(
                      labelText: '发现间隔',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  
                  // 网关测速按钮
                  ElevatedButton.icon(
                    onPressed: _isTestingGateway ? null : _startGatewaySpeedTest,
                    icon: _isTestingGateway 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.speed, size: 20),
                    label: Text(
                      _isTestingGateway ? '测速中...' : '检测上游网络质量',
                      style: theme.textTheme.bodyMedium,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '检测网关网络质量，采用动态截断算法（2-10秒）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
