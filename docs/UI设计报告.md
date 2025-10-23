# FlClash UI设计报告

## 项目概述

FlClash是一个基于ClashMeta的多平台代理客户端，使用Flutter开发，支持Android、Windows、macOS和Linux平台。采用Material You设计语言，提供简洁易用的代理管理体验。

## 设计系统分析

### 1. 色彩系统

**主色调：**
```dart
// 主要色彩配置
ColorScheme _getAppColorScheme({
  required Brightness brightness,
  int? primaryColor,
}) {
  return ref.read(genColorSchemeProvider(brightness));
}
```

**色彩层次：**
- 主色 (Primary): 动态色彩系统
- 辅助色 (Secondary): 用于强调和交互
- 表面色 (Surface): 卡片和背景
- 错误色 (Error): 错误状态指示

### 2. 字体系统

**字体配置：**
```yaml
# pubspec.yaml 字体配置
fonts:
  - family: JetBrainsMono
    fonts:
      - asset: assets/fonts/JetBrainsMono-Regular.ttf
  - family: Twemoji
    fonts:
      - asset: assets/fonts/Twemoji.Mozilla.ttf
  - family: Icons
    fonts:
      - asset: assets/fonts/Icons.ttf
```

**字体层次：**
- 标题字体: 大号加粗
- 正文字体: 中等大小
- 辅助字体: 小号轻量

### 3. 间距系统

**标准间距：**
```dart
// 常用间距值
const double spacingXS = 4.0;
const double spacingS = 8.0;
const double spacingM = 16.0;
const double spacingL = 24.0;
const double spacingXL = 32.0;
```

## 页面结构分析

### 1. 主页面结构

**移动端布局：**
```dart
// HomePage.dart 移动端布局
Column(
  children: [
    Flexible(
      flex: 1,
      child: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return widget.pageBuilder(context, index);
        },
      ),
    ),
    NavigationBar(
      // 底部导航栏
    ),
  ],
)
```

**桌面端布局：**
```dart
// 桌面端使用侧边栏导航
AppSidebarContainer(
  child: Material(
    color: context.colorScheme.surface,
    child: PageView.builder(
      // 页面内容
    ),
  ),
)
```

### 2. 导航系统

**导航项定义：**
```dart
// 导航项包含图标和标签
NavigationDestination(
  icon: e.icon,
  label: Intl.message(e.label.name),
)
```

**页面切换：**
```dart
// 页面切换逻辑
globalState.appController.toPage(navigationItems[index].label);
```

## 核心页面设计规范

### 1. 仪表板页面 (Dashboard)

**布局结构：**
```dart
CommonScaffold(
  title: appLocalizations.dashboard,
  actions: _buildActions(isEdit),
  floatingActionButton: const StartButton(),
  body: Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16).copyWith(bottom: 88),
      child: isEdit ? _buildEditMode() : _buildViewMode(),
    ),
  ),
)
```

**网格布局：**
```dart
Grid(
  crossAxisCount: columns,
  crossAxisSpacing: spacing,
  mainAxisSpacing: spacing,
  children: children,
)
```

**连接状态指示器：**
```dart
// 连接状态按钮
FilledButton.icon(
  onPressed: _handleConnection,
  style: FilledButton.styleFrom(
    backgroundColor: switch (coreStatus) {
      CoreStatus.connecting => null,
      CoreStatus.connected => Colors.greenAccent,
      CoreStatus.disconnected => context.colorScheme.error,
    },
  ),
  icon: SizedBox(
    child: switch (coreStatus) {
      CoreStatus.connecting => CircularProgressIndicator(),
      CoreStatus.connected => Icon(Icons.check_sharp),
      CoreStatus.disconnected => Icon(Icons.restart_alt_sharp),
    },
  ),
  label: Text(switch (coreStatus) {
    CoreStatus.connecting => appLocalizations.connecting,
    CoreStatus.connected => appLocalizations.connected,
    CoreStatus.disconnected => appLocalizations.disconnected,
  }),
)
```

### 2. 代理页面 (Proxies)

**页面结构：**
```dart
CommonScaffold(
  floatingActionButton: _buildFAB(),
  actions: _buildActions(),
  title: appLocalizations.proxies,
  searchState: AppBarSearchState(onSearch: _onSearch),
  body: switch (proxiesType) {
    ProxiesType.tab => ProxiesTabView(),
    ProxiesType.list => const ProxiesListView(),
  },
)
```

