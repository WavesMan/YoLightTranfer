import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/widgets/device_card.dart';
import 'package:yolighttransfer/widgets/file_selection_area.dart';
import 'package:yolighttransfer/widgets/transfer_task_item.dart';
import 'package:yolighttransfer/widgets/section_card.dart';
import 'package:yolighttransfer/widgets/network_quality_recommendation_dialog.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/ai_network_quality_manager.dart';
import 'package:yolighttransfer/models/device.dart' as ui;

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  bool _hasShownRecommendation = false;

  @override
  void initState() {
    super.initState();
    // 延迟启动网络质量检测，确保Provider已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNetworkQualityDetection();
    });
  }

  /// 启动网络质量检测
  Future<void> _startNetworkQualityDetection() async {
    try {
      final qualityManager = context.read<AINetworkQualityManager>();
      await qualityManager.startDetection();
      
      // 监听网络质量状态变化
      qualityManager.addListener(() {
        if (qualityManager.shouldShowRecommendation && !_hasShownRecommendation) {
          _showRecommendationDialog(qualityManager);
        }
      });
    } catch (e) {
      print('网络质量检测启动失败: $e');
    }
  }

  /// 显示推荐弹窗
  void _showRecommendationDialog(AINetworkQualityManager qualityManager) {
    if (!mounted) return;
    
    _hasShownRecommendation = true;
    
    NetworkQualityRecommendationDialog.show(
      context: context,
      qualityManager: qualityManager,
      onAccept: () {
        // 用户接受推荐，跳转到热点分享页面
        // 这里需要实现页面跳转逻辑
        print('用户接受了热点推荐');
      },
      onReject: () {
        print('用户拒绝了热点推荐');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    // 从服务层读取实时数据：
    // - 在线设备：由 DeviceManager 通过 UDP 心跳维护
    // - 传输任务：由 TransferTaskManager 维护
    final devices = context.watch<DeviceManager>().getUiDevices();
    final transferTasks = context.watch<TransferTaskManager>().tasks;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态栏卡片 - 与KT UI对齐
          Card(
            color: theme.colorScheme.surfaceVariant,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.cardBorderRadius,
            ),
            child: Container(
              width: double.infinity,
              padding: AppSpacing.cardPadding,
              child: Text(
                '连接状态：已连接 (${devices.length} 个设备在线)',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 设备选择区域 - 与KT UI对齐
          SectionCard(
            title: '目标设备',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (devices.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                    child: Text(
                      '未发现在线设备',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      // 选中设备提示
                      Consumer<DeviceManager>(
                        builder: (context, deviceManager, child) {
                          final selectedDevice = deviceManager.selectedDevice;
                          if (selectedDevice == null) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s,
                                horizontal: AppSpacing.m,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(AppBorderRadius.s),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  Expanded(
                                    child: Text(
                                      '请选择一个目标设备以进行文件传输',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s,
                              horizontal: AppSpacing.m,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppBorderRadius.s),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    '已选择目标设备: ${selectedDevice.name}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => deviceManager.deselectDevice(),
                                  child: Text(
                                    '取消选择',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      
                      // 设备列表 - 单列横排格式
                      Consumer<DeviceManager>(
                        builder: (context, deviceManager, child) {
                          final uiDevices = deviceManager.getUiDevices();
                          final discoveredDevices = deviceManager.getOnlineDevices();
                          
                          // 安全检查：确保两个列表长度一致
                          if (uiDevices.length != discoveredDevices.length) {
                            print('警告：UI设备列表长度(${uiDevices.length})与发现设备列表长度(${discoveredDevices.length})不一致');
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                              child: Text(
                                '设备列表数据异常，请重启应用',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            );
                          }
                          
                          // 由于 getUiDevices() 基于 getOnlineDevices() 构建，顺序应该一致
                          // 直接使用索引关联，确保设备选择逻辑正确
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: uiDevices.length,
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s),
                            itemBuilder: (context, index) {
                              final uiDevice = uiDevices[index];
                              final discoveredDevice = discoveredDevices[index];
                              
                              return DeviceCard(
                                device: uiDevice,
                                isSelected: deviceManager.isDeviceSelected(discoveredDevice.id),
                                onTap: () {
                                  if (deviceManager.isDeviceSelected(discoveredDevice.id)) {
                                    deviceManager.deselectDevice();
                                  } else {
                                    deviceManager.selectDevice(discoveredDevice.id);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 文件传输区域 - 与KT UI对齐
          SectionCard(
            title: '文件传输',
            child: FileSelectionArea(),
          ),
          const SizedBox(height: AppSpacing.l),

          // 等待传输队列 - 与KT UI对齐
          if (transferTasks.isNotEmpty)
            SectionCard(
              title: '传输任务队列',
              child: Column(
                children: transferTasks
                    .map((task) => TransferTaskItem(
                          task: task,
                          onCancel: () {
                            // 实现取消传输逻辑
                            final taskManager = context.read<TransferTaskManager>();
                            
                            try {
                              final logManager = context.read<TransferLogManager>();
                              
                              // 取消传输
                              taskManager.cancelTask(task.fileName);
                              
                              // 记录取消日志
                              logManager.addInfoLog(
                                message: '用户取消了文件传输: ${task.fileName}',
                                fileName: task.fileName,
                                device: task.targetDevice,
                              );
                            } catch (e) {
                              // 如果日志管理器不可用，仅取消传输
                              taskManager.cancelTask(task.fileName);
                            }
                            
                            // 从 UI 中移除任务
                            taskManager.removeTask(task);
                            
                            // 显示取消成功提示
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已取消传输: ${task.fileName}'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          onRetry: () {
                            // 实现重试传输逻辑
                            final taskManager = context.read<TransferTaskManager>();
                            taskManager.removeTask(task);
                            if (task.fileInfo != null && task.targetDevice != null) {
                              taskManager.addWaitingTask(task.fileInfo!, task.targetDevice!);
                            }
                          },
                        ))
                    .toList(),
              ),
            ),

          // 等待传输队列 - 显示等待传输的文件
          Consumer<TransferTaskManager>(
            builder: (context, taskManager, child) {
              final waitingTasks = taskManager.waitingTasks;
              if (waitingTasks.isEmpty) return const SizedBox.shrink();
              
              return Column(
                children: [
                  const SizedBox(height: AppSpacing.l),
                  SectionCard(
                    title: '等待传输队列',
                    child: Column(
                      children: waitingTasks
                          .map((task) => Container(
                                margin: const EdgeInsets.only(bottom: AppSpacing.s),
                                padding: const EdgeInsets.all(AppSpacing.s),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(AppBorderRadius.s),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.fileName,
                                            style: theme.textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '等待传输到 ${task.targetDevice?.name ?? '未知设备'}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () => taskManager.removeWaitingTask(task.fileName),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

}
