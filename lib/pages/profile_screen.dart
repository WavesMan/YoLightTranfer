import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/services/config/version_service.dart';
import 'package:yolighttransfer/widgets/update_dialog.dart';
import 'package:yolighttransfer/widgets/about_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isCheckingUpdate = false;

  /// 检查更新
  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final versionService = VersionService();
      final response = await versionService.checkForUpdates();

      if (!mounted) return;

      if (response.needsUpdate) {
        // 显示更新对话框
        await showUpdateDialog(
          context,
          versionResponse: response,
          currentVersion: versionService.displayVersion,
          onDownload: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('正在打开浏览器下载...')),
            );
          },
          onCancel: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已取消更新')),
            );
          },
        );
      } else {
        // 已是最新版本
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      print('❌ 检查更新失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

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
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('提示'),
                          content: const Text('暂不支持登录，请等待新版本'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
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
                    subtitle: Text(VersionService().displayVersion),
                    trailing: _isCheckingUpdate
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _checkForUpdate,
                          ),
                  ),
                  _AboutSoftwareItem(
                    onTap: () async {
                      final versionService = VersionService();
                      final aboutText = await versionService.getAboutText();
                      if (context.mounted) {
                        await showAboutAppDialog(
                          context,
                          aboutText: aboutText,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

/// 关于软件列表项 - 带圆角和点击动效
class _AboutSoftwareItem extends StatefulWidget {
  final VoidCallback onTap;

  const _AboutSoftwareItem({
    required this.onTap,
  });

  @override
  State<_AboutSoftwareItem> createState() => _AboutSoftwareItemState();
}

class _AboutSoftwareItemState extends State<_AboutSoftwareItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isPressed
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.m),
        ),
        child: ListTile(
          title: const Text('关于软件'),
          trailing: Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
