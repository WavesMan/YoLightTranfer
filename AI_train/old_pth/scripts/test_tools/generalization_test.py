# language: python
"""
泛化能力测试工具

用于测试模型在不同数据分布上的泛化能力
验证模型的鲁棒性和适应性
"""

import os
import sys
import json
import numpy as np
import pandas as pd
from datetime import datetime

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.models.network_model import NetworkQualityModel
from src.models.trainer import ModelTrainer
from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.utils.config import Config

class GeneralizationTester:
    """泛化能力测试器"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.output_dir = "generalization_results"
        os.makedirs(self.output_dir, exist_ok=True)
        
    def load_model(self, model_path: str):
        """加载模型"""
        print(f"📥 加载模型: {model_path}")
        self.model = NetworkQualityModel.load_model(model_path)
        return self.model
    
    def create_distribution_shifts(self):
        """创建不同的数据分布偏移"""
        distributions = {
            "标准分布": {
                "strong_network": 0.4,
                "weak_network": 0.3,
                "critical_network": 0.3
            },
            "偏向强网络": {
                "strong_network": 0.7,
                "weak_network": 0.2,
                "critical_network": 0.1
            },
            "偏向弱网络": {
                "strong_network": 0.1,
                "weak_network": 0.7,
                "critical_network": 0.2
            },
            "偏向临界网络": {
                "strong_network": 0.2,
                "weak_network": 0.2,
                "critical_network": 0.6
            },
            "极端分布": {
                "strong_network": 0.9,
                "weak_network": 0.05,
                "critical_network": 0.05
            }
        }
        return distributions
    
    def test_distribution_shift(self, distribution_name: str, scenario_weights: dict, n_samples: int = 500, uncertainty_level: float = 0.7):
        """测试特定分布偏移"""
        print(f"\n📊 测试分布: {distribution_name} (不确定性: {uncertainty_level})")
        print(f"   场景权重: {scenario_weights}")
        
        # 生成测试数据 - 使用增强数据生成器
        generator = DataGenerator(seed=42, uncertainty_level=uncertainty_level)
        
        # 生成多样化的测试数据
        base_samples = int(n_samples * 0.7)
        boundary_samples = int(n_samples * 0.15)
        conflict_samples = int(n_samples * 0.15)
        
        # 生成基础数据
        base_data = generator.generate_dataset(
            n_samples=base_samples,
            scenario_weights=scenario_weights,
            include_mixed_scenarios=True
        )
        
        # 生成边界样本
        boundary_data = generator.generate_decision_boundary_samples(n_samples=boundary_samples)
        
        # 生成冲突样本
        conflict_data = generator.generate_conflict_samples(n_samples=conflict_samples)
        
        # 合并所有数据
        test_dataset = pd.concat([base_data, boundary_data, conflict_data], ignore_index=True)
        
        # 记录数据复杂性
        feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
        correlations = test_dataset[feature_columns].corrwith(test_dataset['shouldRecommendHotspot'])
        print(f"   特征相关性: 带宽={correlations['bandwidthMbps']:.3f}, " +
              f"延迟={correlations['avgDelayMs']:.3f}, 丢包率={correlations['packetLossRate']:.3f}")
        
        # 统计模糊案例
        ambiguous_cases = test_dataset[
            (test_dataset['recommendationProbability'] > 0.4) & 
            (test_dataset['recommendationProbability'] < 0.6)
        ]
        print(f"   模糊案例比例: {len(ambiguous_cases)/len(test_dataset)*100:.1f}%")
        
        # 预处理数据 - 直接使用所有数据作为测试集
        preprocessor = DataPreprocessor()
        
        # 提取特征和目标
        X = test_dataset[['bandwidthMbps', 'avgDelayMs', 'packetLossRate']].values
        y = test_dataset[['shouldRecommendHotspot', 'qualityScore', 'confidence']].values
        
        # 标准化特征
        X_scaled = preprocessor.scaler.fit_transform(X)
        
        # 创建训练器用于评估
        trainer = ModelTrainer(self.model)
        
        # 创建测试数据加载器
        _, _, test_loader = trainer.create_dataloaders(
            X_scaled, X_scaled, X_scaled, y, y, y,
            batch_size=32, shuffle=False
        )
        
        # 执行评估
        metrics = trainer.evaluate(test_loader)
        
        # 分析分布特性
        distribution_stats = self._analyze_distribution(test_dataset)
        
        print(f"   测试样本数: {len(X_scaled)}")
        print(f"   热点推荐F1: {metrics['f1_score']:.4f}")
        print(f"   质量预测R²: {metrics['quality_r2']:.4f}")
        print(f"   置信度R²: {metrics['confidence_r2']:.4f}")
        
        return {
            "distribution_name": distribution_name,
            "scenario_weights": scenario_weights,
            "test_samples": len(X_scaled),
            "metrics": metrics,
            "distribution_stats": distribution_stats
        }
    
    def _analyze_distribution(self, dataset: pd.DataFrame) -> dict:
        """分析数据分布特性"""
        total_samples = len(dataset)
        
        # 场景分布
        scenario_counts = dataset['scenario'].value_counts()
        scenario_ratios = {scenario: count/total_samples for scenario, count in scenario_counts.items()}
        
        # 热点推荐分布
        hotspot_counts = dataset['shouldRecommendHotspot'].value_counts()
        hotspot_ratio = hotspot_counts.get(1, 0) / total_samples
        
        # 网络参数统计
        bandwidth_stats = {
            "mean": dataset['bandwidthMbps'].mean(),
            "std": dataset['bandwidthMbps'].std(),
            "min": dataset['bandwidthMbps'].min(),
            "max": dataset['bandwidthMbps'].max()
        }
        
        delay_stats = {
            "mean": dataset['avgDelayMs'].mean(),
            "std": dataset['avgDelayMs'].std(),
            "min": dataset['avgDelayMs'].min(),
            "max": dataset['avgDelayMs'].max()
        }
        
        loss_stats = {
            "mean": dataset['packetLossRate'].mean(),
            "std": dataset['packetLossRate'].std(),
            "min": dataset['packetLossRate'].min(),
            "max": dataset['packetLossRate'].max()
        }
        
        return {
            "scenario_distribution": scenario_ratios,
            "hotspot_recommendation_ratio": hotspot_ratio,
            "bandwidth_statistics": bandwidth_stats,
            "delay_statistics": delay_stats,
            "packet_loss_statistics": loss_stats
        }
    
    def comprehensive_generalization_test(self, model_path: str, n_samples_per_dist: int = 500):
        """全面泛化能力测试"""
        print("🚀 开始全面泛化能力测试")
        print("=" * 60)
        
        # 加载模型
        self.load_model(model_path)
        
        # 创建不同的数据分布
        distributions = self.create_distribution_shifts()
        
        # 执行测试
        all_results = []
        
        for dist_name, scenario_weights in distributions.items():
            print(f"\n{'='*40}")
            print(f"📋 测试分布: {dist_name}")
            print(f"{'='*40}")
            
            result = self.test_distribution_shift(dist_name, scenario_weights, n_samples_per_dist)
            all_results.append(result)
        
        # 生成泛化能力报告
        self._generate_generalization_report(all_results, model_path)
        
        # 分析泛化能力
        self._analyze_generalization_capability(all_results)
        
        return all_results
    
    def _generate_generalization_report(self, results: list, model_path: str):
        """生成泛化能力报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(self.output_dir, f"generalization_report_{timestamp}.json")
        
        report = {
            "test_time": datetime.now().isoformat(),
            "model_path": model_path,
            "total_distributions": len(results),
            "test_results": results,
            "generalization_analysis": self._calculate_generalization_metrics(results)
        }
        
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 泛化能力报告已保存: {report_file}")
        
        # 打印泛化能力摘要
        self._print_generalization_summary(report["generalization_analysis"])
    
    def _calculate_generalization_metrics(self, results: list) -> dict:
        """计算泛化能力指标"""
        # 提取关键指标
        f1_scores = [r["metrics"]["f1_score"] for r in results]
        quality_r2_scores = [r["metrics"]["quality_r2"] for r in results]
        confidence_r2_scores = [r["metrics"]["confidence_r2"] for r in results]
        
        # 计算性能稳定性
        f1_stability = 1 - (np.std(f1_scores) / np.mean(f1_scores)) if np.mean(f1_scores) > 0 else 0
        quality_stability = 1 - (np.std(quality_r2_scores) / np.mean(quality_r2_scores)) if np.mean(quality_r2_scores) > 0 else 0
        confidence_stability = 1 - (np.std(confidence_r2_scores) / np.mean(confidence_r2_scores)) if np.mean(confidence_r2_scores) > 0 else 0
        
        # 计算性能下降（避免除零错误）
        baseline_f1 = f1_scores[0]  # 第一个是标准分布
        f1_degradation = [(baseline_f1 - score) / baseline_f1 for score in f1_scores[1:]] if baseline_f1 != 0 else [0] * (len(f1_scores)-1)
        avg_f1_degradation = np.mean(f1_degradation) if f1_degradation else 0
        
        baseline_quality = quality_r2_scores[0]
        quality_degradation = [(baseline_quality - score) / baseline_quality for score in quality_r2_scores[1:]] if baseline_quality != 0 else [0] * (len(quality_r2_scores)-1)
        avg_quality_degradation = np.mean(quality_degradation) if quality_degradation else 0
        
        baseline_confidence = confidence_r2_scores[0]
        confidence_degradation = [(baseline_confidence - score) / baseline_confidence for score in confidence_r2_scores[1:]] if baseline_confidence != 0 else [0] * (len(confidence_r2_scores)-1)
        avg_confidence_degradation = np.mean(confidence_degradation) if confidence_degradation else 0
        
        return {
            "performance_stability": {
                "f1_stability": float(f1_stability),
                "quality_stability": float(quality_stability),
                "confidence_stability": float(confidence_stability),
                "overall_stability": float((f1_stability + quality_stability + confidence_stability) / 3)
            },
            "performance_degradation": {
                "f1_degradation": float(avg_f1_degradation),
                "quality_degradation": float(avg_quality_degradation),
                "confidence_degradation": float(avg_confidence_degradation),
                "overall_degradation": float((avg_f1_degradation + avg_quality_degradation + avg_confidence_degradation) / 3)
            },
            "distribution_performance": {
                "f1_scores": [float(score) for score in f1_scores],
                "quality_r2_scores": [float(score) for score in quality_r2_scores],
                "confidence_r2_scores": [float(score) for score in confidence_r2_scores]
            }
        }
    
    def _print_generalization_summary(self, analysis: dict):
        """打印泛化能力摘要"""
        print("\n" + "="*60)
        print("📊 泛化能力分析摘要")
        print("="*60)
        
        stability = analysis["performance_stability"]
        degradation = analysis["performance_degradation"]
        
        print(f"\n🎯 性能稳定性:")
        print(f"  热点推荐稳定性: {stability['f1_stability']:.4f}")
        print(f"  质量预测稳定性: {stability['quality_stability']:.4f}")
        print(f"  置信度预测稳定性: {stability['confidence_stability']:.4f}")
        print(f"  整体稳定性: {stability['overall_stability']:.4f}")
        
        print(f"\n📉 性能下降:")
        print(f"  热点推荐下降: {degradation['f1_degradation']:.2%}")
        print(f"  质量预测下降: {degradation['quality_degradation']:.2%}")
        print(f"  置信度预测下降: {degradation['confidence_degradation']:.2%}")
        print(f"  整体下降: {degradation['overall_degradation']:.2%}")
        
        # 泛化能力评估
        self._assess_generalization_capability(stability, degradation)
    
    def _assess_generalization_capability(self, stability: dict, degradation: dict):
        """评估泛化能力"""
        print(f"\n🔍 泛化能力评估:")
        
        overall_stability = stability["overall_stability"]
        overall_degradation = degradation["overall_degradation"]
        
        if overall_stability > 0.9 and overall_degradation < 0.05:
            print("  ✅ 泛化能力: 优秀 - 模型在不同分布上表现稳定")
        elif overall_stability > 0.8 and overall_degradation < 0.1:
            print("  ✅ 泛化能力: 良好 - 模型具有一定的泛化能力")
        elif overall_stability > 0.7 and overall_degradation < 0.2:
            print("  ⚠️ 泛化能力: 中等 - 模型在部分分布上表现下降")
        else:
            print("  ❌ 泛化能力: 较差 - 模型对数据分布敏感")
        
        # 改进建议
        self._print_generalization_suggestions(stability, degradation)
    
    def _print_generalization_suggestions(self, stability: dict, degradation: dict):
        """打印泛化能力改进建议"""
        print(f"\n💡 改进建议:")
        
        if stability["f1_stability"] < 0.8:
            print("  🔸 热点推荐稳定性较低，建议增加数据多样性")
        
        if stability["quality_stability"] < 0.8:
            print("  🔸 质量预测稳定性较低，建议优化回归损失函数")
        
        if stability["confidence_stability"] < 0.8:
            print("  🔸 置信度预测稳定性较低，建议检查置信度校准")
        
        if degradation["overall_degradation"] > 0.1:
            print("  🔸 整体性能下降较大，建议使用数据增强技术")
        
        if stability["overall_stability"] < 0.8:
            print("  🔸 整体稳定性不足，建议使用正则化技术")
    
    def _analyze_generalization_capability(self, results: list):
        """分析泛化能力"""
        print(f"\n🔍 详细泛化能力分析:")
        
        # 按分布类型分析性能变化
        for result in results:
            dist_name = result["distribution_name"]
            metrics = result["metrics"]
            dist_stats = result["distribution_stats"]
            
            print(f"\n  📊 分布: {dist_name}")
            print(f"    场景分布: {dist_stats['scenario_distribution']}")
            print(f"    热点推荐比例: {dist_stats['hotspot_recommendation_ratio']:.2%}")
            print(f"    性能指标:")
            print(f"      F1分数: {metrics['f1_score']:.4f}")
            print(f"      质量R²: {metrics['quality_r2']:.4f}")
            print(f"      置信度R²: {metrics['confidence_r2']:.4f}")
            
            # 性能变化分析
            if dist_name != "标准分布":
                baseline_result = results[0]  # 标准分布
                baseline_f1 = baseline_result["metrics"]["f1_score"]
                f1_change = (metrics["f1_score"] - baseline_f1) / baseline_f1 if baseline_f1 != 0 else 0
                
                if abs(f1_change) < 0.05:
                    print(f"      F1变化: {f1_change:+.2%} (稳定)")
                elif abs(f1_change) < 0.15:
                    print(f"      F1变化: {f1_change:+.2%} (轻微变化)")
                else:
                    print(f"      F1变化: {f1_change:+.2%} (显著变化)")

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="泛化能力测试工具")
    parser.add_argument("--model", type=str, default="checkpoints/best_model.pth", 
                       help="模型文件路径")
    parser.add_argument("--samples", type=int, default=500,
                       help="每个分布的测试样本数量")
    parser.add_argument("--config", type=str, default="configs/train_config.json",
                       help="配置文件路径")
    
    args = parser.parse_args()
    
    # 创建测试器
    tester = GeneralizationTester(args.config)
    
    # 执行全面泛化能力测试
    results = tester.comprehensive_generalization_test(args.model, args.samples)
    
    print(f"\n🎉 泛化能力测试完成!")
    print(f"📁 结果保存在: {tester.output_dir}")

if __name__ == "__main__":
    main()
