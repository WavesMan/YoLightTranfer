# AI Network Quality Analysis

基于深度学习的网络质量分析与热点推荐AI模型训练项目。

## 📋 项目概述

本项目提供了一个完整的AI模型训练框架，用于分析网络质量并智能推荐是否开启热点。模型基于三个核心网络特征进行预测：

### 输入特征
- **带宽 (bandwidthMbps)** - 网络带宽（Mbps）
- **延迟 (avgDelayMs)** - 平均往返延迟（毫秒）  
- **丢包率 (packetLossRate)** - 数据包丢失率（%）

### 输出预测
- **置信度 (confidence)** - 模型预测的置信度（0.0-1.0）
- **质量评分 (qualityScore)** - 网络质量评分（0.0-1.0）
- **热点推荐 (shouldRecommendHotspot)** - 是否推荐开启热点

## 🏗️ 项目架构

```
AI_train/
├── src/                          # 源代码目录
│   ├── data/                     # 数据处理模块
│   │   ├── collector.py          # 数据收集器
│   │   ├── generator.py          # 模拟数据生成器
│   │   └── preprocessor.py       # 数据预处理器
│   ├── models/                   # 模型模块
│   │   ├── network_model.py      # 神经网络模型
│   │   └── trainer.py           # 模型训练器
│   ├── utils/                    # 工具模块
│   │   ├── config.py            # 配置管理
│   │   └── metrics.py           # 评估指标
│   └── main.py                  # 主程序入口
├── scripts/                      # 脚本目录
│   ├── train_model.py           # 基础训练脚本
│   ├── auto_train.py            # 多终端自动训练脚本
│   ├── model_merger.py          # 模型合并监听器
│   ├── accelerated_trainer.py   # 加速训练器
│   └── test_pipeline.py         # 测试管道
├── data/                         # 数据目录
│   ├── raw/                     # 原始数据
│   ├── processed/               # 处理后的数据
│   └── models/                  # 训练好的模型
├── notebooks/                    # Jupyter笔记本
├── tests/                        # 测试目录
├── pyproject.toml               # 项目配置
├── requirements.txt             # 依赖列表
└── README.md                    # 项目文档
```

## 🚀 快速开始

### 环境要求

- Python 3.8+
- CUDA 13.0 (推荐用于GPU训练)
- uv 包管理器

### 安装依赖

```bash
# 使用uv安装依赖
uv sync

# 或者使用pip
pip install -r requirements.txt
```

### 快速训练

```bash
# 使用默认配置训练模型
python scripts/train_model.py

# 使用自定义配置训练
python scripts/train_model.py \
  --dataset-size 5000 \
  --epochs 50 \
  --batch-size 64 \
  --learning-rate 0.0005
```

### 使用主程序

```bash
# 运行完整训练管道
python src/main.py

# 使用配置文件
python src/main.py --config config.json
```

### 多终端并行训练

项目支持多终端并行训练，让模型在原有基础上不断累积优化：

```bash
# 启动多终端自动训练（可在多个终端同时运行）
uv run python scripts/auto_train.py

# 指定训练迭代次数
uv run python scripts/auto_train.py --n-iters 100
```

### 模型合并与累积优化

使用智能模型合并监听器，将多个小模型累积优化为最佳模型：

```bash
# 单次合并所有未合并的小模型
uv run python scripts/model_merger.py --mode single

# 持续监听模式（每5分钟检查一次新模型）
uv run python scripts/model_merger.py --mode continuous --interval 5
```

## 📊 模型架构

### 神经网络结构
- **输入层**: 3个特征（带宽、延迟、丢包率）
- **隐藏层**: 3层全连接神经网络 (64 → 32 → 16)
- **输出层**: 3个输出（热点概率、质量评分、置信度）
- **激活函数**: ReLU（隐藏层）、Sigmoid（输出层）
- **正则化**: Dropout (0.2) + Batch Normalization

