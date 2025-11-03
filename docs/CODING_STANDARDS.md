# YoLightTransfer 项目编码规范

## 1. 概述

本文档定义了 YoLightTransfer 项目的统一编码规范，旨在确保代码质量、可维护性和团队协作效率。规范基于现有代码风格，为后续开发提供标准指导。

## 2. Dart/Flutter 编码规范

### 2.1 代码风格和格式化

#### 2.1.1 基础规范
- 使用 **2个空格** 缩进
- 行长度限制：**80个字符**
- 使用 **单引号** 表示字符串
- 类名使用 **PascalCase**
- 变量和方法名使用 **camelCase**
- 常量使用 **UPPER_CASE_WITH_UNDERSCORES**

#### 2.1.2 导入顺序
```dart
// 1. Dart SDK 导入
import 'dart:async';
import 'dart:io';

// 2. Flutter SDK 导入
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 第三方包导入
import 'package:provider/provider.dart';
import 'package:http/http.dart';

// 4. 项目内部导入（相对路径）
import '../models/device.dart';
import '../services/device_manager.dart';
import '../widgets/device_card.dart';
```

#### 2.1.3 注释规范
```dart
/// 类级别的文档注释
/// 
/// 描述类的用途和主要功能
/// 
/// 示例：
/// ```dart
/// final manager = DeviceManager();
/// await manager.initialize();
/// ```
class DeviceManager extends ChangeNotifier {
  // 单行注释使用双斜杠
  final List<Device> _devices = [];
  
  /// 方法级别的文档注释
  /// 
  /// [deviceName] 设备名称
  /// [ipAddress] IP地址
  /// 
  /// 返回 [bool] 添加是否成功
  bool addDevice(String deviceName, String ipAddress) {
    // 行内注释
    final device = Device(name: deviceName, ip: ipAddress);
    _devices.add(device);
    notifyListeners(); // 通知监听器更新
    return true;
  }
}
```

### 2.2 状态管理规范

#### 2.2.1 Provider 使用规范
```dart
// 正确示例
class TransferTaskManager extends ChangeNotifier {
  final List<TransferTask> _tasks = [];
  
  List<TransferTask> get tasks => List.unmodifiable(_tasks);
  
  void addTask(TransferTask task) {
    _tasks.add(task);
    notifyListeners(); // 状态变化后必须通知
  }
  
  void removeTask(TransferTask task) {
    _tasks.remove(task);
    notifyListeners();
  }
}

// 在 Widget 中使用
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final taskManager = context.watch<TransferTaskManager>();
    
    return ListView.builder(
      itemCount: taskManager.tasks.length,
      itemBuilder: (context, index) {
        final task = taskManager.tasks[index];
        return TransferTaskItem(task: task);
      },
    );
  }
}
```

#### 2.2.2 异步操作处理
```dart
class AppConfigService {
  /// 异步初始化方法
  /// 
  /// 返回 [Future<bool>] 初始化是否成功
  Future<bool> initialize() async {
    try {
      print('=== 配置服务初始化开始 ===');
      await _loadConfig();
      await _validateSettings();
      print('✅ 配置服务初始化完成');
      return true;
    } catch (e, stack) {
      print('❌ 配置服务初始化失败: $e');
      print('堆栈: $stack');
      return false;
    }
  }
}
```

### 2.3 组件设计规范

#### 2.3.1 Widget 命名和结构
```dart
// 有状态组件
class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});
  
  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  // 私有状态变量使用下划线前缀
  bool _isDiscovering = false;
  final List<DiscoveredDevice> _devices = [];
  
  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备发现'),
      ),
      body: _buildContent(),
    );
  }
  
  // 私有方法使用下划线前缀
  Widget _buildContent() {
    if (_isDiscovering) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) => DeviceCard(device: _devices[index]),
    );
  }
}
```

#### 2.3.2 主题和样式
```dart
// 使用主题系统
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6750A4),
      secondary: Color(0xFF625B71),
    ),
    fontFamily: FontManager.getAvailableFontFamily(),
  );
  
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD0BCFF),
      secondary: Color(0xFFCCC2DC),
    ),
  );
}
```

## 3. Python AI 训练规范

### 3.1 代码结构和模块化

#### 3.1.1 项目结构
```
AI_train/
├── src/
│   ├── __init__.py
│   ├── main.py              # 主程序入口
│   ├── data/
│   │   ├── __init__.py
│   │   ├── generator.py     # 数据生成
│   │   └── preprocessor.py  # 数据预处理
│   ├── models/
│   │   ├── __init__.py
│   │   ├── network_model.py # 模型定义
│   │   └── trainer.py       # 训练器
│   └── utils/
│       ├── __init__.py
│       ├── config.py        # 配置管理
│       └── metrics.py       # 评估指标
├── configs/
│   ├── train_config.json    # 训练配置
│   └── rtx4070_optimized.json
└── scripts/
    ├── accelerated_trainer.py
    └── auto_train.py
