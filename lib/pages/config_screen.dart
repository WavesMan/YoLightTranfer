import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

/// 配置管理页面
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final Map<String, dynamic> _tempConfig = {};
  bool _hasUnsavedChanges = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configService = context.watch<AppConfigService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('应用配置'),
        centerTitle: true,
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveChanges(configService),
              tooltip: '保存更改',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _resetToDefaults(configService),
            tooltip: '重置为默认值',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          // 传输日志配置
          _buildConfigSection(
            theme,
            title: '传输日志设置',
            icon: Icons.history,
            children: [
              _buildBooleanConfig(
                configService,
                key: AppConfigService.enableTransferLogPage,
                label: '启用传输日志页面',
                description: '控制是否在应用中显示传输日志页面',
                onChanged: (value) => _updateConfig(AppConfigService.enableTransferLogPage, value),
              ),
              _buildIntegerConfig(
                configService,
                key: AppConfigService.maxLogEntries,
                label: '最大日志条目数',
                description: '限制传输日志的最大数量，避免内存占用过大',
                minValue: 100,
                maxValue: 10000,
                step: 100,
                onChanged: (value) => _updateConfig(AppConfigService.maxLogEntries, value),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),

          // 传输设置
          _buildConfigSection(
            theme,
            title: '传输设置',
            icon: Icons.file_copy,
            children: [
              _buildBooleanConfig(
                configService,
                key: AppConfigService.enableFileVerification,
                label: '启用文件校验',
                description: '传输完成后验证文件的完整性',
                onChanged: (value) => _updateConfig(AppConfigService.enableFileVerification, value),
              ),
              _buildBooleanConfig(
                configService,
                key: AppConfigService.enableTransferRecovery,
                label: '启用传输恢复',
                description: '支持断点续传和传输失败恢复',
                onChanged: (value) => _updateConfig(AppConfigService.enableTransferRecovery, value),
              ),
              _buildIntegerConfig(
                configService,
                key: AppConfigService.transferChunkSize,
                label: '传输分片大小',
                description: '文件传输时的分片大小（字节）',
                minValue: 1024,
                maxValue: 1024 * 1024,
                step: 1024,
                onChanged: (value) => _updateConfig(AppConfigService.transferChunkSize, value),
              ),
              _buildIntegerConfig(
                configService,
                key: AppConfigService.connectionTimeout,
                label: '连接超时时间',
                description: '网络连接超时时间（毫秒）',
                minValue: 1000,
                maxValue: 60000,
                step: 1000,
                onChanged: (value) => _updateConfig(AppConfigService.connectionTimeout, value),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),

          // 系统设置
          _buildConfigSection(
            theme,
            title: '系统设置',
            icon: Icons.settings,
            children: [
              _buildBooleanConfig(
                configService,
                key: AppConfigService.enableDebugMode,
                label: '启用调试模式',
                description: '显示详细的调试信息和日志',
                onChanged: (value) => _updateConfig(AppConfigService.enableDebugMode, value),
              ),
              _buildBooleanConfig(
                configService,
                key: AppConfigService.enableAutoSave,
                label: '启用自动保存',
                description: '自动保存配置更改',
                onChanged: (value) => _updateConfig(AppConfigService.enableAutoSave, value),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),

          // 操作按钮
          _buildActionButtons(configService, theme),
        ],
      ),
    );
  }

  /// 构建配置区块
  Widget _buildConfigSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 区块标题
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.s),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            
            // 配置项
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建布尔类型配置项
  Widget _buildBooleanConfig(
    AppConfigService configService, {
    required String key,
    required String label,
    required String description,
    required ValueChanged<bool> onChanged,
  }) {
    final currentValue = _tempConfig[key] ?? configService.get<bool>(key);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Switch(
            value: currentValue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 构建整数类型配置项
  Widget _buildIntegerConfig(
    AppConfigService configService, {
    required String key,
    required String label,
    required String description,
    required int minValue,
    required int maxValue,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    final currentValue = _tempConfig[key] ?? configService.get<int>(key);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                currentValue.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Slider(
            value: currentValue.toDouble(),
            min: minValue.toDouble(),
            max: maxValue.toDouble(),
            divisions: (maxValue - minValue) ~/ step,
            onChanged: (value) => onChanged(value.toInt()),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(AppConfigService configService, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _exportConfig(configService),
            child: const Text('导出配置'),
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _importConfig(configService),
            child: const Text('导入配置'),
          ),
        ),
      ],
    );
  }

  /// 更新配置值
  void _updateConfig(String key, dynamic value) {
    setState(() {
      _tempConfig[key] = value;
      _hasUnsavedChanges = true;
    });
  }

  /// 保存更改
  Future<void> _saveChanges(AppConfigService configService) async {
    try {
      for (final entry in _tempConfig.entries) {
        await configService.set(entry.key, entry.value);
      }
      
      setState(() {
        _tempConfig.clear();
        _hasUnsavedChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 重置为默认值
  Future<void> _resetToDefaults(AppConfigService configService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要重置所有配置为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await configService.resetToDefaults();
        setState(() {
          _tempConfig.clear();
          _hasUnsavedChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配置已重置为默认值'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 导出配置
  Future<void> _exportConfig(AppConfigService configService) async {
    // 这里需要实现文件选择器来保存配置文件
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导出功能将在后续版本中实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 导入配置
  Future<void> _importConfig(AppConfigService configService) async {
    // 这里需要实现文件选择器来加载配置文件
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('导入功能将在后续版本中实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