### 训练策略
- **优化器**: AdamW
- **学习率调度**: ReduceLROnPlateau
- **早停机制**: 验证损失10个epoch无改善
- **损失函数**: 加权组合（热点分类 + 质量回归 + 置信度回归）

## ⚙️ 配置管理

项目使用统一的配置管理系统，支持JSON配置文件：

```json
{
  "project": {
    "name": "AI Network Quality Analysis",
    "version": "1.0.0",
    "author": "YoLightTransfer Team"
  },
  "model": {
    "input_size": 3,
    "hidden_sizes": [64, 32, 16],
    "dropout_rate": 0.2,
    "use_batch_norm": true
  },
  "training": {
    "learning_rate": 0.001,
    "batch_size": 32,
    "epochs": 100,
    "early_stopping_patience": 10
  },
  "data": {
    "dataset_size": 10000,
    "scenario_weights": {
      "strong_network": 0.4,
      "weak_network": 0.3,
      "critical_network": 0.3
    }
  }
}
```

## 📈 评估指标

### 分类指标（热点推荐）
- 准确率 (Accuracy)
- 精确率 (Precision) 
- 召回率 (Recall)
- F1分数 (F1-Score)
- AUC-ROC曲线
- 混淆矩阵

### 回归指标（质量评分 & 置信度）
- 均方误差 (MSE)
- 平均绝对误差 (MAE)
- R²决定系数
- 最大误差

### 综合评分
- 总体评分 (加权组合)

## 🚀 多终端训练与模型合并系统

### 系统概述

本项目实现了先进的多终端并行训练和智能模型合并系统，让模型能够在原有基础上不断累积优化，变得越来越强大。

### 系统架构

```
训练流程：
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  多终端训练     │    │  模型合并监听   │    │  累积优化模型   │
│  auto_train.py  │───▶│  model_merger.py│───▶│  best_model.pth │
└─────────────────┘    └─────────────────┘    └─────────────────┘
     │                         │                         │
     ▼                         ▼                         ▼
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│ 小模型目录   │         │ 合并记录     │         │ 参数统计     │
│ terminal_*/ │         │ merged.json │         │ statistics  │
└─────────────┘         └─────────────┘         └─────────────┘
```

### 多终端训练 (auto_train.py)

支持在多个终端同时运行训练，每个终端独立生成小模型：

```python
# 主要特性：
# - 自动生成唯一终端标识符
# - 共享进度跟踪
# - 避免模型覆盖
# - 实时路径生成

# 启动训练（可在多个终端同时运行）
uv run python scripts/auto_train.py

# 自定义训练参数
uv run python scripts/auto_train.py --n-iters 50 --config configs/train_config.json
```

### 智能模型合并 (model_merger.py)

将多个小模型智能合并到最佳模型中，实现累积优化：

```python
# 智能合并算法：
# - 渐进式融合：新模型参数以较小权重融入最佳模型
# - 学习率衰减：随着合并次数增加，融合权重逐渐降低
# - 避免覆盖：记录已合并模型，避免重复处理
# - 参数统计：记录模型参数变化和演化历史

# 单次合并
uv run python scripts/model_merger.py --mode single

# 持续监听（推荐）
uv run python scripts/model_merger.py --mode continuous --interval 5
```

### 智能合并算法

```python
def smart_merge(best_model, small_model, merge_count):
    # 动态学习率：随着合并次数增加，学习率降低
    learning_rate = 0.1 / (1 + merge_count * 0.05)
    
    # 渐进式参数融合
    for best_param, small_param in zip(best_model.parameters(), small_model.parameters()):
        best_param.data = best_param.data + learning_rate * (small_param.data - best_param.data)
    
    return best_model
```

### 文件结构说明