```

#### 3.1.2 类和方法命名
```python
# 类名使用 PascalCase
class NetworkQualityTrainer:
    """网络质量训练器完整流程"""
    
    def __init__(self, config: Config = None):
        """初始化训练器
        
        Args:
            config: 配置对象（默认为None时使用默认配置）
        """
        self.config = config or Config()
        self.data_generator = DataGenerator()
        self.preprocessor = DataPreprocessor()
        
    def generate_training_data(self, save_data: bool = True) -> Dict[str, Any]:
        """生成训练数据集
        
        Args:
            save_data: 是否保存生成的数据到文件
            
        Returns:
            包含生成数据和元数据的字典
        """
        print("\n" + "="*60)
        print("GENERATING TRAINING DATA")
        print("="*60)
        
        dataset = self.data_generator.generate_dataset(
            n_samples=self.config.data.dataset_size,
            scenario_weights=self.config.data.scenario_weights
        )
        
        return {
            'dataset': dataset,
            'stats': self._calculate_dataset_stats(dataset)
        }
    
    def _calculate_dataset_stats(self, dataset) -> Dict[str, Any]:
        """计算数据集统计信息（私有方法）"""
        return {
            'total_samples': len(dataset),
            'hotspot_recommendations': dataset['shouldRecommendHotspot'].value_counts().to_dict(),
        }
```

### 3.2 类型注解和文档

#### 3.2.1 类型注解规范
```python
from typing import Dict, List, Tuple, Optional, Any, Union

def preprocess_data(
    dataset: pd.DataFrame,
    test_size: float = 0.2,
    validation_size: float = 0.1
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, Any]:
    """预处理训练数据
    
    Args:
        dataset: 原始数据集
        test_size: 测试集比例
        validation_size: 验证集比例
        
    Returns:
        包含预处理数据的元组:
        - X_train: 训练特征
        - X_val: 验证特征  
        - X_test: 测试特征
        - y_train: 训练标签
        - y_val: 验证标签
        - y_test: 测试标签
        - scaler: 数据缩放器
    """
    # 实现代码
    pass
```

#### 3.2.2 配置管理
```python
class Config:
    """配置管理类"""
    
    def __init__(self, config_path: Optional[str] = None):
        """初始化配置
        
        Args:
            config_path: 配置文件路径，None时使用默认配置
        """
        self.data = DataConfig()
        self.training = TrainingConfig()
        self.model = ModelConfig()
        
        if config_path:
            self._load_from_file(config_path)
    
    def print_summary(self) -> None:
        """打印配置摘要"""
        print("=== 配置摘要 ===")
        print(f"数据集大小: {self.data.dataset_size}")
        print(f"训练轮数: {self.training.epochs}")
        print(f"学习率: {self.training.learning_rate}")
