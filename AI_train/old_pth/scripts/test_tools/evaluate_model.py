# language: python
"""
模型性能评估工具

用于全面评估训练好的模型在测试集上的性能表现
包括分类指标、回归指标、混淆矩阵、ROC曲线等
"""

import os
import sys
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
if os.path.join(PROJECT_ROOT, 'src') not in sys.path:
    sys.path.insert(0, os.path.join(PROJECT_ROOT, 'src'))

from src.models.network_model import NetworkQualityModel
from src.models.trainer import ModelTrainer
from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.utils.config import Config

class ModelEvaluator:
    """模型性能评估器"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.output_dir = "evaluation_results"
        os.makedirs(self.output_dir, exist_ok=True)
        
    def load_model(self, model_path: str):
        """加载模型"""
        print(f"📥 加载模型: {model_path}")
        self.model = NetworkQualityModel.load_model(model_path)
        return self.model
    
    def generate_test_data(self, n_samples: int = 1000, uncertainty_level: float = 0.7):
        """生成测试数据"""
        print(f"📊 生成 {n_samples} 个测试样本 (不确定性: {uncertainty_level})...")
        generator = DataGenerator(seed=42, uncertainty_level=uncertainty_level)
        
        # 生成多样化的测试数据
        base_samples = int(n_samples * 0.7)
        boundary_samples = int(n_samples * 0.15)
        conflict_samples = int(n_samples * 0.15)
        
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
        self.test_dataset = pd.concat([base_data, boundary_data, conflict_data], ignore_index=True)
        
        # 记录数据复杂性
        feature_columns = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
        correlations = self.test_dataset[feature_columns].corrwith(self.test_dataset['shouldRecommendHotspot'])
        print(f"   特征相关性: 带宽={correlations['bandwidthMbps']:.3f}, " +
              f"延迟={correlations['avgDelayMs']:.3f}, 丢包率={correlations['packetLossRate']:.3f}")
        
        # 统计模糊案例
        ambiguous_cases = self.test_dataset[
            (self.test_dataset['recommendationProbability'] > 0.4) & 
            (self.test_dataset['recommendationProbability'] < 0.6)
        ]
        print(f"   模糊案例比例: {len(ambiguous_cases)/len(self.test_dataset)*100:.1f}%")
        
        # 预处理数据 - 直接使用所有数据作为测试集
        preprocessor = DataPreprocessor()
        
        # 提取特征和目标
        X = self.test_dataset[['bandwidthMbps', 'avgDelayMs', 'packetLossRate']].values
        y = self.test_dataset[['shouldRecommendHotspot', 'qualityScore', 'confidence']].values
        
        # 标准化特征
        X_scaled = preprocessor.scaler.fit_transform(X)
        
        self.X_test = X_scaled
        self.y_test = y
        return X_scaled, y
    
    def comprehensive_evaluation(self, model_path: str, n_test_samples: int = 1000):
        """全面评估模型性能"""
        print("🚀 开始全面模型评估")
        print("=" * 60)
        
        # 加载模型
        model = self.load_model(model_path)
        
        # 生成测试数据
        X_test, y_test = self.generate_test_data(n_test_samples)
        
        # 创建训练器用于评估
        trainer = ModelTrainer(model)
        
        # 创建测试数据加载器
        _, _, test_loader = trainer.create_dataloaders(
            X_test, X_test, X_test, y_test, y_test, y_test,
            batch_size=32, shuffle=False
        )
        
        # 执行评估
        print("\n📈 执行模型评估...")
        metrics = trainer.evaluate(test_loader)
        
        # 生成详细报告
        self._generate_detailed_report(metrics, model_path)
        
        # 可视化结果
        self._create_visualizations(metrics, model_path)
        
        return metrics
    
    def _generate_detailed_report(self, metrics: dict, model_path: str):
        """生成详细评估报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(self.output_dir, f"evaluation_report_{timestamp}.json")
        
        report = {
            "evaluation_time": datetime.now().isoformat(),
            "model_path": model_path,
            "model_config": {
                "input_size": self.model.input_size,
                "hidden_sizes": self.model.hidden_sizes,
                "dropout_rate": self.model.dropout_rate,
                "use_batch_norm": self.model.use_batch_norm
            },
            "test_data_info": {
                "samples": len(self.X_test),
                "features": self.X_test.shape[1],
                "outputs": self.y_test.shape[1]
            },
            "performance_metrics": metrics,
            "performance_summary": self._generate_performance_summary(metrics)
        }
        
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"💾 评估报告已保存: {report_file}")
        
        # 打印性能摘要
        self._print_performance_summary(report["performance_summary"])
    
    def _generate_performance_summary(self, metrics: dict) -> dict:
        """生成性能摘要"""
        summary = {
            "hotspot_recommendation": {
                "accuracy": metrics["accuracy"],
                "f1_score": metrics["f1_score"],
                "auc_roc": metrics["auc_roc"],
                "status": "优秀" if metrics["f1_score"] > 0.8 else "良好" if metrics["f1_score"] > 0.6 else "需要改进"
            },
            "quality_prediction": {
                "mae": metrics["quality_mae"],
                "r2": metrics["quality_r2"],
                "status": "优秀" if metrics["quality_r2"] > 0.8 else "良好" if metrics["quality_r2"] > 0.6 else "需要改进"
            },
            "confidence_prediction": {
                "mae": metrics["confidence_mae"],
                "r2": metrics["confidence_r2"],
                "status": "优秀" if metrics["confidence_r2"] > 0.8 else "良好" if metrics["confidence_r2"] > 0.6 else "需要改进"
            },
            "overall_score": (metrics["f1_score"] + metrics["quality_r2"] + metrics["confidence_r2"]) / 3
        }
        
        return summary
    
    def _print_performance_summary(self, summary: dict):
        """打印性能摘要"""
        print("\n" + "="*60)
        print("📊 性能评估摘要")
        print("="*60)
        
        print(f"\n🎯 热点推荐性能:")
        print(f"  准确率: {summary['hotspot_recommendation']['accuracy']:.4f}")
        print(f"  F1分数: {summary['hotspot_recommendation']['f1_score']:.4f}")
        print(f"  AUC-ROC: {summary['hotspot_recommendation']['auc_roc']:.4f}")
        print(f"  状态: {summary['hotspot_recommendation']['status']}")
        
        print(f"\n📈 质量预测性能:")
        print(f"  MAE: {summary['quality_prediction']['mae']:.4f}")
        print(f"  R²: {summary['quality_prediction']['r2']:.4f}")
        print(f"  状态: {summary['quality_prediction']['status']}")
        
        print(f"\n🎯 置信度预测性能:")
        print(f"  MAE: {summary['confidence_prediction']['mae']:.4f}")
        print(f"  R²: {summary['confidence_prediction']['r2']:.4f}")
        print(f"  状态: {summary['confidence_prediction']['status']}")
        
        print(f"\n🌟 综合评分: {summary['overall_score']:.4f}")
        
        # 改进建议
        self._print_improvement_suggestions(summary)
    
    def _print_improvement_suggestions(self, summary: dict):
        """打印改进建议"""
        print(f"\n💡 改进建议:")
        
        if summary["hotspot_recommendation"]["f1_score"] < 0.7:
            print("  🔸 热点推荐性能需要改进，建议检查数据平衡性和模型复杂度")
        
        if summary["quality_prediction"]["r2"] < 0.6:
            print("  🔸 质量预测回归性能较低，建议优化回归损失函数权重")
        
        if summary["confidence_prediction"]["r2"] < 0.6:
            print("  🔸 置信度预测需要改进，建议检查置信度标签的准确性")
        
        if summary["overall_score"] < 0.7:
            print("  🔸 整体性能需要提升，建议重新训练或调整模型架构")
    
    def _create_visualizations(self, metrics: dict, model_path: str):
        """创建可视化图表"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 设置中文字体
        plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei']
        plt.rcParams['axes.unicode_minus'] = False
        
        # 创建性能对比图
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        
        # 1. 分类性能对比
        classification_metrics = {
            '准确率': metrics['accuracy'],
            '精确率': metrics['precision'],
            '召回率': metrics['recall'],
            'F1分数': metrics['f1_score']
        }
        
        axes[0, 0].bar(classification_metrics.keys(), classification_metrics.values(), color=['#3498db', '#2ecc71', '#e74c3c', '#f39c12'])
        axes[0, 0].set_title('热点推荐分类性能', fontsize=14, fontweight='bold')
        axes[0, 0].set_ylabel('分数')
        axes[0, 0].set_ylim(0, 1)
        for i, v in enumerate(classification_metrics.values()):
            axes[0, 0].text(i, v + 0.01, f'{v:.3f}', ha='center', va='bottom')
        
        # 2. 回归性能对比
        regression_metrics = {
            '质量MAE': metrics['quality_mae'],
            '质量R²': metrics['quality_r2'],
            '置信度MAE': metrics['confidence_mae'],
            '置信度R²': metrics['confidence_r2']
        }
        
        colors = ['#e74c3c', '#2ecc71', '#e74c3c', '#2ecc71']
        bars = axes[0, 1].bar(regression_metrics.keys(), regression_metrics.values(), color=colors)
        axes[0, 1].set_title('回归预测性能', fontsize=14, fontweight='bold')
        axes[0, 1].set_ylabel('分数')
        axes[0, 1].set_ylim(0, 1)
        for i, v in enumerate(regression_metrics.values()):
            axes[0, 1].text(i, v + 0.01, f'{v:.3f}', ha='center', va='bottom')
        
        # 3. 综合评分条形图 (替代雷达图)
        overall_metrics = {
            '热点推荐F1': metrics['f1_score'],
            '质量预测R²': metrics['quality_r2'],
            '置信度R²': metrics['confidence_r2']
        }
        
        axes[1, 0].bar(overall_metrics.keys(), overall_metrics.values(), color=['#3498db', '#2ecc71', '#9b59b6'])
        axes[1, 0].set_title('综合性能指标', fontsize=14, fontweight='bold')
        axes[1, 0].set_ylabel('分数')
        axes[1, 0].set_ylim(0, 1)
        for i, v in enumerate(overall_metrics.values()):
            axes[1, 0].text(i, v + 0.01, f'{v:.3f}', ha='center', va='bottom')
        
        # 4. 混淆矩阵热力图
        cm = np.array(metrics['confusion_matrix'])
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[1, 1])
        axes[1, 1].set_title('混淆矩阵', fontsize=14, fontweight='bold')
        axes[1, 1].set_xlabel('预测标签')
        axes[1, 1].set_ylabel('真实标签')
        
        plt.tight_layout()
        plot_file = os.path.join(self.output_dir, f"performance_plots_{timestamp}.png")
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        plt.show()
        
        print(f"📊 性能图表已保存: {plot_file}")

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="模型性能评估工具")
    parser.add_argument("--model", type=str, default="checkpoints/best_model.pth", 
                       help="模型文件路径")
    parser.add_argument("--test-samples", type=int, default=1000,
                       help="测试样本数量")
    parser.add_argument("--config", type=str, default="configs/train_config.json",
                       help="配置文件路径")
    
    args = parser.parse_args()
    
    # 创建评估器
    evaluator = ModelEvaluator(args.config)
    
    # 执行全面评估
    metrics = evaluator.comprehensive_evaluation(args.model, args.test_samples)
    
    print(f"\n🎉 模型评估完成!")
    print(f"📁 结果保存在: {evaluator.output_dir}")

if __name__ == "__main__":
    main()
