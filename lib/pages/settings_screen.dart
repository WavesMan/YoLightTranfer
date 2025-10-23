import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
