import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yolighttransfer/pages/device_discovery_screen.dart';
import 'package:yolighttransfer/pages/profile_screen.dart';
import 'package:yolighttransfer/pages/config_screen.dart';
import 'package:yolighttransfer/pages/transfer_log_screen.dart';
import 'package:yolighttransfer/theme/app_theme.dart';
import 'package:yolighttransfer/theme/app_border_radius.dart';
import 'package:yolighttransfer/services/device/device_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_task_manager.dart';
import 'package:yolighttransfer/services/discovery/multi_network_udp_discovery_service.dart';
import 'package:yolighttransfer/services/device/device_name_service.dart';
import 'package:yolighttransfer/services/file_picker/file_picker_factory.dart';
import 'package:yolighttransfer/services/network/firewall_checker.dart';
import 'package:yolighttransfer/services/font/font_manager.dart';
import 'package:yolighttransfer/services/http/http_transfer_manager.dart';
import 'package:yolighttransfer/services/transfer/transfer_log_manager.dart';
import 'package:yolighttransfer/services/config/app_config_service.dart';
import 'package:yolighttransfer/services/file/cache_cleanup_service.dart';
import 'package:yolighttransfer/widgets/file_receive_dialog.dart';
import 'package:yolighttransfer/services/config/version_service.dart';

void main() async {
  // 预加载字体
  WidgetsFlutterBinding.ensureInitialized();
  await FontManager.preloadFonts();
  
  // 初始化版本服务
  await VersionService().initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceManager()),
        ChangeNotifierProvider(create: (_) => TransferTaskManager()),
        ChangeNotifierProvider(create: (_) => TransferLogManager()),
        Provider(create: (context) => HttpTransferManager(
          logManager: context.read<TransferLogManager>(),
          taskManager: context.read<TransferTaskManager>(),
        )),
        Provider(create: (_) => AppConfigService()),
      ],
      child: const YoLightTransferApp(),
    ),
  );
}

