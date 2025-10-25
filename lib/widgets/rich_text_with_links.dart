import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yolighttransfer/util/url_parser.dart';

/// 支持链接的富文本组件
/// 
/// 自动识别纯 URL 和 Markdown 链接格式 [text](url)
/// 点击链接时打开浏览器
class RichTextWithLinks extends StatelessWidget {
  /// 文本内容
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 链接样式
  final TextStyle? linkStyle;

  /// 行高
  final double? height;

  const RichTextWithLinks({
    required this.text,
    this.style,
    this.linkStyle,
    this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 默认文本样式
    final defaultStyle = style ?? theme.textTheme.bodyMedium;
    
    // 默认链接样式（蓝色、下划线）
    final defaultLinkStyle = linkStyle ??
        (defaultStyle?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ) ??
        TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ));

    // 解析文本中的链接
    final segments = UrlParser.parseText(text);

    // 构建 TextSpan 列表
    final textSpans = <InlineSpan>[];
    
    for (final segment in segments) {
      if (segment.isLink && segment.url != null) {
        // 链接片段
        textSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _openUrl(segment.url!),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  segment.text,
                  style: defaultLinkStyle.copyWith(height: height),
                ),
              ),
            ),
          ),
        );
      } else {
        // 普通文本片段
        textSpans.add(
          TextSpan(
            text: segment.text,
            style: defaultStyle?.copyWith(height: height),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: defaultStyle?.copyWith(height: height),
      ),
    );
  }

  /// 打开 URL
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('❌ 无法打开 URL: $url');
      }
    } catch (e) {
      print('❌ 打开 URL 失败: $e');
    }
  }
}
