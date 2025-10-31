# language: python
import os
import sys
import json
import glob
import torch
import numpy as np
from datetime import datetime
from pathlib import Path

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.models.network_model import NetworkQualityModel
from src.utils.config import Config

class ModelAnalyzer:
    """模型分析器 - 遍历读取所有小模型参数并总结分析数据"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.models_dir = self.cfg.data.models_dir
        self.analysis_results = {}
        self.summary_stats = {}
        
    def scan_all_models(self) -> list:
        """扫描所有小模型文件"""
        pattern = os.path.join(self.models_dir, "terminal_*", "model_iter_*.pth")
        model_files = glob.glob(pattern)
        print(f"🔍 发现 {len(model_files)} 个模型文件")
        return sorted(model_files)
    
    def analyze_single_model(self, model_path: str) -> dict:
        """分析单个模型的参数"""
        try:
            # 加载模型
            model = NetworkQualityModel(
                input_size=self.cfg.model.input_size,
                hidden_sizes=tuple(self.cfg.model.hidden_sizes),
                dropout_rate=self.cfg.model.dropout_rate,
                use_batch_norm=self.cfg.model.use_batch_norm
            )
            model.load_model(model_path)
            
            # 分析参数
            stats = self._analyze_model_parameters(model)
            stats["model_path"] = model_path
            stats["file_size"] = os.path.getsize(model_path)
            stats["quality_score"] = self._calculate_quality_score(stats)
            
            return stats
            
        except Exception as e:
            print(f"❌ 分析模型失败 {model_path}: {e}")
            return {
                "model_path": model_path,
                "error": str(e),
                "quality_score": 0.0
            }
    
    def _analyze_model_parameters(self, model: NetworkQualityModel) -> dict:
        """分析模型参数统计"""
        params = dict(model.named_parameters())
        stats = {
            "total_parameters": 0,
            "layer_statistics": {},
            "parameter_ranges": {},
            "zero_parameters": 0,
            "nan_parameters": 0,
            "inf_parameters": 0
        }
        
        for name, param in params.items():
            # 参数数量
            param_count = param.numel()
            stats["total_parameters"] += param_count
            
            # 参数统计
            layer_name = name.split('.')[0] if '.' in name else name
            if layer_name not in stats["layer_statistics"]:
                stats["layer_statistics"][layer_name] = {
                    "parameter_count": 0,
                    "mean": 0.0,
                    "std": 0.0,
                    "min": 0.0,
                    "max": 0.0,
                    "zero_count": 0
                }
            
            layer_stats = stats["layer_statistics"][layer_name]
            layer_stats["parameter_count"] += param_count
            
            # 参数值统计
            param_data = param.data.cpu().numpy()
            layer_stats["mean"] = float(param_data.mean())
            layer_stats["std"] = float(param_data.std())
            layer_stats["min"] = float(param_data.min())
            layer_stats["max"] = float(param_data.max())
            
            # 统计零参数
            zero_count = np.sum(param_data == 0)
            layer_stats["zero_count"] += int(zero_count)
            stats["zero_parameters"] += int(zero_count)
            
            # 统计异常值
            stats["nan_parameters"] += int(np.sum(np.isnan(param_data)))
            stats["inf_parameters"] += int(np.sum(np.isinf(param_data)))
            
            # 参数范围
            stats["parameter_ranges"][name] = {
                "min": float(param_data.min()),
                "max": float(param_data.max()),
                "mean": float(param_data.mean()),
                "std": float(param_data.std())
            }
        
        # 计算零参数比例
        stats["zero_ratio"] = stats["zero_parameters"] / stats["total_parameters"] if stats["total_parameters"] > 0 else 1.0
        
        return stats
    
    def _calculate_quality_score(self, stats: dict) -> float:
        """计算模型质量评分"""
        score = 1.0
        
        # 零参数比例惩罚
        zero_penalty = min(1.0, stats["zero_ratio"] * 10)  # 零参数比例越高，惩罚越大
        score *= (1.0 - zero_penalty * 0.5)
        
        # 异常值惩罚
        if stats["nan_parameters"] > 0 or stats["inf_parameters"] > 0:
            score *= 0.1
        
        # 参数范围合理性检查
        for layer_name, layer_stats in stats["layer_statistics"].items():
            # 检查参数范围是否合理
            if abs(layer_stats["mean"]) > 10 or layer_stats["std"] > 10:
                score *= 0.8
        
        return max(0.0, min(1.0, score))
    
    def analyze_all_models(self):
        """分析所有模型"""
        print("🚀 开始分析所有模型...")
        model_files = self.scan_all_models()
        
        for i, model_path in enumerate(model_files, 1):
            print(f"📊 分析进度: {i}/{len(model_files)} - {os.path.basename(model_path)}")
            
            # 分析单个模型
            model_stats = self.analyze_single_model(model_path)
            self.analysis_results[model_path] = model_stats
        
        # 生成汇总统计
        self._generate_summary_statistics()
        
        print(f"✅ 分析完成! 共分析了 {len(model_files)} 个模型")
    
    def _generate_summary_statistics(self):
        """生成汇总统计信息"""
        if not self.analysis_results:
            return
        
        # 基本统计
        total_models = len(self.analysis_results)
        valid_models = [m for m in self.analysis_results.values() if "error" not in m]
        error_models = [m for m in self.analysis_results.values() if "error" in m]
        
        # 质量评分分布
        quality_scores = [m["quality_score"] for m in valid_models]
        zero_ratios = [m["zero_ratio"] for m in valid_models]
        
        self.summary_stats = {
            "analysis_time": datetime.now().isoformat(),
            "total_models": total_models,
            "valid_models": len(valid_models),
            "error_models": len(error_models),
            "quality_distribution": {
                "mean": float(np.mean(quality_scores)),
                "std": float(np.std(quality_scores)),
                "min": float(np.min(quality_scores)),
                "max": float(np.max(quality_scores)),
                "percentiles": {
                    "25": float(np.percentile(quality_scores, 25)),
                    "50": float(np.percentile(quality_scores, 50)),
                    "75": float(np.percentile(quality_scores, 75))
                }
            },
            "zero_ratio_distribution": {
                "mean": float(np.mean(zero_ratios)),
                "std": float(np.std(zero_ratios)),
                "min": float(np.min(zero_ratios)),
                "max": float(np.max(zero_ratios))
            },
            "problem_models": {
                "high_zero_ratio": [m["model_path"] for m in valid_models if m["zero_ratio"] > 0.5],
                "low_quality": [m["model_path"] for m in valid_models if m["quality_score"] < 0.3],
                "has_errors": [m["model_path"] for m in error_models]
            },
            "terminal_distribution": self._analyze_terminal_distribution()
        }
    
    def _analyze_terminal_distribution(self) -> dict:
        """分析终端分布"""
        terminal_stats = {}
        
        for model_path, stats in self.analysis_results.items():
            # 提取终端ID
            parts = model_path.split(os.sep)
            terminal_dir = parts[-2] if len(parts) >= 2 else "unknown"
            
            if terminal_dir not in terminal_stats:
                terminal_stats[terminal_dir] = {
                    "model_count": 0,
                    "avg_quality": 0.0,
                    "avg_zero_ratio": 0.0
                }
            
            terminal_stats[terminal_dir]["model_count"] += 1
            
            if "error" not in stats:
                terminal_stats[terminal_dir]["avg_quality"] += stats["quality_score"]
                terminal_stats[terminal_dir]["avg_zero_ratio"] += stats["zero_ratio"]
        
        # 计算平均值
        for terminal in terminal_stats:
            count = terminal_stats[terminal]["model_count"]
            if count > 0:
                terminal_stats[terminal]["avg_quality"] /= count
                terminal_stats[terminal]["avg_zero_ratio"] /= count
        
        return terminal_stats
    
    def print_summary_report(self):
        """打印汇总分析报告"""
        if not self.summary_stats:
            print("❌ 没有分析数据可用")
            return
        
        print("\n" + "="*80)
        print("📊 模型分析汇总报告")
        print("="*80)
        
        # 基本统计
        print(f"\n📈 基本统计:")
        print(f"  总模型数: {self.summary_stats['total_models']}")
        print(f"  有效模型: {self.summary_stats['valid_models']}")
        print(f"  错误模型: {self.summary_stats['error_models']}")
        
        # 质量分布
        qd = self.summary_stats['quality_distribution']
        print(f"\n🎯 质量评分分布:")
        print(f"  平均值: {qd['mean']:.4f}")
        print(f"  标准差: {qd['std']:.4f}")
        print(f"  范围: [{qd['min']:.4f}, {qd['max']:.4f}]")
        print(f"  分位数 - 25%: {qd['percentiles']['25']:.4f}, 50%: {qd['percentiles']['50']:.4f}, 75%: {qd['percentiles']['75']:.4f}")
        
        # 零参数比例
        zrd = self.summary_stats['zero_ratio_distribution']
        print(f"\n🔢 零参数比例分布:")
        print(f"  平均值: {zrd['mean']:.4f}")
        print(f"  标准差: {zrd['std']:.4f}")
        print(f"  范围: [{zrd['min']:.4f}, {zrd['max']:.4f}]")
        
        # 问题模型
        pm = self.summary_stats['problem_models']
        print(f"\n⚠️  问题模型统计:")
        print(f"  高零参数比例 (>50%): {len(pm['high_zero_ratio'])} 个")
        print(f"  低质量评分 (<0.3): {len(pm['low_quality'])} 个")
        print(f"  加载错误: {len(pm['has_errors'])} 个")
        
        # 终端分布
        print(f"\n💻 终端分布:")
        for terminal, stats in self.summary_stats['terminal_distribution'].items():
            print(f"  {terminal}: {stats['model_count']} 模型, 平均质量: {stats['avg_quality']:.4f}, 平均零参数: {stats['avg_zero_ratio']:.4f}")
        
        # 改进建议
        self._print_improvement_suggestions()
    
    def _print_improvement_suggestions(self):
        """打印改进建议"""
        print(f"\n💡 改进建议:")
        
        if self.summary_stats['zero_ratio_distribution']['mean'] > 0.1:
            print("  🔸 零参数比例较高，建议检查训练过程和合并算法")
        
        if self.summary_stats['quality_distribution']['mean'] < 0.5:
            print("  🔸 整体模型质量较低，建议优化训练参数")
        
        pm = self.summary_stats['problem_models']
        if len(pm['high_zero_ratio']) > len(self.analysis_results) * 0.1:
            print("  🔸 超过10%的模型有高零参数比例，可能存在系统性问题")
        
        if len(pm['has_errors']) > 0:
            print("  🔸 存在加载错误的模型，建议检查模型文件完整性")
    
    def export_analysis_results(self, output_dir: str = "analysis"):
        """导出分析结果"""
        os.makedirs(output_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 导出详细分析结果
        detailed_file = os.path.join(output_dir, f"model_analysis_detailed_{timestamp}.json")
        with open(detailed_file, 'w', encoding='utf-8') as f:
            json.dump(self.analysis_results, f, indent=2, ensure_ascii=False)
        
        # 导出汇总统计
        summary_file = os.path.join(output_dir, f"model_analysis_summary_{timestamp}.json")
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(self.summary_stats, f, indent=2, ensure_ascii=False)
        
        print(f"💾 分析结果已导出:")
        print(f"  详细结果: {detailed_file}")
        print(f"  汇总统计: {summary_file}")

def main():
    """主函数"""
    analyzer = ModelAnalyzer()
    
    # 分析所有模型
    analyzer.analyze_all_models()
    
    # 打印汇总报告
    analyzer.print_summary_report()
    
    # 导出分析结果
    analyzer.export_analysis_results()

if __name__ == "__main__":
    main()
