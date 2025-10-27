import 'dart:convert';

/// 版本检查响应信息
class VersionCheckResponse {
  /// 新版本号
  final String version;

  /// 下载地址
  final String downloadUrl;

  /// 是否需要更新
  final bool needsUpdate;

  /// 更新说明（可选）
  final String? updateDescription;

  /// 是否强制更新（可选）
  final bool forceUpdate;

  /// 结构化更新日志（可选）
  final Changelog? changelog;

  VersionCheckResponse({
    required this.version,
    required this.downloadUrl,
    required this.needsUpdate,
    this.updateDescription,
    this.forceUpdate = false,
    this.changelog,
  });

  @override
  String toString() {
    return 'VersionCheckResponse('
        'version=$version, '
        'downloadUrl=$downloadUrl, '
        'needsUpdate=$needsUpdate, '
        'forceUpdate=$forceUpdate'
        ')';
  }
}

/// 结构化更新日志
class Changelog {
  /// 更新日志标题
  final String title;

  /// 更新章节列表
  final List<ChangelogSection> sections;

  /// 页脚信息（可选）
  final String? footer;

  Changelog({
    required this.title,
    required this.sections,
    this.footer,
  });
}

/// 更新日志章节
class ChangelogSection {
  /// 章节标题
  final String title;

  /// 章节类型
  final String type;

  /// 章节内容项
  final List<String> items;

  ChangelogSection({
    required this.title,
    required this.type,
    required this.items,
  });
}

/// 版本检查 JSON 解析器
/// 
/// 支持灵活的 JSON 结构：
/// {
///   "app": {
///     "version": "1.0.1",
///     "url": "https://example.com/download/v1.0.1",
///     "description": "更新说明",
///     "force": false,
///     ... 其他字段
///   },
///   ... 其他顶级字段
/// }
class VersionCheckParser {
  /// 解析版本检查 JSON 响应
  static VersionCheckResponse parseResponse(
    String jsonString,
    String currentVersion,
  ) {
    try {
      final json = jsonDecode(jsonString);
      return _parseJson(json, currentVersion);
    } catch (e) {
      print('❌ 版本检查 JSON 解析失败: $e');
      throw FormatException('无法解析版本检查响应: $e');
    }
  }

  /// 从 Map 解析版本检查响应
  static VersionCheckResponse parseMap(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    return _parseJson(json, currentVersion);
  }

