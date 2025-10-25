import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/widgets/rich_text_with_links.dart';

/// 关于软件对话框
class AboutAppDialog extends StatelessWidget {
  /// 关于软件的文本内容
  final String aboutText;

  const AboutAppDialog({
    required this.aboutText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('关于软件'),
      content: SingleChildScrollView(
        child: RichTextWithLinks(
          text: aboutText,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.6,
          ),
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 显示关于软件对话框的便捷方法
Future<void> showAboutAppDialog(
  BuildContext context, {
  required String aboutText,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AboutAppDialog(
      aboutText: aboutText,
    ),
  );
}
