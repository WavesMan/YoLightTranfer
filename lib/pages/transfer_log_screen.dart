import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/models/transfer_log.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/file_picker/file_picker_factory.dart';
import 'package:yolighttransfer/widgets/traditional_log_item.dart';

/// 传输日志查看页面 - 使用传统 time | models | logs 格式
class TransferLogScreen extends StatefulWidget {
  const TransferLogScreen({super.key});

  @override
  State<TransferLogScreen> createState() => _TransferLogScreenState();
}

class _TransferLogScreenState extends State<TransferLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransferLogType? _selectedType;
  bool _showFullTimestamp = false;
  bool _showHeader = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logManager = context.watch<TransferLogManager>();
    final logs = logManager.logs;

    // 应用筛选
    List<TransferLog> filteredLogs = logs;
    if (_selectedType != null) {
      filteredLogs = logs.where((log) => log.type == _selectedType).toList();
    }
    if (_searchController.text.isNotEmpty) {
      filteredLogs = logManager.searchLogs(_searchController.text);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输日志'),
        centerTitle: true,
        actions: [
          // 时间格式切换
          IconButton(
            icon: Icon(_showFullTimestamp ? Icons.access_time : Icons.schedule),
            onPressed: () {
              setState(() {
                _showFullTimestamp = !_showFullTimestamp;
              });
            },
            tooltip: _showFullTimestamp ? '显示相对时间' : '显示完整时间戳',
          ),
          // 头部显示切换
          IconButton(
            icon: Icon(_showHeader ? Icons.view_headline : Icons.view_stream),
            onPressed: () {
              setState(() {
                _showHeader = !_showHeader;
              });
            },
            tooltip: _showHeader ? '隐藏表头' : '显示表头',
          ),
          // 导出日志
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportLogs(logManager),
            tooltip: '导出日志',
          ),
          // 清空日志
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _clearLogs(logManager),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和筛选栏
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索日志内容...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: AppBorderRadius.buttonBorderRadius,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                  ),
                  onChanged: (String value) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.m),
                
                // 类型筛选
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeFilter('全部', null, theme),
                      _buildTypeFilter('发送', TransferLogType.send, theme),
                      _buildTypeFilter('接收', TransferLogType.receive, theme),
                      _buildTypeFilter('错误', TransferLogType.error, theme),
                      _buildTypeFilter('信息', TransferLogType.info, theme),
                      _buildTypeFilter('TCP', TransferLogType.tcp, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 日志头部
          if (_showHeader) TraditionalLogHeader(showFullTimestamp: _showFullTimestamp),

          // 日志列表
          Expanded(
            child: TraditionalLogList(
              logs: filteredLogs,
              showFullTimestamp: _showFullTimestamp,
              onLogTap: (log) => _showLogDetails(log, theme),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型筛选按钮
  Widget _buildTypeFilter(String text, TransferLogType? type, ThemeData theme) {
    final isSelected = _selectedType == type;
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.s),
      child: FilterChip(
        label: Text(text),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedType = isSelected ? null : type;
          });
        },
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
        checkmarkColor: theme.colorScheme.primary,
      ),
    );
  }

  /// 显示日志详情
  void _showLogDetails(TransferLog log, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('日志详情 - ${log.typeText}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('时间', _formatFullTimestamp(log.timestamp)),
              _buildDetailRow('类型', log.typeText),
              _buildDetailRow('文件', log.fileName),
              if (log.fileSize > 0) _buildDetailRow('大小', log.fileSizeText),
              if (log.deviceName != '未知设备') _buildDetailRow('设备', log.deviceName),
              _buildDetailRow('消息', log.message),
              if (log.error != null) _buildDetailRow('错误', log.error!, isError: true),
              if (log.progress != null) _buildDetailRow('进度', '${log.progress}%'),
              if (log.transferSpeed != null) _buildDetailRow('速度', log.transferSpeed!),
              if (log.estimatedTime != null) _buildDetailRow('预计时间', log.estimatedTime!),
              if (log.savePath != null) _buildDetailRow('保存位置', log.savePath!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化完整时间戳
  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 导出日志
  Future<void> _exportLogs(TransferLogManager logManager) async {
    try {
      // 创建文件选择器服务
      final filePickerService = FilePickerFactory.create();
      
      // 获取默认导出文件名
      final defaultFileName = logManager.getDefaultExportFileName();
      
      // 让用户选择保存位置和文件名
      final savePath = await filePickerService.pickSaveLocation(
        defaultFileName: defaultFileName,
        allowedExtensions: ['json'],
        dialogTitle: '保存传输日志',
      );
      
      if (savePath == null) {
        // 用户取消了选择
        return;
      }
      
      // 导出日志到用户选择的路径
      final exportPath = await logManager.exportLogsToPath(savePath);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('日志已导出到: $exportPath'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 清空日志
  Future<void> _clearLogs(TransferLogManager logManager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有传输日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logManager.clearAllLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所有日志已清空'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