  /// 内部解析逻辑
  static VersionCheckResponse _parseJson(
    dynamic json,
    String currentVersion,
  ) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('响应必须是 JSON 对象');
    }

    // 获取 app 配置
    final appConfig = json['app'];
    if (appConfig == null) {
      throw FormatException('响应中缺少 app 字段');
    }

    if (appConfig is! Map<String, dynamic>) {
      throw FormatException('app 字段必须是对象');
    }

    // 提取版本号
    final newVersion = appConfig['version'] as String?;
    if (newVersion == null || newVersion.isEmpty) {
      throw FormatException('app.version 字段缺失或为空');
    }

    // 提取下载 URL
    final downloadUrl = appConfig['url'] as String?;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw FormatException('app.url 字段缺失或为空');
    }

    // 提取可选字段
    final updateDescription = appConfig['description'] as String?;
    final forceUpdate = appConfig['force'] as bool? ?? false;

    // 解析结构化更新日志（如果存在）
    final changelog = _parseChangelog(appConfig);

    // 比较版本号
    final needsUpdate = _compareVersions(currentVersion, newVersion) < 0;

    return VersionCheckResponse(
      version: newVersion,
      downloadUrl: downloadUrl,
      needsUpdate: needsUpdate,
      updateDescription: updateDescription,
      forceUpdate: forceUpdate,
      changelog: changelog,
    );
  }

  /// 比较版本号
  /// 返回值：
  /// - 负数：currentVersion < newVersion（需要更新）
  /// - 0：currentVersion == newVersion（版本相同）
  /// - 正数：currentVersion > newVersion（当前版本更新）
  static int _compareVersions(String version1, String version2) {
    try {
      final parts1 = version1.split('+');
      final parts2 = version2.split('+');

      // 比较主版本号（x.y.z）
      final mainVersion1 = parts1[0];
      final mainVersion2 = parts2[0];

      final comparison = _compareMainVersions(mainVersion1, mainVersion2);
      if (comparison != 0) {
        return comparison;
      }

      // 如果主版本号相同，比较构建号
      final buildNumber1 = parts1.length > 1 ? int.tryParse(parts1[1]) ?? 0 : 0;
      final buildNumber2 = parts2.length > 1 ? int.tryParse(parts2[1]) ?? 0 : 0;

      return buildNumber1.compareTo(buildNumber2);
    } catch (e) {
      print('⚠️ 版本号比较失败: $e，将视为版本相同');
      return 0;
    }
  }

  /// 比较主版本号（x.y.z 格式）
  static int _compareMainVersions(String version1, String version2) {
    try {
      final parts1 = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // 补齐版本号长度
      while (parts1.length < parts2.length) {
        parts1.add(0);
      }
      while (parts2.length < parts1.length) {
        parts2.add(0);
      }

      // 逐位比较
      for (int i = 0; i < parts1.length; i++) {
        final comparison = parts1[i].compareTo(parts2[i]);
        if (comparison != 0) {
          return comparison;
        }
      }

      return 0;
    } catch (e) {
      print('⚠️ 主版本号比较失败: $e');
      return 0;
    }
  }

  /// 验证版本号格式
  static bool isValidVersion(String version) {
    // 支持格式：x.y.z 或 x.y.z+buildNumber
    final pattern = RegExp(r'^\d+(\.\d+)*(\+\d+)?$');
    return pattern.hasMatch(version);
  }

  /// 验证 URL 格式
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  /// 解析结构化更新日志
  static Changelog? _parseChangelog(Map<String, dynamic> appConfig) {
    try {
      final changelogJson = appConfig['changelog'];
      if (changelogJson == null) {
        return null;
      }

      if (changelogJson is! Map<String, dynamic>) {
        print('⚠️ changelog 字段必须是对象，忽略该字段');
        return null;
      }

      final title = changelogJson['title'] as String?;
      if (title == null || title.isEmpty) {
        print('⚠️ changelog.title 字段缺失或为空，忽略 changelog');
        return null;
      }

      final sectionsJson = changelogJson['sections'];
      if (sectionsJson == null || sectionsJson is! List) {
        print('⚠️ changelog.sections 字段缺失或不是数组，忽略 changelog');
        return null;
      }

      final sections = <ChangelogSection>[];
      for (final sectionJson in sectionsJson) {
        if (sectionJson is! Map<String, dynamic>) {
          print('⚠️ 章节数据格式错误，跳过该章节');
          continue;
        }

        final sectionTitle = sectionJson['title'] as String?;
        final sectionType = sectionJson['type'] as String?;
        final sectionItems = sectionJson['items'] as List?;

        if (sectionTitle == null || sectionTitle.isEmpty) {
          print('⚠️ 章节标题缺失，跳过该章节');
          continue;
        }

        if (sectionType == null || sectionType.isEmpty) {
          print('⚠️ 章节类型缺失，跳过该章节');
          continue;
        }

        if (sectionItems == null || sectionItems is! List) {
          print('⚠️ 章节内容项缺失或不是数组，跳过该章节');
          continue;
        }

        final items = <String>[];
        for (final item in sectionItems) {
          if (item is String) {
            items.add(item);
          } else {
            print('⚠️ 章节内容项格式错误，跳过该项');
          }
        }

        if (items.isNotEmpty) {
          sections.add(ChangelogSection(
            title: sectionTitle,
            type: sectionType,
            items: items,
          ));
        }
      }

      if (sections.isEmpty) {
        print('⚠️ 没有有效的章节，忽略 changelog');
        return null;
      }

      final footer = changelogJson['footer'] as String?;

      return Changelog(
        title: title,
        sections: sections,
        footer: footer,
      );
    } catch (e) {
      print('⚠️ 解析结构化更新日志失败: $e，忽略该字段');
      return null;
    }
  }
}