```

### 3.3 实验和模型管理

#### 3.3.1 实验记录
```python
def run_complete_pipeline(self, save_data: bool = True) -> Dict[str, Any]:
    """运行完整的训练和评估流程
    
    Args:
        save_data: 是否保存生成的数据
        
    Returns:
        完整的流程结果
    """
    print("="*80)
    print("STARTING COMPLETE AI NETWORK QUALITY TRAINING PIPELINE")
    print("="*80)
    
    try:
        # 步骤1: 生成数据
        data_results = self.generate_training_data(save_data=save_data)
        
        # 步骤2: 预处理数据
        X_train, X_val, X_test, y_train, y_val, y_test, scaler = self.preprocess_data(
            data_results['dataset']
        )
        
        # 步骤3: 训练模型
        training_results = self.train_model(X_train, X_val, X_test, y_train, y_val, y_test)
        
        # 步骤4: 评估模型
        evaluation_results = self.evaluate_model(X_test, y_test)
        
        # 编译最终结果
        final_results = {
            'data_generation': data_results,
            'training': training_results,
            'evaluation': evaluation_results,
            'config': self.config.to_dict()
        }
        
        return final_results
        
    except Exception as e:
        print(f"\nERROR: Pipeline failed with exception: {e}")
        raise
```

## 4. 项目结构和文件组织

### 4.1 目录结构标准

```
yolighttransfer/
├── lib/                          # Flutter 主代码
│   ├── main.dart                 # 应用入口
│   ├── config.yaml               # 应用配置
│   ├── ai/                       # AI 相关功能
│   ├── models/                   # 数据模型
│   ├── pages/                    # 页面组件
│   ├── services/                 # 业务服务
│   ├── theme/                    # 主题配置
│   ├── util/                     # 工具类
│   └── widgets/                  # 可复用组件
├── AI_train/                     # Python AI 训练
│   ├── src/                      # 源代码
│   ├── configs/                  # 训练配置
│   ├── scripts/                  # 训练脚本
│   └── checkpoints/              # 模型检查点
├── assets/                       # 静态资源
│   ├── config/                   # 配置文件
│   ├── front/                    # 前端资源
│   ├── images/                   # 图片资源
│   └── models/                   # 模型文件
├── docs/                         # 项目文档
├── test/                         # 测试代码
└── 各平台目录 (android/, ios/, etc.)
```

### 4.2 文件命名规范

- **Dart文件**: `snake_case.dart` (如: `device_discovery_screen.dart`)
- **Python文件**: `snake_case.py` (如: `data_generator.py`)
- **资源文件**: `kebab-case.ext` (如: `network-thresholds.json`)
- **配置文件**: 使用描述性名称 (如: `train_config.json`)

## 5. 版本控制和提交规范

### 5.1 Git 提交消息格式

基于项目实际提交历史，采用以下格式：

```
<类型>(<范围>): <主题>

<正文>

<页脚>
```

#### 5.1.1 提交类型（基于实际使用）
- `feat`: 新功能（最常用）
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具变动

#### 5.1.2 提交范围（基于实际项目结构）
- `hotspot`: 热点管理相关
- `network-testing`: 网络测试相关
- `android`: Android平台相关
- `training`: AI训练相关
- `data-collection`: 数据收集相关
- `transfer`: 文件传输相关
- `ai`: AI模块相关
- `tcp`: TCP协议相关
- `update`: 版本更新相关

#### 5.1.3 实际提交示例（基于项目历史）
```
feat(hotspot): 添加跨平台热点管理功能及相关页面

- 实现 Windows/Android 平台热点管理
- 添加热点状态监控组件
- 集成网络质量分析模块
```

```
feat(training): 增强多终端多线程自动训练逻辑并优化模型结构

- 实现多终端训练进度同步
- 优化模型隐藏层配置
- 添加训练进度共享机制
```

```
feat(network-testing): 增加网关网络测速模块及相关测试

- 实现网关网络质量检测
- 添加测速服务单元测试
- 优化网络数据收集逻辑
```

```
feat(android): 更新包名及构建配置，新增网关测速功能

- 更新应用包名为 cn.waveyo.yolighttransfer
- 配置 Android 10+ 最低版本支持
- 集成网关测速到 Android 平台
```

```
feat(test): 添加网络测试与 AI 模块的单元测试

- 实现 AI 网络顾问完整测试套件
- 添加网络数据收集器测试
- 覆盖主要业务逻辑边界情况
```

```
chore(tcp): 移除增强 TCP 客户端和服务器代码