**代理列表项：**
```dart
// 代理项设计规范
ListTile(
  leading: ProxyIcon(proxy: proxy),
  title: Text(proxy.name),
  subtitle: Text(proxy.delay?.toString() ?? '--'),
  trailing: ProxyStatusIndicator(proxy: proxy),
  onTap: () => _selectProxy(proxy),
)
```

### 3. 设置页面

**设置项结构：**
```dart
// 设置项通用模式
ListTile(
  leading: Icon(setting.icon),
  title: Text(setting.title),
  subtitle: Text(setting.description),
  trailing: setting.controlWidget,
  onTap: setting.onTap,
)
```

## 组件设计规范

### 1. 通用组件

**CommonScaffold：**
```dart
class CommonScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final AppBarSearchState? searchState;

  const CommonScaffold({
    required this.title,
    required this.actions,
    required this.body,
    this.floatingActionButton,
    this.searchState,
  });
}
```

**按钮组件：**
```dart
// 主要按钮样式
FilledButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: EdgeInsets.symmetric(horizontal: 12),
)
```

### 2. 状态指示器

**连接状态：**
```dart
// 连接状态指示器
IconButton.filled(
  style: IconButton.styleFrom(
    backgroundColor: Colors.greenAccent,
    foregroundColor: context.colorScheme.onSurfaceVariant,
  ),
  icon: Icon(Icons.check, fontWeight: FontWeight.w900),
)
```

**加载状态：**
```dart
CircularProgressIndicator(
  strokeWidth: 3,
  color: context.colorScheme.onPrimary,
  backgroundColor: Colors.transparent,
)
```

### 3. 弹窗和表单

**底部弹窗：**
```dart
showSheet(
  builder: (_, type) {
    return AdaptiveSheetScaffold(
      type: type,
      body: const ProxiesSetting(),
      title: appLocalizations.settings,
    );
  },
  context: context,
)
```

## 平台差异化设计

### 1. Android端设计

**导航模式：**
- 底部导航栏
- 手势导航支持
- 状态栏集成

**交互模式：**
- Material Design 交互模式
- 触摸友好的控件大小
- 系统级集成（VPN服务）

### 2. Windows端设计

**窗口管理：**
```dart
// 桌面端窗口管理
WindowManager(
  child: TrayManager(
    child: HotKeyManager(child: ProxyManager(child: child)),
  ),
)
```

**桌面特性：**
- 系统托盘集成
- 全局快捷键
- 窗口控制
- 右键菜单

## 交互设计模式

### 1. 页面切换

**平滑过渡：**
```dart
await _pageController.animateToPage(
  index,
  duration: kTabScrollDuration,
  curve: Curves.easeOut,
)
```

### 2. 状态管理

**Riverpod状态管理：**
```dart
final currentPageLabelProvider = Provider<PageLabel>((ref) {
  return ref.watch(appSettingProvider.select((state) => state.pageLabel));
});
```

### 3. 搜索功能

**实时搜索：**
```dart
void _onSearch(String value) {
  ref.read(queryMapProvider.notifier).updateQuery(QueryTag.proxies, value);
}
```

## 视觉设计规范

### 1. 卡片设计

**卡片样式：**
```dart
Card(
  elevation: 1,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 卡片内容
      ],
    ),
  ),
)
```

### 2. 图标设计

**图标使用规范：**
- Material Icons 为主要图标库
- 自定义图标用于特殊功能
- 一致的图标大小和颜色

### 3. 动画效果

**页面过渡：**
```dart
const PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: CommonPageTransitionsBuilder(),
    TargetPlatform.windows: CommonPageTransitionsBuilder(),
  },
)
```

## 实现建议

### 1. 组件开发指南

**创建可复用组件：**
```dart
class CustomComponent extends StatelessWidget {
  final String title;
  final Widget content;
  
  const CustomComponent({
    required this.title,
    required this.content,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          content,
        ],
      ),
    );
  }
}
```

### 2. 主题配置

**主题扩展：**
```dart
extension ThemeExtension on ThemeData {
  Color get customColor => colorScheme.primary.withOpacity(0.1);
}
```

### 3. 响应式设计

**屏幕适配：**
```dart
bool get isMobile => MediaQuery.of(context).size.width < 600;
bool get isTablet => MediaQuery.of(context).size.width < 1200;
bool get isDesktop => !isMobile && !isTablet;
```

## 总结

FlClash的UI设计体现了现代Flutter应用的最佳实践：
- 采用Material You设计语言
- 支持多平台自适应
- 模块化组件设计
- 良好的用户体验
- 一致的设计系统

这个设计报告提供了完整的UI设计规范和实现指南，可以作为其他类似项目的参考模板。
