# YoLightTransfer AI训练系统

网络质量分析模型的渐进式训练系统，专门针对不确定扰动训练问题进行优化。

## 项目概述

本项目旨在解决用户发现的训练问题：**加入不确定扰动训练2k轮+（2k+迭代，每次迭代至多100次学习）后，模型性能反而没有原过拟合模型优秀**。通过分析当前训练方式与数据生成方式的问题，我们设计了一套完整的渐进式训练系统。

## 核心问题分析

### 当前问题识别
1. **扰动训练实现问题**：不确定扰动的引入方式可能不合理
2. **数据生成质量问题**：训练数据的分布和特征工程需要优化
3. **训练策略问题**：超参数设置和训练流程需要改进
4. **模型泛化能力**：需要平衡过拟合和泛化性能

### 解决方案
- **渐进式训练策略**：分阶段训练，逐步增加数据复杂度和模型复杂度
- **硬件自适应系统**：根据硬件配置自动优化训练参数
- **多任务学习**：同时优化热点概率、质量评分和置信度
- **智能监控分析**：实时监控训练过程，提供优化建议

## 项目结构

```
YoLightTransfer/
├── src/                          # 源代码目录
│   ├── onnx_model/               # ONNX模型定义
│   │   ├── model_builder.py      # 模型构建器
│   │   └── network_quality_model.py # 网络质量模型
│   ├── data/                     # 数据处理模块
│   │   ├── generator.py          # 数据生成器
│   │   ├── preprocessor.py       # 数据预处理
│   │   └── loader.py            # 数据加载器
│   ├── onnx_trainer/            # 训练器模块
│   │   ├── trainer.py           # 基础训练器
│   │   └── progressive_manager.py # 渐进式训练管理器
│   ├── hardware/                # 硬件自适应系统
│   │   ├── detector.py          # 硬件检测器
│   │   ├── adaptor.py           # 硬件适配器
│   │   └── benchmark.py         # 性能基准测试
│   └── utils/                   # 工具模块
│       └── visualization.py     # 可视化工具
├── configs/                     # 配置文件
│   ├── train_config.json        # 默认训练配置
│   ├── rtx4090_25g_optimized.json # 4090优化配置
│   └── rtx4070_optimized.json   # 4070优化配置
├── checkpoints/                 # 模型检查点
├── data/                        # 数据目录
├── reports/                     # 训练报告
├── training_results/           # 训练结果
├── evaluation_results/         # 评估结果
└── main.py                     # 主程序
```

## 快速开始

### 环境要求
- Python 3.8+
- ONNX Runtime
- NumPy, Pandas, Matplotlib, Plotly
- 可选：CUDA支持的GPU（推荐）

### 安装依赖
```bash
pip install onnxruntime numpy pandas matplotlib plotly
```

### 基本使用

1. **显示系统信息**
```bash
python main.py --mode info
```

2. **生成训练数据**
```bash
python main.py --mode generate_data --samples 10000
```

3. **使用默认配置训练**
```bash
python main.py --mode train
```

4. **使用特定配置训练**
```bash
python main.py --mode train --config configs/rtx4090_25g_optimized.json
```

5. **评估模型**
```bash
python main.py --mode evaluate --model checkpoints/best_model.onnx
```

## 配置文件说明

### 默认配置 (train_config.json)
- 适用于通用硬件环境
- 平衡性能和资源消耗
- 适合初次实验和测试

### RTX 4090 25GB优化配置
- **模型复杂度**：高（4层隐藏层：128-64-32-16）
- **批次大小**：256-512（动态调整）
- **数据规模**：50,000样本
- **训练轮次**：300轮（5阶段渐进式）
- **精度模式**：混合精度（float16）
- **优化特性**：Tensor Core优化、CUDA加速

### RTX 4070优化配置
- **模型复杂度**：中（4层隐藏层：96-48-24-12）
- **批次大小**：128-256（动态调整）
- **数据规模**：30,000样本
- **训练轮次**：200轮（4阶段渐进式）
- **精度模式**：混合精度（float16）

## 渐进式训练策略

### 训练阶段设计
1. **预热阶段**：小数据集高学习率快速收敛
2. **高速训练**：中等数据集标准参数训练
3. **精细调优**：完整数据集低学习率微调
4. **最终精炼**：超低学习率优化（可选）

### 多任务学习
- **热点概率**（权重0.4）：网络热点推荐概率
- **质量评分**（权重0.4）：综合网络质量评估
- **置信度**（权重0.2）：预测可靠性评估

## 硬件自适应特性

### 自动检测和优化
- **CPU性能检测**：核心数、频率、缓存
- **GPU性能检测**：显存、计算能力、Tensor Core
- **内存优化**：自动调整批次大小和缓存策略
- **精度优化**：根据硬件能力选择最佳精度模式

### 性能基准测试
- 矩阵运算性能测试
- 内存带宽测试
- 推理速度测试
- 综合性能评分

## 数据生成和处理

### 网络质量特征
- 信号强度指标
- 网络延迟特征
- 带宽利用率
- 连接稳定性
- 干扰水平评估

### 数据增强
- 随机噪声注入
- 特征扰动
- 数据重采样
- 异常值处理

## 监控和可视化

### 实时监控
- 训练损失曲线
- 验证性能指标
- 硬件利用率
- 内存使用情况

### 可视化报告
- 训练历史图表
- 性能对比分析
- 特征重要性分析
- 预测结果可视化

## 性能优化建议

### 针对当前问题的优化
1. **扰动训练改进**：渐进式引入扰动，避免过早过拟合
2. **数据质量提升**：增强数据多样性，改善特征工程
3. **训练策略调整**：动态学习率调度，早停机制优化
4. **模型结构优化**：平衡模型复杂度和泛化能力

### 硬件特定优化
- **高性能GPU**：利用大批次训练和混合精度
- **中等GPU**：优化内存使用，平衡速度和精度
- **CPU训练**：优化数据加载，减少IO瓶颈

## 故障排除

### 常见问题
1. **内存不足**：减小批次大小或使用数据流式加载
2. **训练不稳定**：调整学习率或启用梯度裁剪
3. **性能不佳**：检查硬件配置，使用合适的配置文件
4. **模型不收敛**：检查数据质量，调整模型复杂度

### 调试工具
```python
# 启用详细日志
import logging
logging.basicConfig(level=logging.DEBUG)

# 性能分析
from src.hardware.benchmark import PerformanceBenchmark
benchmark = PerformanceBenchmark()
results = benchmark.run_comprehensive_benchmark()
```

## 扩展和定制

### 添加新的硬件配置
在`configs/`目录下创建新的JSON配置文件，参考现有模板。

### 自定义模型结构
修改`src/onnx_model/model_builder.py`中的模型定义。

### 添加新的训练策略
扩展`src/onnx_trainer/progressive_manager.py`中的训练逻辑。

## 许可证

本项目采用MIT许可证。

## 贡献指南

欢迎提交Issue和Pull Request来改进本项目。

## 联系方式

如有问题或建议，请通过项目Issue页面联系。

---

**注意**：本项目仍在积极开发中，API可能会发生变化。建议定期更新到最新版本。
