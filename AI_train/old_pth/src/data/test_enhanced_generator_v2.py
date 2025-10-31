"""
增强版测试脚本 - 测试改进后的数据生成器破坏拟合曲线的效果
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import pandas as pd
from generator import DataGenerator
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix


def test_enhanced_generator():
    """测试增强后的数据生成器效果"""
    print("=== 增强数据生成器破坏拟合曲线测试 ===\n")
    
    # 测试不同的不确定性水平
    for uncertainty in [0.0, 0.5, 1.0]:
        print(f"测试不确定性水平: {uncertainty}")
        generator = DataGenerator(uncertainty_level=uncertainty, seed=42)
        
        # 生成各种类型的样本
        regular_data = generator.generate_dataset(n_samples=500, include_mixed_scenarios=True)
        conflict_data = generator.generate_conflict_samples(n_samples=100)
        boundary_data = generator.generate_decision_boundary_samples(n_samples=100)
        
        # 合并数据集
        combined_data = pd.concat([regular_data, conflict_data, boundary_data], ignore_index=True)
        
        print(f"  总样本数: {len(combined_data)}")
        print(f"  常规样本: {len(regular_data)}")
        print(f"  冲突样本: {len(conflict_data)}")
        print(f"  边界样本: {len(boundary_data)}")
        
        # 统计信息
        print(f"  平均推荐概率: {combined_data['recommendationProbability'].mean():.3f}")
        print(f"  平均置信度: {combined_data['confidence'].mean():.3f}")
        print(f"  平均质量分数: {combined_data['qualityScore'].mean():.3f}")
        
        # 模糊案例统计
        ambiguous_cases = combined_data[
            (combined_data['recommendationProbability'] > 0.4) & 
            (combined_data['recommendationProbability'] < 0.6)
        ]
        print(f"  模糊案例数（概率0.4-0.6）: {len(ambiguous_cases)} ({len(ambiguous_cases)/len(combined_data)*100:.1f}%)")
        
        # 边界样本统计
        boundary_cases = combined_data[combined_data['scenario'] == 'boundary']
        if len(boundary_cases) > 0:
            print(f"  边界样本平均概率: {boundary_cases['recommendationProbability'].mean():.3f}")
            print(f"  边界样本平均置信度: {boundary_cases['confidence'].mean():.3f}")
        
        print()


def test_model_performance_with_enhanced_data():
    """测试使用增强数据训练模型的性能"""
    print("=== 模型性能测试（使用增强数据） ===\n")
    
    # 使用中等不确定性水平生成训练数据
    train_generator = DataGenerator(uncertainty_level=0.7, seed=42)
    
    # 生成多样化的训练数据
    regular_train = train_generator.generate_dataset(n_samples=600, include_mixed_scenarios=True)
    conflict_train = train_generator.generate_conflict_samples(n_samples=150)
    boundary_train = train_generator.generate_decision_boundary_samples(n_samples=150)
    
    train_data = pd.concat([regular_train, conflict_train, boundary_train], ignore_index=True)
    
    # 生成测试数据（使用不同的不确定性水平）
    test_generator = DataGenerator(uncertainty_level=0.3, seed=123)
    test_data = test_generator.generate_dataset(n_samples=200, include_mixed_scenarios=True)
    
    print(f"训练数据组成:")
    print(f"  常规样本: {len(regular_train)}")
    print(f"  冲突样本: {len(conflict_train)}")
    print(f"  边界样本: {len(boundary_train)}")
    print(f"  总训练样本: {len(train_data)}")
    print(f"  测试样本: {len(test_data)}")
    
    # 准备特征和标签
    feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
    X_train = train_data[feature_columns].values
    y_train = train_data['shouldRecommendHotspot'].values
    X_test = test_data[feature_columns].values
    y_test = test_data['shouldRecommendHotspot'].values
    
    # 训练模型
    model = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        max_depth=10
    )
    model.fit(X_train, y_train)
    
    # 在测试集上评估
    y_pred = model.predict(X_test)
    y_pred_proba = model.predict_proba(X_test)[:, 1]
    
    accuracy = accuracy_score(y_test, y_pred)
    prediction_confidence = np.mean(np.maximum(y_pred_proba, 1 - y_pred_proba))
    ambiguous_predictions = np.sum((y_pred_proba > 0.4) & (y_pred_proba < 0.6)) / len(y_pred_proba)
    
    print(f"\n测试集性能:")
    print(f"  准确率: {accuracy:.3f}")
    print(f"  平均预测置信度: {prediction_confidence:.3f}")
    print(f"  模糊预测比例: {ambiguous_predictions:.3f}")
    
    # 在冲突样本上测试
    conflict_test = train_generator.generate_conflict_samples(n_samples=100)
    X_conflict = conflict_test[feature_columns].values
    y_conflict = conflict_test['shouldRecommendHotspot'].values
    
    y_pred_conflict = model.predict(X_conflict)
    conflict_accuracy = accuracy_score(y_conflict, y_pred_conflict)
    
    print(f"\n冲突样本性能:")
    print(f"  冲突样本准确率: {conflict_accuracy:.3f}")
    print(f"  性能差距: {accuracy - conflict_accuracy:.3f}")
    
    return model, train_data, test_data


def analyze_feature_complexity():
    """分析特征复杂性"""
    print("\n=== 特征复杂性分析 ===")
    
    generator = DataGenerator(uncertainty_level=0.7, seed=42)
    data = generator.generate_dataset(n_samples=1000, include_mixed_scenarios=True)
    
    feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
    
    # 计算特征相关性
    correlations = data[feature_columns].corrwith(data['shouldRecommendHotspot'])
    
    print("特征与热点推荐的相关性:")
    for feature, corr in correlations.items():
        print(f"  {feature}: {corr:.3f}")
    
    # 计算特征方差
    variances = data[feature_columns].var()
    print("\n特征方差:")
    for feature, var in variances.items():
        print(f"  {feature}: {var:.3f}")
    
    # 计算特征分布的峰度和偏度
    from scipy.stats import kurtosis, skew
    
    print("\n特征分布统计:")
    for feature in feature_columns:
        feature_data = data[feature]
        print(f"  {feature}:")
        print(f"    偏度: {skew(feature_data):.3f}")
        print(f"    峰度: {kurtosis(feature_data):.3f}")
        print(f"    范围: [{feature_data.min():.1f}, {feature_data.max():.1f}]")


def test_decision_boundary_samples():
    """专门测试决策边界样本"""
    print("\n=== 决策边界样本测试 ===")
    
    generator = DataGenerator(uncertainty_level=0.7, seed=42)
    boundary_data = generator.generate_decision_boundary_samples(n_samples=200)
    
    print(f"生成的边界样本数: {len(boundary_data)}")
    
    # 分析边界样本的概率分布
    probabilities = boundary_data['recommendationProbability']
    
    print(f"边界样本概率分布:")
    print(f"  平均概率: {probabilities.mean():.3f}")
    print(f"  概率标准差: {probabilities.std():.3f}")
    print(f"  概率范围: [{probabilities.min():.3f}, {probabilities.max():.3f}]")
    
    # 统计不同概率区间的样本数
    bins = [0.0, 0.3, 0.4, 0.5, 0.6, 0.7, 1.0]
    hist, _ = np.histogram(probabilities, bins=bins)
    
    print(f"\n概率分布直方图:")
    for i in range(len(bins)-1):
        print(f"  {bins[i]:.1f}-{bins[i+1]:.1f}: {hist[i]} 样本 ({hist[i]/len(probabilities)*100:.1f}%)")
    
    # 边界样本的置信度分析
    confidence = boundary_data['confidence']
    print(f"\n边界样本置信度:")
    print(f"  平均置信度: {confidence.mean():.3f}")
    print(f"  置信度范围: [{confidence.min():.3f}, {confidence.max():.3f}]")


if __name__ == "__main__":
    # 运行所有测试
    test_enhanced_generator()
    model, train_data, test_data = test_model_performance_with_enhanced_data()
    analyze_feature_complexity()
    test_decision_boundary_samples()
    
    print("\n=== 总结 ===")
    print("增强数据生成器成功引入了:")
    print("- 增强的非线性特征交互")
    print("- 专门的决策边界样本生成")
    print("- 多样化的冲突样本")
    print("- 可调节的不确定性水平")
    print("- 更复杂的特征分布")