```
models/
├── shared_progress.json      # 多终端训练进度跟踪
├── merged_models.json        # 已合并模型记录
├── terminal_1761744172/      # 终端1模型目录
│   ├── model_iter_1_20251029_212335.pth
│   ├── model_iter_5_20251029_212443.pth
│   └── ...
├── terminal_1761744188/      # 终端2模型目录
│   └── ...
└── ...

checkpoints/
├── best_model.pth            # 累积优化的最佳模型
└── model_statistics.json     # 模型参数统计记录
```

### 系统优势

1. **避免模型覆盖**：每个模型都有唯一路径，不会相互覆盖
2. **累积优化**：模型在原有基础上不断改进，越来越强大
3. **多终端并行**：充分利用计算资源，加速训练过程
4. **智能合并**：渐进式融合算法，避免破坏已有知识
5. **完整记录**：详细的参数统计和合并历史记录

## 🔧 高级用法

### 数据生成

项目包含智能数据生成器，模拟三种网络场景：

1. **强网络** (40%) - 高带宽、低延迟、低丢包
2. **弱网络** (30%) - 低带宽、高延迟、高丢包  
3. **临界网络** (30%) - 中等网络条件

```python
from src.data.generator import DataGenerator

# 生成自定义数据集
generator = DataGenerator()
dataset = generator.generate_dataset(
    n_samples=10000,
    scenario_weights={
        "strong_network": 0.4,
        "weak_network": 0.3, 
        "critical_network": 0.3
    }
)
```

### 自定义模型

```python
from src.models.network_model import NetworkQualityModel

# 创建自定义模型
model = NetworkQualityModel(
    input_size=3,
    hidden_sizes=(128, 64, 32),
    dropout_rate=0.3,
    use_batch_norm=True
)
```

### 实时预测

```python
# 加载训练好的模型
model = NetworkQualityModel.load_model("models/final_model.pth")

# 进行预测
network_data = np.array([[25.5, 85.2, 2.1]])  # 带宽, 延迟, 丢包率
predictions = model.predict(network_data)

print(f"热点推荐概率: {predictions['hotspot_probability'][0]:.3f}")
print(f"网络质量评分: {predictions['quality_score'][0]:.3f}")
print(f"模型置信度: {predictions['confidence'][0]:.3f}")
```

## 🧪 测试与验证

运行测试套件：

```bash
# 运行单元测试
python -m pytest tests/

# 运行模型验证
python scripts/evaluate_model.py --model models/final_model.pth
```

## 📁 输出文件

### 基础训练输出

- `models/final_model.pth` - 训练好的模型权重
- `models/training_report.json` - 训练过程报告
- `models/evaluation_report.json` - 评估结果报告  
- `models/training_history.png` - 训练历史图表
- `models/confusion_matrix.png` - 混淆矩阵
- `models/roc_curve.png` - ROC曲线
- `data/processed/training_dataset.csv` - 训练数据集

### 多终端训练系统输出

- `checkpoints/best_model.pth` - 累积优化的最佳模型
- `checkpoints/model_statistics.json` - 模型参数统计记录
- `models/shared_progress.json` - 多终端训练进度跟踪
- `models/merged_models.json` - 已合并模型记录
- `models/terminal_*/` - 各终端小模型目录
  - `model_iter_{n}_{timestamp}.pth` - 唯一命名的模型文件

## 🔄 持续改进

### 短期目标 (1-2周)
- [ ] 建立数据收集管道
- [ ] 收集初始训练数据集 (1000+样本)
- [ ] 训练基础模型并集成到应用中

### 中期目标 (1个月)  
- [ ] 扩大数据集规模
- [ ] 优化模型性能
- [ ] 实现在线学习能力

### 长期目标 (3个月)
- [ ] 多场景模型适配
- [ ] 个性化推荐优化
- [ ] 模型自动更新机制

## 🤝 贡献指南

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

YoLightTransfer Team - team@yolighttransfer.com

项目链接: [https://github.com/YoLightTransfer/AI_train](https://github.com/YoLightTransfer/AI_train)
