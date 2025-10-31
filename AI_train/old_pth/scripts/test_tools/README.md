# 测试工具套件

本项目提供了一套完整的模型测试工具，用于全面评估训练好的网络质量分析模型。

## 📁 工具目录结构

```
scripts/test_tools/
├── evaluate_model.py          # 模型性能评估工具
├── test_predictions.py        # 实时预测测试工具
├── generalization_test.py     # 泛化能力测试工具
└── README.md                  # 使用说明文档
```

## 🛠️ 工具功能说明

### 1. 模型性能评估工具 (`evaluate_model.py`)

**功能**: 全面评估模型在测试集上的性能表现

**主要特性**:
- 分类指标评估（准确率、精确率、召回率、F1分数、AUC-ROC）
- 回归指标评估（MAE、R²、最大误差）
- 混淆矩阵和ROC曲线分析
- 可视化性能图表
- 详细评估报告生成

**使用方法**:
```bash
# 基础使用
python scripts/test_tools/evaluate_model.py

# 指定模型和测试样本数
python scripts/test_tools/evaluate_model.py \
  --model checkpoints/best_model.pth \
  --test-samples 2000

# 使用自定义配置
python scripts/test_tools/evaluate_model.py \
  --config configs/train_config.json
```

**输出文件**:
- `evaluation_results/evaluation_report_YYYYMMDD_HHMMSS.json` - 详细评估报告
- `evaluation_results/performance_plots_YYYYMMDD_HHMMSS.png` - 性能图表

### 2. 实时预测测试工具 (`test_predictions.py`)

**功能**: 测试模型在不同网络场景下的实时预测表现

**主要特性**:
- 多种预设测试场景（强网络、弱网络、临界网络、边界测试）
- 决策合理性分析
- 交互式测试模式
- 预测一致性分析
- 决策分布统计

**使用方法**:
```bash
# 全面测试模式
python scripts/test_tools/test_predictions.py

# 交互式测试模式
python scripts/test_tools/test_predictions.py --mode interactive

# 指定模型
python scripts/test_tools/test_predictions.py --model checkpoints/best_model.pth
```

**输出文件**:
- `prediction_results/prediction_report_YYYYMMDD_HHMMSS.json` - 预测测试报告

### 3. 泛化能力测试工具 (`generalization_test.py`)

**功能**: 测试模型在不同数据分布上的泛化能力

**主要特性**:
- 多种数据分布偏移测试
- 性能稳定性分析
- 性能下降评估
- 泛化能力评级
- 改进建议生成

**使用方法**:
```bash
# 基础使用
python scripts/test_tools/generalization_test.py

# 指定测试样本数
python scripts/test_tools/generalization_test.py --samples 1000

# 使用自定义配置
python scripts/test_tools/generalization_test.py \
  --model checkpoints/best_model.pth \
  --config configs/train_config.json
```

**输出文件**:
- `generalization_results/generalization_report_YYYYMMDD_HHMMSS.json` - 泛化能力报告

## 🎯 测试流程建议

### 第一阶段：基础性能评估
```bash
# 1. 评估模型在标准测试集上的性能
python scripts/test_tools/evaluate_model.py --test-samples 1000

# 2. 测试实时预测能力
python scripts/test_tools/test_predictions.py
```

### 第二阶段：泛化能力验证
```bash
# 3. 验证模型在不同数据分布上的表现
python scripts/test_tools/generalization_test.py --samples 500
```

### 第三阶段：深入分析
```bash
# 4. 使用交互模式进行针对性测试
python scripts/test_tools/test_predictions.py --mode interactive
```

## 📊 评估指标说明

### 分类指标（热点推荐）
- **准确率**: 正确预测的比例
- **精确率**: 推荐热点中真正需要热点的比例
- **召回率**: 需要热点的场景中被正确推荐的比例
- **F1分数**: 精确率和召回率的调和平均
- **AUC-ROC**: 模型区分能力的综合指标

### 回归指标（质量评分 & 置信度）
- **MAE**: 平均绝对误差
- **R²**: 决定系数，表示模型解释的方差比例
- **最大误差**: 预测值与真实值的最大差异

### 泛化能力指标
- **性能稳定性**: 在不同分布上性能的一致性
- **性能下降**: 相对于标准分布的性能损失
- **决策一致性**: 相似场景下决策的稳定性

## 💡 性能改进建议

根据测试结果，工具会提供针对性的改进建议：

### 如果热点推荐性能不佳：
- 检查数据平衡性
- 增加模型复杂度
- 调整分类阈值

### 如果回归预测性能较低：
- 优化回归损失函数权重
- 增加训练数据量
- 调整网络架构

### 如果泛化能力不足：
- 使用数据增强技术
- 增加正则化
- 使用更复杂的模型架构

## 🔧 高级用法

### 批量测试多个模型
```bash
# 可以编写脚本批量测试多个模型版本
for model in models/*.pth; do
    echo "测试模型: $model"
    python scripts/test_tools/evaluate_model.py --model "$model"
done
```

### 集成到CI/CD流程
```bash
# 在自动化流程中运行测试
python scripts/test_tools/evaluate_model.py --test-samples 500
if [ $? -eq 0 ]; then
    echo "✅ 模型测试通过"
else
    echo "❌ 模型测试失败"
    exit 1
fi
```

## 📝 注意事项

1. **确保模型文件存在**: 测试前请确认模型文件路径正确
2. **足够的测试样本**: 建议使用至少500个测试样本以获得可靠结果
3. **结果解读**: 结合多个指标综合评估模型性能
4. **改进迭代**: 根据测试结果持续优化模型和训练策略

## 🆘 故障排除

### 常见问题：
1. **模型加载失败**: 检查模型文件路径和格式
2. **内存不足**: 减少测试样本数量
3. **依赖缺失**: 确保安装了所有必要的Python包

### 获取帮助：
如果遇到问题，请检查：
- 模型文件完整性
- 配置文件正确性
- Python环境依赖
- 输出目录权限

---

**使用这些工具，您可以全面了解模型的性能表现，发现潜在问题，并制定有效的改进策略。**