- 清理过时的 TCP 传输实现
- 移除相关依赖和配置文件
- 优化项目结构
```

### 5.2 分支管理策略

- `main`: 主分支，稳定版本
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 热修复分支
- `release/*`: 发布分支

## 6. 功能开发指导规范

### 6.1 热点管理功能开发规范

#### 6.1.1 跨平台热点管理架构
```dart
// 使用工厂模式创建平台特定的热点管理器
class HotspotManagerFactory {
  static HotspotManager create() {
    if (Platform.isWindows) {
      return WindowsHotspotManager();
    } else if (Platform.isAndroid) {
      return AndroidHotspotManager();
    } else {
      return DefaultHotspotManager();
    }
  }
}

// 热点状态管理使用 Provider
class HotspotStateProvider extends ChangeNotifier {
  bool _isHotspotRunning = false;
  bool _isLoading = false;
  String _ssid = '';
  String _password = '';
  
  bool get isHotspotRunning => _isHotspotRunning;
  bool get isLoading => _isLoading;
  String get ssid => _ssid;
  String get password => _password;
  
  void setHotspotRunning(bool running) {
    _isHotspotRunning = running;
    notifyListeners();
  }
  
  void regenerateCredentials() {
    _ssid = 'YoLightTransfer_${DateTime.now().millisecondsSinceEpoch}';
    _password = _generateRandomPassword();
    notifyListeners();
  }
}
```

#### 6.1.2 权限处理规范
```dart
class HotspotPermissionHandler {
  /// 检查并请求热点相关权限
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Android 权限检查
        final hasPermission = await Permission.location.isGranted;
        if (!hasPermission) {
          final result = await Permission.location.request();
          return result.isGranted;
        }
        return true;
      } else if (Platform.isWindows) {
        // Windows 管理员权限检查
        return await _checkWindowsAdminPrivileges();
      }
      return true;
    } catch (e) {
      print('权限检查失败: $e');
      return false;
    }
  }
}
```

### 6.2 AI 网络质量分析开发规范

#### 6.2.1 AI 推理架构
```dart
class AINetworkAdvisor extends ChangeNotifier {
  final NetworkQualityAnalyzer _networkAnalyzer;
  final TFLiteNetworkEvaluator _tfliteEvaluator;
  
  /// 基于历史数据的防抖推荐机制
  Future<AIRecommendation> shouldRecommendHotspotWith(NetworkQuality quality) async {
    // 连续3次弱网检测才触发推荐
    _weakNetworkHistory.add(quality);
    if (_weakNetworkHistory.length > 3) {
      _weakNetworkHistory.removeAt(0);
    }
    
    // 检查用户拒绝冷却期
    if (_isInRejectionCooldown()) {
      return AIRecommendation(
        shouldRecommendHotspot: false,
        reason: '用户近期已拒绝推荐',
        networkQuality: quality,
      );
    }
    
    // 使用 TFLite 模型或规则引擎
    if (_tfliteEvaluator.isModelLoaded) {
      return await _getTFLiteRecommendation(quality);
    } else {
      return _getRuleBasedRecommendation(quality);
    }
  }
}
```

#### 6.2.2 多场景阈值配置
```dart
enum AIScene { general, manufacturing, education }

extension AISceneExtension on AIScene {
  double get bandwidthThreshold {
    switch (this) {
      case AIScene.manufacturing:
        return 0.8; // 制造车间对网络要求较低
      case AIScene.education:
        return 1.2; // 高校实验室对网络要求较高
      case AIScene.general:
      default:
        return 1.0; // 通用场景
    }
  }
}
```

### 6.3 多终端 AI 训练开发规范

#### 6.3.1 分布式训练架构
```python
class MultiTerminalTrainer:
    """多终端训练管理器"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.terminal_id = self._generate_simple_terminal_id()
        self.progress_file = os.path.join(self.cfg.data.models_dir, "shared_progress.json")
        
    def get_next_iteration(self) -> int:
        """获取下一个可用的迭代编号 - 支持多终端并发"""
        try:
            if os.path.exists(self.progress_file):
                with open(self.progress_file, 'r') as f:
                    progress_data = json.load(f)
            else:
                progress_data = {"total_iterations": 0, "terminals": {}}
            
            next_iter = progress_data["total_iterations"] + 1
            progress_data["total_iterations"] = next_iter
            progress_data["terminals"][self.terminal_id] = {
                "current_iteration": next_iter,
                "last_update": datetime.now().isoformat()
            }
            
            with open(self.progress_file, 'w') as f:
                json.dump(progress_data, f, indent=2)
            
            return next_iter
        except (json.JSONDecodeError, KeyError):
            # 文件损坏时重新开始
            return self._reset_progress_file()
```

#### 6.3.2 自动训练流程
```python
def auto_train_iter(n_iters: int = 1000, config_path: str = "configs/train_config.json"):
    """多终端多线程自动训练函数"""
    mt_trainer = MultiTerminalTrainer(config_path)
    cfg = mt_trainer.cfg
    
    print(f"🚀 启动多终端训练 - 终端ID: {mt_trainer.terminal_id}")
    
    for _ in range(n_iters):
        iteration = mt_trainer.get_next_iteration()
        
        print(f"\n🎯 开始训练迭代 #{iteration}")
        
        # 1. 数据生成
        generator = DataGenerator(seed=cfg.training.random_seed)
        raw_dataset = generator.generate_dataset(n_samples=cfg.data.dataset_size)
        
        # 2. 数据预处理
        preprocessor = DataPreprocessor()
        X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(
            raw_dataset,
            test_size=cfg.training.test_split,
            validation_size=cfg.training.validation_split,
            random_state=cfg.training.random_seed
        )
        
        # 3. 模型训练
        model = NetworkQualityModel(
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
        )
        
        trainer = ModelTrainer(model=model)
        trainer.setup_training(
            learning_rate=cfg.training.learning_rate,
            weight_decay=cfg.training.weight_decay
        )
        
        # 4. 保存模型
        model_path = mt_trainer.generate_model_path(iteration)
        model.save_model(model_path)
        print(f"✅ [{iteration}] 已保存模型: {model_path}")
```

### 6.4 网络测试和网关测速开发规范

#### 6.4.1 网关测速架构
```dart
class GatewaySpeedTestService {
  /// 执行网关网络质量测试
  Future<GatewaySpeedResult> testGatewaySpeed() async {
    try {
      print('=== 网关测速开始 ===');
      
      // 1. 获取网关信息
      final gatewayInfo = await _getGatewayInfo();
      
      // 2. 执行延迟测试
      final latency = await _testLatency(gatewayInfo.ip);
      
      // 3. 执行带宽测试
      final bandwidth = await _testBandwidth(gatewayInfo.ip);
      
      // 4. 计算网络质量评分
      final qualityScore = _calculateQualityScore(latency, bandwidth);
      
      print('✅ 网关测速完成');
      return GatewaySpeedResult(
        latency: latency,
        bandwidth: bandwidth,
        qualityScore: qualityScore,
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      print('❌ 网关测速失败: $e');
      print('堆栈: $stack');
      rethrow;
    }
  }
}
```

#### 6.4.2 Android 平台集成规范
```kotlin
// Android 端网关测速实现
class GatewaySpeedTestManager {
    fun testGatewaySpeed(): GatewaySpeedResult {
        // 使用 Android 网络 API 获取网关信息
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork
        val linkProperties = connectivityManager.getLinkProperties(network)
        
        val gatewayAddresses = linkProperties?.routes
            ?.filter { it.isDefaultRoute }
            ?.mapNotNull { it.gateway?.hostAddress }
        
        // 执行网络测试
        return performNetworkTests(gatewayAddresses?.firstOrNull())
    }
}
```

### 6.5 测试开发规范

#### 6.5.1 AI 模块测试规范
```dart
// test/ai/ai_network_advisor_test.dart
void main() {
  group('AINetworkAdvisor', () {
    late AINetworkAdvisor advisor;
    late MockNetworkQualityAnalyzer mockAnalyzer;
    late MockTFLiteNetworkEvaluator mockTFLiteEvaluator;
    
    setUp(() {
      mockAnalyzer = MockNetworkQualityAnalyzer();
      mockTFLiteEvaluator = MockTFLiteNetworkEvaluator();
      
      // 设置模拟推理行为
      when(() => mockTFLiteEvaluator.simulateInference(any()))
          .thenReturn(TFLiteInferenceResult(
            confidence: 0.7,
            qualityScore: 0.3,
            shouldRecommendHotspot: true,
            modelVersion: 'simulated_1.0.0',
          ));
      
      advisor = AINetworkAdvisor(
        networkAnalyzer: mockAnalyzer,
        tfliteEvaluator: mockTFLiteEvaluator,
      );
    });
    
    test('防抖机制测试', () async {
      final poorQuality = NetworkQuality(
        bandwidthMbps: 0.5,
        packetLossRate: 10.0,
        avgDelayMs: 150.0,
      );
      
      // 需要连续3次弱网才触发推荐
      var recommendation = await advisor.shouldRecommendHotspotWith(poorQuality);
      expect(recommendation.shouldRecommendHotspot, isFalse);
      
      recommendation = await advisor.shouldRecommendHotspotWith(poorQuality);
      expect(recommendation.shouldRecommendHotspot, isFalse);
      
      recommendation = await advisor.shouldRecommendHotspotWith(poorQuality);
      expect(recommendation.shouldRecommendHotspot, isTrue);
    });
  });
}
```

#### 6.5.2 Python 训练测试规范
```python
# tests/test_network_quality_trainer.py
class TestNetworkQualityTrainer:
    def test_complete_pipeline(self):
        """测试完整训练流程"""
        trainer = NetworkQualityTrainer()
        
        # 运行完整流程
        results = trainer.run_complete_pipeline(save_data=False)
        
        # 验证结果结构
        assert 'data_generation' in results
        assert 'training' in results
        assert 'evaluation' in results
        assert 'config' in results
        
        # 验证训练指标
        training_metrics = results['training']
        assert 'best_val_loss' in training_metrics
        assert training_metrics['best_val_loss'] < 1.0  # 合理的损失值
```

## 7. 文档编写规范

### 7.1 代码注释标准

#### 7.1.1 Dart 注释
```dart
/// 传输任务管理器
/// 
/// 负责管理文件传输任务的队列和状态
/// 支持等待状态和手动触发传输
class TransferTaskManager extends ChangeNotifier {
  final List<TransferTask> _tasks = [];
  
  /// 获取所有活跃任务
  List<TransferTask> get tasks => List.unmodifiable(_tasks);
  
  /// 添加等待传输的任务
  /// 
  /// [file] 文件信息
  /// [targetDevice] 目标设备
  void addWaitingTask(FileInfo file, DiscoveredDevice targetDevice) {
    // 实现代码
  }
}
```

#### 7.1.2 Python 注释
```python
class NetworkQualityModel(nn.Module):
    """网络质量分析模型
    
    基于多层感知机的网络质量评估模型，输出：
    - 热点推荐概率
    - 网络质量评分
    - 预测置信度
    """
    
    def __init__(self, input_size: int, hidden_sizes: List[int], dropout_rate: float = 0.2):
        """初始化模型
        
        Args:
            input_size: 输入特征维度
            hidden_sizes: 隐藏层大小列表
            dropout_rate: Dropout 比率
        """
        super().__init__()
        self.layers = self._build_layers(input_size, hidden_sizes, dropout_rate)
```

### 6.2 API 文档规范

## 设备发现服务 API

### discoverDevices()

发现局域网内的可用设备。

**参数**: 无

**返回**: `Future<List<DiscoveredDevice>>`

**示例**:
```dart
final devices = await discoveryService.discoverDevices();
for (final device in devices) {
  print('发现设备: ${device.name} (${device.ip})');
}
```

**错误**:
- `NetworkException`: 网络连接失败
- `DiscoveryTimeoutException`: 发现超时


## 7. 测试和质量保证

### 7.1 测试规范

#### 7.1.1 单元测试
```dart
// test/services/transfer_task_manager_test.dart
void main() {
  group('TransferTaskManager', () {
    late TransferTaskManager manager;
    
    setUp(() {
      manager = TransferTaskManager();
    });
    
    test('添加等待任务', () {
      final file = FileInfo(name: 'test.txt', size: 1024);
      final device = DiscoveredDevice(name: 'Test Device', ip: '192.168.1.100');
      
      manager.addWaitingTask(file, device);
      
      expect(manager.waitingTasks, hasLength(1));
      expect(manager.waitingTasks.first.fileName, 'test.txt');
    });
  });
}
```

#### 7.1.2 集成测试
```dart
// test/integration/transfer_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('完整的文件传输流程', (tester) async {
    // 启动应用
    await tester.pumpWidget(const YoLightTransferApp());
    
    // 模拟设备发现
    await tester.tap(find.text('设备发现'));
    await tester.pumpAndSettle();
    
    // 验证设备列表显示
    expect(find.text('Test Device'), findsOneWidget);
  });
}
```

#### 7.1.3 Python 测试
```python
# tests/test_network_quality_trainer.py
import pytest
from src.main import NetworkQualityTrainer
from src.utils.config import Config

class TestNetworkQualityTrainer:
    """网络质量训练器测试"""
    
    def test_initialization(self):
        """测试训练器初始化"""
        trainer = NetworkQualityTrainer()
        assert trainer.config is not None
        assert trainer.data_generator is not None
    
    def test_data_generation(self):
        """测试数据生成"""
        trainer = NetworkQualityTrainer()
        data_results = trainer.generate_training_data(save_data=False)
        
        assert 'dataset' in data_results
        assert 'stats' in data_results
        assert len(data_results['dataset']) > 0
```

### 7.2 代码质量检查

#### 7.2.1 Dart 代码检查
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # 启用推荐的代码质量规则
    avoid_print: false  # 允许调试输出
    prefer_single_quotes: true
    always_declare_return_types: true
    avoid_dynamic_calls: true
```

#### 7.2.2 Python 代码检查
```toml
# pyproject.toml
[tool.black]
line-length = 88
target-version = ['py38']

[tool.mypy]
python_version = "3.8"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

## 8. 错误处理和日志规范

### 8.1 错误处理模式

#### 8.1.1 Dart 错误处理
```dart
class HttpTransferManager {
  /// 启动 HTTP 服务器
  Future<bool> startServer({required int port, required String uploadDir}) async {
    try {
      print('=== HTTP服务器启动 ===');
      // 服务器启动逻辑
      print('HTTP服务器已启动在端口: $port');
      return true;
    } catch (e, stack) {
      print('❌ HTTP服务器启动失败: $e');
      print('堆栈: $stack');
      return false;
    }
  }
  
  /// 处理文件传输
  Future<void> transferFile(FileInfo file, String targetUrl) async {
    try {
      // 传输逻辑
      await _uploadFile(file, targetUrl);
    } on SocketException catch (e) {
      print('网络连接错误: $e');
      rethrow;
    } on HttpException catch (e) {
      print('HTTP协议错误: $e');
      rethrow;
    } catch (e) {
      print('未知错误: $e');
      rethrow;
    }
  }
}
```

#### 8.1.2 Python 错误处理
```python
def run_complete_pipeline(self, save_data: bool = True) -> Dict[str, Any]:
    """运行完整的训练和评估流程"""
    print("="*80)
    print("STARTING COMPLETE AI NETWORK QUALITY TRAINING PIPELINE")
    print("="*80)
    
    try:
        # 训练流程
        data_results = self.generate_training_data(save_data=save_data)
        # ... 其他步骤
        
        return final_results
        
    except KeyboardInterrupt:
        print("\nTraining interrupted by user")
        raise
    except Exception as e:
        print(f"\nERROR: Pipeline failed with exception: {e}")
        raise
```

### 8.2 日志规范

#### 8.2.1 日志级别
- `✅`: 成功操作
- `❌`: 错误和失败
- `⚠️`: 警告信息
- `🧹`: 清理操作
- `===`: 重要流程开始/结束

#### 8.2.2 日志格式
```dart
// 应用启动日志
print('=== 应用启动调试 ===');
print('平台: ${Platform.operatingSystem}');
print('版本: ${Platform.version}');

// 成功操作
print('✅ Flutter绑定初始化完成');
print('✅ 字体预加载完成');

// 错误处理
print('❌ 应用启动失败: $e');
print('堆栈: $stack');

// 警告信息
print('⚠️ 清理过期 cache 失败: $e');
```

## 9. 性能优化规范

### 9.1 Flutter 性能优化

#### 9.1.1 列表优化
```dart
// 使用 ListView.builder 优化长列表
ListView.builder(
  itemCount: devices.length,
  itemBuilder: (context, index) => DeviceCard(device: devices[index]),
)

// 使用 const 构造函数优化重建
const DeviceCard({required this.device});
```

#### 9.1.2 状态管理优化
```dart
// 使用 Consumer 精确重建
Consumer<TransferTaskManager>(
  builder: (context, taskManager, child) {
    return ListView.builder(
      itemCount: taskManager.tasks.length,
      itemBuilder: (context, index) => TransferTaskItem(
        task: taskManager.tasks[index],
      ),
    );
  },
)
```

### 9.2 Python 性能优化

#### 9.2.1 数据处理优化
```python
def preprocess_data(self, dataset: pd.DataFrame) -> tuple:
    """预处理训练数据（优化版本）"""
    # 使用向量化操作替代循环
    features = dataset[['bandwidthMbps', 'avgDelayMs', 'packetLossRate']].values
    labels = dataset[['shouldRecommendHotspot', 'qualityScore', 'confidence']].values
    
    # 使用 sklearn 的预处理管道
    from sklearn.pipeline import Pipeline
    from sklearn.preprocessing import StandardScaler
    
    pipeline = Pipeline([
        ('scaler', StandardScaler())
    ])
    
    return pipeline.fit_transform(features), labels
```

## 10. 安全规范

### 10.1 数据传输安全

#### 10.1.1 文件传输安全
```dart
class HttpTransferManager {
  /// 验证文件传输请求
  bool _validateTransferRequest(String senderDeviceName, String fileName, int fileSize) {
    // 验证文件大小限制
    if (fileSize > _maxFileSize) {
      print('❌ 文件大小超出限制: $fileSize');
      return false;
    }
    
    // 验证文件类型
    if (!_isAllowedFileType(fileName)) {
      print('❌ 不支持的文件类型: $fileName');
      return false;
    }
    
    return true;
  }
}
```

#### 10.1.2 权限管理
```dart
class FilePickerFactory {
  /// 申请文件访问权限
  static Future<bool> requestFilePermissions() async {
    try {
      final filePickerService = create();
      if (filePickerService.requiresPermission) {
        final hasPermission = await filePickerService.hasPermission();
        if (!hasPermission) {
          return await filePickerService.requestPermission();
        }
      }
      return true;
    } catch (e) {
      print('权限申请失败: $e');
      return false;
    }
  }
}
```

## 11. 附录

### 11.1 常用工具和命令

#### 11.1.1 Flutter 开发工具
```bash
# 代码格式化
flutter format lib/

# 静态分析
flutter analyze

# 运行测试
flutter test

# 构建应用
flutter build apk --release
```

#### 11.1.2 Python 开发工具
```bash
# 代码格式化
black AI_train/src/

# 类型检查
mypy AI_train/src/

# 运行测试
pytest AI_train/tests/

# 安装依赖
cd AI_train && pip install -e .
```

### 11.2 参考资料

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言指南](https://dart.dev/guides/language)
- [Python PEP 8](https://peps.python.org/pep-0008/)
- [Git 提交消息规范](https://www.conventionalcommits.org/)

---

**最后更新**: 2025年1月3日  
**维护者**: YoLightTransfer 开发团队
