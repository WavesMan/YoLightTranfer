import 'package:flutter/material.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_spacing.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark 
          ? theme.colorScheme.surfaceContainerHigh // 暗色模式下使用更深的背景
          : theme.colorScheme.surface, // 亮色模式下使用默认表面色
      elevation: isDark ? 6 : 4, // 暗色模式下增加阴影
      shadowColor: isDark 
          ? Colors.black.withOpacity(0.4) // 暗色模式下更强的阴影
          : theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.cardBorderRadius,
        side: isDark 
            ? BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2), // 暗色模式下添加边框
                width: 1,
              )
            : BorderSide.none,
      ),
      child: Container(
        width: double.infinity,
        padding: padding ?? AppSpacing.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark 
                    ? theme.colorScheme.onSurface // 暗色模式下使用更亮的文字
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            // 内容区域
            child,
          ],
        ),
      ),
    );
  }
}
