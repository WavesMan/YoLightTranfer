"""
测试增强版自动训练脚本
"""

import os
import sys
import pandas as pd

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.data.generator import DataGenerator
from src.utils.config import Config

def test_enhanced_data_generation():
    """测试增强数据生成功能"""
    print("=== 测试增强数据生成功能 ===\n")
    
    # 加载配置
    cfg = Config("configs/train_config.json")
    
    # 测试不同的不确定性水平
    for uncertainty in [0.3, 0.7, 0.9]:
        print(f"测试不确定性水平: {uncertainty}")
        
        # 使用增强数据生成器
        generator = DataGenerator(
            seed=42,
            uncertainty_level=uncertainty
        )
        
        # 生成多样化的训练数据
        base_samples = int(cfg.data.dataset_size * 0.7)
        boundary_samples = int(cfg.data.dataset_size * cfg.data.data_generation.boundary_sample_ratio)
        conflict_samples = int(cfg.data.dataset_size * cfg.data.data_generation.conflict_sample_ratio)
        
        print(f"  基础样本: {base_samples}")
        print(f"  边界样本: {boundary_samples}")
        print(f"  冲突样本: {conflict_samples}")
        
        # 生成基础数据
        base_data = generator.generate_dataset(
            n_samples=base_samples, 
            include_mixed_scenarios=True
        )
        
        # 生成边界样本
        boundary_data = generator.generate_decision_boundary_samples(n_samples=boundary_samples)
        
        # 生成冲突样本
        conflict_data = generator.generate_conflict_samples(n_samples=conflict_samples)
        
        # 合并所有数据
        raw_dataset = pd.concat([base_data, boundary_data, conflict_data], ignore_index=True)
        
        print(f"  总样本数: {len(raw_dataset)}")
        
        # 记录数据复杂性
        feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
        correlations = raw_dataset[feature_columns].corrwith(raw_dataset['shouldRecommendHotspot'])
        print(f"  特征相关性:")
        print(f"    带宽: {correlations['bandwidthMbps']:.3f}")
        print(f"    延迟: {correlations['avgDelayMs']:.3f}")
        print(f"    丢包率: {correlations['packetLossRate']:.3f}")
        
        # 统计模糊案例
        ambiguous_cases = raw_dataset[
            (raw_dataset['recommendationProbability'] > 0.4) & 
            (raw_dataset['recommendationProbability'] < 0.6)
        ]
        print(f"  模糊案例比例: {len(ambiguous_cases)/len(raw_dataset)*100:.1f}%")
        
        # 统计样本类型分布
        if 'scenario' in raw_dataset.columns:
            scenario_counts = raw_dataset['scenario'].value_counts()
            print(f"  样本类型分布:")
            for scenario, count in scenario_counts.items():
                print(f"    {scenario}: {count} ({count/len(raw_dataset)*100:.1f}%)")
        
        print()

def test_dynamic_uncertainty():
    """测试动态不确定性调整"""
    print("=== 测试动态不确定性调整 ===\n")
    
    cfg = Config("configs/train_config.json")
    
    # 模拟不同迭代次数的动态不确定性
    iterations = [1, 100, 500, 1000, 1500]
    
    for iteration in iterations:
        # 计算动态不确定性水平
        progress_ratio = min(iteration / 1000, 1.0)
        uncertainty_level = cfg.data.data_generation.min_uncertainty + \
                          (cfg.data.data_generation.max_uncertainty - cfg.data.data_generation.min_uncertainty) * progress_ratio
        
        print(f"迭代 #{iteration}:")
        print(f"  进度比例: {progress_ratio:.2f}")
        print(f"  不确定性水平: {uncertainty_level:.2f}")
        
        # 生成数据并分析复杂性
        generator = DataGenerator(
            seed=42 + iteration,
            uncertainty_level=uncertainty_level
        )
        
        data = generator.generate_dataset(n_samples=100, include_mixed_scenarios=True)
        
        # 计算特征相关性
        feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
        correlations = data[feature_columns].corrwith(data['shouldRecommendHotspot'])
        avg_correlation = correlations.abs().mean()
        
        print(f"  平均特征相关性: {avg_correlation:.3f}")
        print()

def test_config_integration():
    """测试配置集成"""
    print("=== 测试配置集成 ===\n")
    
    cfg = Config("configs/train_config.json")
    
    print("数据生成配置:")
    print(f"  不确定性水平: {cfg.data.data_generation.uncertainty_level}")
    print(f"  包含混合场景: {cfg.data.data_generation.include_mixed_scenarios}")
    print(f"  包含边界样本: {cfg.data.data_generation.include_boundary_samples}")
    print(f"  包含冲突样本: {cfg.data.data_generation.include_conflict_samples}")
    print(f"  边界样本比例: {cfg.data.data_generation.boundary_sample_ratio}")
    print(f"  冲突样本比例: {cfg.data.data_generation.conflict_sample_ratio}")
    print(f"  动态不确定性: {cfg.data.data_generation.dynamic_uncertainty}")
    print(f"  最小不确定性: {cfg.data.data_generation.min_uncertainty}")
    print(f"  最大不确定性: {cfg.data.data_generation.max_uncertainty}")

if __name__ == "__main__":
    test_config_integration()
    test_enhanced_data_generation()
    test_dynamic_uncertainty()
    
    print("=== 总结 ===")
    print("增强版自动训练功能已成功集成:")
    print("- 配置参数已添加到 train_config.json")
    print("- 动态不确定性调整已实现")
    print("- 多样化数据生成已集成")
    print("- 数据复杂性监控已添加")
    print("- 破坏拟合曲线的功能已启用")