class YoLightTransferApp extends StatelessWidget {
  const YoLightTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 配置系统UI
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    return MaterialApp(
      title: 'YoLightTransfer',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      // 添加字体回退配置
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 确保文本缩放比例正常
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child!,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // UDP 发现服务实例（应用前台时保持运行）
  MultiNetworkUdpDiscoveryService? _discovery;
  
  
  // HTTP 传输管理器实例
  HttpTransferManager? _httpTransferManager;
  
  // 传输日志管理器
  TransferLogManager? _logManager;

  @override
  void initState() {
    super.initState();
    // 延后到首帧后启动，确保 Provider 可用
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 初始化配置服务
      final configService = context.read<AppConfigService>();
      await configService.initialize();
      
      // 应用启动时清理过期的 cache 文件
      await _cleanupExpiredCache();
      
      // 执行网络诊断
      await _runNetworkDiagnostics();
      
      final manager = context.read<DeviceManager>();
      _discovery = MultiNetworkUdpDiscoveryService(manager);
      
      // 初始化传输日志管理器
      _logManager = context.read<TransferLogManager>();
      await _logManager!.initialize();
      
      // 初始化 HTTP 传输管理器
      _httpTransferManager = context.read<HttpTransferManager>();
      _httpTransferManager!.onLog = (message) {
        print(message);
      };
      
      // 设置文件接收确认回调
      _httpTransferManager!.onReceiveConfirmation = _handleFileTransferRequest;
      
      // 启动 HTTP 服务器（接收端）
      final httpServerStarted = await _httpTransferManager!.startServer(
        port: 30071,
        uploadDir: '/YoLightTransfer',
      );
      
      if (httpServerStarted) {
        print('=== HTTP服务器启动 ===');
        print('HTTP服务器已启动在端口: 30071');
        print('==================');
      } else {
        print('❌ HTTP服务器启动失败');
      }
      
      // 获取动态设备名称
      final deviceName = await DeviceNameService.getDeviceName();
      _discovery!.start(deviceName: deviceName, httpPort: 30071);
      
      // 应用启动时申请文件访问权限
      _requestFilePermissions();
    });
  }

  /// 清理过期的 cache 文件
  Future<void> _cleanupExpiredCache() async {
    try {
      print('🧹 应用启动时清理过期 cache...');
      
      // 清理 file_picker 的 cache 目录
      final deletedCount = await CacheCleanupService.cleanFilePickerCache();
      
      if (deletedCount > 0) {
        print('✅ 清理完成，删除了 $deletedCount 个过期文件');
      } else {
        print('✅ 没有过期文件需要清理');
      }
    } catch (e) {
      print('⚠️ 清理过期 cache 失败: $e');
    }
  }

  /// 执行网络诊断
  Future<void> _runNetworkDiagnostics() async {
    print('=== 启动网络诊断 ===');
    await FirewallChecker.showNetworkDiagnostics();
    print('=== 网络诊断完成 ===');
  }

  @override
  void dispose() {
    _discovery?.stop();
    _httpTransferManager?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 申请文件访问权限
  Future<void> _requestFilePermissions() async {
    try {
      final filePickerService = FilePickerFactory.create();
      if (filePickerService.requiresPermission) {
        final hasPermission = await filePickerService.hasPermission();
        if (!hasPermission) {
          await filePickerService.requestPermission();
        }
      }
    } catch (e) {
      // 权限申请失败不影响应用正常启动
      print('权限申请失败: $e');
    }
  }

  /// 处理文件传输请求
  Future<bool> _handleFileTransferRequest(
    String senderDeviceName,
    String fileName,
    int fileSize,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FileReceiveDialog(
        senderDeviceName: senderDeviceName,
        fileName: fileName,
        fileSize: fileSize,
        onAccept: () => Navigator.of(context).pop(true),
        onReject: () => Navigator.of(context).pop(false),
        onDismiss: () => Navigator.of(context).pop(false),
      ),
    );

    return result ?? false;
  }

  // 根据配置动态生成屏幕列表
  List<Widget> _getScreens(BuildContext context) {
    try {
      final configService = context.read<AppConfigService>();
      final enableTransferLogPage = configService.get<bool>(AppConfigService.enableTransferLogPage, true);
      
      final screens = <Widget>[
        const DeviceDiscoveryScreen(),
        if (enableTransferLogPage) const TransferLogScreen(),
        const ConfigScreen(), // 替换原来的设置页面为配置页面
        const ProfileScreen(),
      ];
      
      return screens;
    } catch (e) {
      // 如果配置服务未初始化，使用默认配置
      print('配置服务访问失败，使用默认配置: $e');
      return [
        const DeviceDiscoveryScreen(),
        const TransferLogScreen(), // 默认启用传输日志页面
        const ConfigScreen(),
        const ProfileScreen(),
      ];
    }
  }

  // 根据配置动态生成标题列表
  List<String> _getAppBarTitles(BuildContext context) {
    try {
      final configService = context.read<AppConfigService>();
      final enableTransferLogPage = configService.get<bool>(AppConfigService.enableTransferLogPage, true);
      
      final titles = <String>[
        '设备发现',
        if (enableTransferLogPage) '传输日志',
        '配置',
        '我的 [BETA]',
      ];
      
      return titles;
    } catch (e) {
      // 如果配置服务未初始化，使用默认配置
      print('配置服务访问失败，使用默认标题: $e');
      return [
        '设备发现',
        // '传输日志', // 默认不启用传输日志页面
        '配置',
        '我的 [BETA]',
      ];
    }
  }

  // 根据配置动态生成导航项
  List<_NavItemData> _getNavItems(BuildContext context) {
    try {
      final configService = context.read<AppConfigService>();
      final enableTransferLogPage = configService.get<bool>(AppConfigService.enableTransferLogPage, true);
      
      final items = <_NavItemData>[
        _NavItemData(icon: Icons.devices, label: '设备发现'),
        if (enableTransferLogPage) _NavItemData(icon: Icons.history, label: '传输日志'),
        _NavItemData(icon: Icons.settings, label: '配置'),
        _NavItemData(icon: Icons.person, label: '我的 [BETA]'),
      ];
      
      return items;
    } catch (e) {
      // 如果配置服务未初始化，使用默认配置
      print('配置服务访问失败，使用默认导航项: $e');
      return [
        _NavItemData(icon: Icons.devices, label: '设备发现'),
        _NavItemData(icon: Icons.history, label: '传输日志'), // 默认启用传输日志页面
        _NavItemData(icon: Icons.settings, label: '配置'),
        _NavItemData(icon: Icons.person, label: '我的 [BETA]'),
      ];
    }
  }

  // 根据配置动态生成底部导航项
  List<BottomNavigationBarItem> _getBottomNavItems(BuildContext context) {
    try {
      final configService = context.read<AppConfigService>();
      final enableTransferLogPage = configService.get<bool>(AppConfigService.enableTransferLogPage, true);
      
      final items = <BottomNavigationBarItem>[
        const BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: '设备发现',
        ),
        if (enableTransferLogPage)
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '传输日志',
          ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '配置',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '我的 [BETA]',
        ),
      ];
      
      return items;
    } catch (e) {
      // 如果配置服务未初始化，使用默认配置
      print('配置服务访问失败，使用默认底部导航项: $e');
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: '设备发现',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: '传输日志', // 默认启用传输日志页面
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '配置',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '我的 [BETA]',
        ),
      ];
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;

    // 动态获取屏幕列表和导航项
    final screens = _getScreens(context);
    final appBarTitles = _getAppBarTitles(context);
    final navItems = _getNavItems(context);
    final bottomNavItems = _getBottomNavItems(context);

    // 确保当前索引在有效范围内
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    if (isLargeScreen) {
      // 大屏布局 - 基于KT UI设计逻辑优化
      return Scaffold(
        body: Row(
          children: [
            // 侧边导航栏 - 与KT UI设计对齐
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 应用标题
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'YoLightTransfer',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  // 导航项
                  Expanded(
                    child: ListView.builder(
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final selected = index == _currentIndex;
                        return ListTile(
                          leading: Icon(
                            item.icon,
                            size: 24,
                            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          selected: selected,
                          selectedTileColor: theme.colorScheme.primary.withOpacity(0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.m),
                          ),
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 主内容区域
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(appBarTitles[_currentIndex]),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                body: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: screens[_currentIndex],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 小屏布局 - 使用 PageView 提供流畅的滑动切换
      return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitles[_currentIndex]),
          centerTitle: true,
          actions: _currentIndex == 1
              ? [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设置已保存')),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ]
              : null,
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), // 提供自然的滚动效果
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: bottomNavItems,
          backgroundColor: theme.colorScheme.surfaceContainer,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedFontSize: 12,
          unselectedFontSize: 12,
        ),
      );
    }
  }
}

// 补充此数据类定义（建议放在 _MainScreenState 前面/后面均可）
class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

// 单行icon+文本组件，选中有高亮
class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _RailItem({
    required this.icon,
    required this.label,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      height: 60, // 每项高度，可根据审美修改（一般48-72）
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: selected
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28), // 图标大一点
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18, // 更大字体
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
