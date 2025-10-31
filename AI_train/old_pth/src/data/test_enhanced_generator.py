"""
Test script to validate the enhanced data generator and its impact on model training.
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


def test_model_generalization():
    """测试增强数据对模型泛化能力的影响"""
    print("=== 模型泛化能力测试 ===\n")
    
    # 生成不同不确定性水平的数据集
    datasets = {}
    for uncertainty in [0.0, 0.5, 1.0]:
        print(f"生成不确定性水平为 {uncertainty} 的数据集")
        generator = DataGenerator(uncertainty_level=uncertainty, seed=42)
        
        # 生成训练数据
        train_data = generator.generate_dataset(
            n_samples=1000, 
            include_mixed_scenarios=True
        )
        
        # 生成测试数据（使用不同的生成器模拟真实世界分布偏移）
        test_generator = DataGenerator(uncertainty_level=0.3, seed=123)
        test_data = test_generator.generate_dataset(
            n_samples=200,
            include_mixed_scenarios=True
        )
        
        datasets[uncertainty] = {
            'train': train_data,
            'test': test_data
        }
        
        print(f"  训练样本数: {len(train_data)}")
        print(f"  测试样本数: {len(test_data)}")
        print(f"  训练集热点推荐分布: {train_data['shouldRecommendHotspot'].value_counts().to_dict()}")
        print(f"  测试集热点推荐分布: {test_data['shouldRecommendHotspot'].value_counts().to_dict()}")
        print()
    
    # 训练和评估模型
    results = {}
    feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
    
    for uncertainty, data_dict in datasets.items():
        print(f"训练不确定性水平 {uncertainty} 的模型...")
        
        # 准备特征和标签
        X_train = data_dict['train'][feature_columns].values
        y_train = data_dict['train']['shouldRecommendHotspot'].values
        X_test = data_dict['test'][feature_columns].values
        y_test = data_dict['test']['shouldRecommendHotspot'].values
        
        # 训练随机森林分类器
        model = RandomForestClassifier(
            n_estimators=100,
            random_state=42,
            max_depth=10
        )
        model.fit(X_train, y_train)
        
        # 进行预测
        y_pred = model.predict(X_test)
        y_pred_proba = model.predict_proba(X_test)[:, 1]
        
        # 计算指标
        accuracy = accuracy_score(y_test, y_pred)
        
        # 计算预测置信度（概率接近0或1的程度）
        prediction_confidence = np.mean(np.maximum(y_pred_proba, 1 - y_pred_proba))
        
        # 计算模糊预测（接近0.5的概率）
        ambiguous_predictions = np.sum((y_pred_proba > 0.4) & (y_pred_proba < 0.6)) / len(y_pred_proba)
        
        results[uncertainty] = {
            'accuracy': accuracy,
            'prediction_confidence': prediction_confidence,
            'ambiguous_predictions': ambiguous_predictions,
            'model': model
        }
        
        print(f"  测试准确率: {accuracy:.3f}")
        print(f"  平均预测置信度: {prediction_confidence:.3f}")
        print(f"  模糊预测比例: {ambiguous_predictions:.3f}")
        print()
    
    # 比较结果
    print("=== 结果对比 ===")
    for uncertainty, result in results.items():
        print(f"不确定性水平 {uncertainty}:")
        print(f"  准确率: {result['accuracy']:.3f}")
        print(f"  预测置信度: {result['prediction_confidence']:.3f}")
        print(f"  模糊预测比例: {result['ambiguous_predictions']:.3f}")
        print()
    
    return results, datasets


def analyze_feature_importance(datasets):
    """分析不同不确定性水平下的特征重要性"""
    print("=== 特征重要性分析 ===")
    
    feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
    
    for uncertainty, data_dict in datasets.items():
        print(f"\n不确定性水平 {uncertainty}:")
        
        # 计算与热点推荐的相关性
        train_data = data_dict['train']
        correlations = train_data[feature_columns].corrwith(train_data['shouldRecommendHotspot'])
        
        print("  特征与热点推荐的相关性:")
        for feature, corr in correlations.items():
            print(f"    {feature}: {corr:.3f}")
        
        # 计算特征方差
        variances = train_data[feature_columns].var()
        print("  特征方差:")
        for feature, var in variances.items():
            print(f"    {feature}: {var:.3f}")


def test_conflict_samples_handling():
    """测试模型处理冲突样本的能力"""
    print("\n=== 冲突样本处理测试 ===")
    
    # 在增强数据上训练模型
    generator = DataGenerator(uncertainty_level=0.7, seed=42)
    train_data = generator.generate_dataset(n_samples=800, include_mixed_scenarios=True)
    
    # 生成冲突样本
    conflict_data = generator.generate_conflict_samples(n_samples=200)
    
    # 准备数据
    feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
    X_train = train_data[feature_columns].values
    y_train = train_data['shouldRecommendHotspot'].values
    X_conflict = conflict_data[feature_columns].values
    y_conflict = conflict_data['shouldRecommendHotspot'].values
    
    # 训练模型
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # 在冲突样本上评估
    y_pred_conflict = model.predict(X_conflict)
    conflict_accuracy = accuracy_score(y_conflict, y_pred_conflict)
    
    # 获取冲突样本的预测概率
    y_pred_proba_conflict = model.predict_proba(X_conflict)[:, 1]
    conflict_confidence = np.mean(np.maximum(y_pred_proba_conflict, 1 - y_pred_proba_conflict))
    
    print(f"冲突样本准确率: {conflict_accuracy:.3f}")
    print(f"冲突样本平均置信度: {conflict_confidence:.3f}")
    
    # 与常规测试性能比较
    test_generator = DataGenerator(uncertainty_level=0.3, seed=123)
    test_data = test_generator.generate_dataset(n_samples=200, include_mixed_scenarios=True)
    X_test = test_data[feature_columns].values
    y_test = test_data['shouldRecommendHotspot'].values
    
    y_pred_test = model.predict(X_test)
    test_accuracy = accuracy_score(y_test, y_pred_test)
    
    print(f"常规测试准确率: {test_accuracy:.3f}")
    print(f"性能差距（测试 - 冲突）: {test_accuracy - conflict_accuracy:.3f}")


if __name__ == "__main__":
    # 运行所有测试
    results, datasets = test_model_generalization()
    analyze_feature_importance(datasets)
    test_conflict_samples_handling()
    
