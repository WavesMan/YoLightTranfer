/// URL 和 Markdown 链接解析器
/// 
/// 支持两种格式：
/// 1. 纯 URL：https://example.com
/// 2. Markdown 链接：[显示文本](https://example.com)

class LinkSegment {
  /// 显示的文本
  final String text;

  /// URL 地址（如果是链接）
  final String? url;

  /// 是否是链接
  final bool isLink;

  LinkSegment({
    required this.text,
    this.url,
    this.isLink = false,
  });

  @override
  String toString() {
    return 'LinkSegment(text=$text, url=$url, isLink=$isLink)';
  }
}

/// URL 和 Markdown 链接解析器
class UrlParser {
  /// URL 正则表达式（匹配 http:// 和 https:// 开头的 URL）
  static final _urlRegex = RegExp(
    r'https?://[^\s\)]+',
    caseSensitive: false,
  );

  /// Markdown 链接正则表达式（匹配 [text](url) 格式）
  static final _markdownLinkRegex = RegExp(
    r'\[([^\]]+)\]\(([^)]+)\)',
  );

  /// 解析文本中的 URL 和 Markdown 链接
  /// 
  /// 返回文本片段列表，每个片段包含文本和可选的 URL
  static List<LinkSegment> parseText(String text) {
    final segments = <LinkSegment>[];
    
    if (text.isEmpty) {
      return segments;
    }

    // 首先处理 Markdown 链接
    final markdownMatches = _markdownLinkRegex.allMatches(text);
    final markdownRanges = <_Range>[];
    
    for (final match in markdownMatches) {
      final displayText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      
      if (displayText.isNotEmpty && url.isNotEmpty && _isValidUrl(url)) {
        markdownRanges.add(_Range(
          start: match.start,
          end: match.end,
          text: displayText,
          url: url,
          isMarkdown: true,
        ));
      }
    }

    // 然后处理纯 URL（不在 Markdown 链接范围内）
    final urlMatches = _urlRegex.allMatches(text);
    final urlRanges = <_Range>[];
    
    for (final match in urlMatches) {
      final url = match.group(0) ?? '';
      
      // 检查是否在 Markdown 链接范围内
      bool inMarkdownRange = false;
      for (final range in markdownRanges) {
        if (match.start >= range.start && match.end <= range.end) {
          inMarkdownRange = true;
          break;
        }
      }
      
      if (!inMarkdownRange && _isValidUrl(url)) {
        urlRanges.add(_Range(
          start: match.start,
          end: match.end,
          text: url,
          url: url,
          isMarkdown: false,
        ));
      }
    }

    // 合并所有范围
    final allRanges = [...markdownRanges, ...urlRanges];
    allRanges.sort((a, b) => a.start.compareTo(b.start));

    // 检查重叠
    final finalRanges = <_Range>[];
    for (final range in allRanges) {
      bool overlaps = false;
      for (final existing in finalRanges) {
        if ((range.start >= existing.start && range.start < existing.end) ||
            (range.end > existing.start && range.end <= existing.end) ||
            (range.start <= existing.start && range.end >= existing.end)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        finalRanges.add(range);
      }
    }

    // 构建文本片段
    int currentPos = 0;
    for (final range in finalRanges) {
      // 添加范围前的普通文本
      if (currentPos < range.start) {
        segments.add(LinkSegment(
          text: text.substring(currentPos, range.start),
          isLink: false,
        ));
      }

      // 添加链接片段
      segments.add(LinkSegment(
        text: range.text,
        url: range.url,
        isLink: true,
      ));

      currentPos = range.end;
    }

    // 添加末尾的普通文本
    if (currentPos < text.length) {
      segments.add(LinkSegment(
        text: text.substring(currentPos),
        isLink: false,
      ));
    }

    return segments;
  }

  /// 验证 URL 格式
  static bool _isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }
}

/// 内部范围类
class _Range {
  final int start;
  final int end;
  final String text;
  final String url;
  final bool isMarkdown;

  _Range({
    required this.start,
    required this.end,
    required this.text,
    required this.url,
    required this.isMarkdown,
  });
}
