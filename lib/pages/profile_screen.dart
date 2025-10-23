import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息
          Text(
            '用户信息',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.m),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  const Text(
                    '未登录',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  ElevatedButton(
                    onPressed: () {
                      // 登录逻辑
                    },
                    child: const Text('立即登录'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 应用信息
          Text(
            '应用信息',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.m),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('版本'),
                    subtitle: const Text('v1.0.0'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        // 检查更新
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已是已是已是最新最新版本')),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('关于软件'),
                    onTap: () {
                      // 关于软件软件
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 数据统计
          Text(
            '数据统计',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.m),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('总传输'),
                    subtitle: const Text('128文件 (2.5 GB)'),
                  ),
                  ListTile(
                    title: const Text('成功'),
                    subtitle: const Text('125'),
                  ),
                  ListTile(
                    title: const Text('失败'),
                    subtitle: const Text('3'),
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
