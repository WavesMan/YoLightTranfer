# language: python
import os
import sys
import time
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

class ModelMerger:
    """模型合并监听器 - 定期整理合并所有小模型到最佳模型"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.models_dir = self.cfg.data.models_dir
        self.checkpoint_dir = self.cfg.data.checkpoint_dir
        self.merged_file = os.path.join(self.models_dir, "merged_models.json")
        self.best_model_path = os.path.join(self.checkpoint_dir, "best_model.pth")
        self.model_stats_file = os.path.join(self.checkpoint_dir, "model_statistics.json")
        
        # 确保目录存在
        os.makedirs(self.checkpoint_dir, exist_ok=True)
        
        # 初始化合并记录
        self.merged_models = self._load_merged_records()
        self.model_statistics = self._load_model_statistics()
        
    def _load_merged_records(self) -> dict:
        """加载已合并模型记录"""
        try:
            if os.path.exists(self.merged_file):
                with open(self.merged_file, 'r') as f:
                    return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            pass
        return {"merged_models": [], "last_merge_time": None, "merge_count": 0}
    
    def _save_merged_records(self):
        """保存合并记录"""
        with open(self.merged_file, 'w') as f:
            json.dump(self.merged_models, f, indent=2)
    
    def _load_model_statistics(self) -> dict:
        """加载模型统计信息"""
        try:
            if os.path.exists(self.model_stats_file):
                with open(self.model_stats_file, 'r') as f:
                    return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            pass
        return {
            "merge_history": [],
            "parameter_statistics": {},
            "model_evolution": [],
            "last_update": None
        }
    
    def _save_model_statistics(self):
        """保存模型统计信息"""
        with open(self.model_stats_file, 'w') as f:
            json.dump(self.model_statistics, f, indent=2)
    
    def _analyze_model_parameters(self, model: NetworkQualityModel) -> dict:
        """分析模型参数统计"""
        params = dict(model.named_parameters())
        stats = {
            "total_parameters": 0,
            "layer_statistics": {},
            "parameter_ranges": {},
            "gradient_statistics": {}
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
                    "max": 0.0
                }
            
            layer_stats = stats["layer_statistics"][layer_name]
            layer_stats["parameter_count"] += param_count
            
            # 参数值统计
            param_data = param.data.cpu().numpy()
            layer_stats["mean"] = float(param_data.mean())
            layer_stats["std"] = float(param_data.std())
            layer_stats["min"] = float(param_data.min())
            layer_stats["max"] = float(param_data.max())
            
            # 参数范围
            stats["parameter_ranges"][name] = {
                "min": float(param_data.min()),
                "max": float(param_data.max()),
                "mean": float(param_data.mean()),
                "std": float(param_data.std())
            }
        
        return stats
    
    def _record_merge_statistics(self, best_model: NetworkQualityModel, merged_count: int, unmerged_models: list):
        """记录合并统计信息"""
        timestamp = datetime.now().isoformat()
        
        # 分析当前最佳模型参数
        model_stats = self._analyze_model_parameters(best_model)
        
        # 记录合并历史
        merge_record = {
            "timestamp": timestamp,
            "merged_models_count": len(unmerged_models),
            "total_merge_count": merged_count,
            "model_statistics": model_stats,
            "unmerged_models": unmerged_models
        }
        
        # 更新统计信息
        self.model_statistics["merge_history"].append(merge_record)
        self.model_statistics["parameter_statistics"] = model_stats
        self.model_statistics["last_update"] = timestamp
        
        # 记录模型演化
        evolution_record = {
            "timestamp": timestamp,
            "merge_count": merged_count,
            "total_parameters": model_stats["total_parameters"],
            "layer_count": len(model_stats["layer_statistics"])
        }
        self.model_statistics["model_evolution"].append(evolution_record)
        
        # 保存统计信息
        self._save_model_statistics()
        
        # 打印统计摘要
        self._print_statistics_summary(model_stats, merged_count, len(unmerged_models))
    
    def _print_statistics_summary(self, stats: dict, total_merge_count: int, current_merge_count: int):
        """打印统计摘要"""
        print(f"\n📊 模型参数统计:")
        print(f"  总参数数量: {stats['total_parameters']:,}")
        print(f"  网络层数: {len(stats['layer_statistics'])}")
        print(f"  累计合并次数: {total_merge_count}")
        print(f"  本次合并模型数: {current_merge_count}")
        
        print(f"\n📈 各层参数统计:")
        for layer_name, layer_stats in stats["layer_statistics"].items():
            print(f"  {layer_name}: {layer_stats['parameter_count']:,} 参数")
            print(f"    均值: {layer_stats['mean']:.6f}, 标准差: {layer_stats['std']:.6f}")
            print(f"    范围: [{layer_stats['min']:.6f}, {layer_stats['max']:.6f}]")
    
    def _get_all_models(self) -> list:
        """获取所有模型文件路径"""
        pattern = os.path.join(self.models_dir, "terminal_*", "model_iter_*.pth")
        return glob.glob(pattern)
    
    def _get_unmerged_models(self) -> list:
        """获取未合并的模型"""
        all_models = self._get_all_models()
        merged_set = set(self.merged_models.get("merged_models", []))
        return [model for model in all_models if model not in merged_set]
    
    def _load_best_model(self) -> NetworkQualityModel:
        """加载最佳模型，如果不存在则创建新模型"""
        model = NetworkQualityModel(
            input_size=self.cfg.model.input_size,
            hidden_sizes=tuple(self.cfg.model.hidden_sizes),
            dropout_rate=self.cfg.model.dropout_rate,
            use_batch_norm=self.cfg.model.use_batch_norm
        )
        
        if os.path.exists(self.best_model_path):
            print(f"📥 加载现有最佳模型: {self.best_model_path}")
            model.load_model(self.best_model_path)
        else:
            print("🆕 创建新的最佳模型")
            
        return model
    
    def _load_small_model(self, model_path: str) -> NetworkQualityModel:
        """加载小模型"""
        model = NetworkQualityModel(
            input_size=self.cfg.model.input_size,
            hidden_sizes=tuple(self.cfg.model.hidden_sizes),
            dropout_rate=self.cfg.model.dropout_rate,
            use_batch_norm=self.cfg.model.use_batch_norm
        )
        model.load_model(model_path)
        return model
    
    def federated_average_merge(self, models: list, weights: list = None) -> NetworkQualityModel:
        """联邦平均合并算法"""
        if weights is None:
            weights = [1.0] * len(models)
        
        total_weight = sum(weights)
        print(f"🧠 联邦平均合并: {len(models)} 个模型, 总权重: {total_weight}")
        
        # 创建新模型
        merged_model = NetworkQualityModel(
            input_size=self.cfg.model.input_size,
            hidden_sizes=tuple(self.cfg.model.hidden_sizes),
            dropout_rate=self.cfg.model.dropout_rate,
            use_batch_norm=self.cfg.model.use_batch_norm
        )
        
        # 获取所有模型的参数
        all_params = []
        for model in models:
            all_params.append(dict(model.named_parameters()))
        
        # 计算加权平均参数
        avg_params = {}
        for name in all_params[0].keys():
            param_sum = torch.zeros_like(all_params[0][name].data)
            for i, params in enumerate(all_params):
                param_sum += weights[i] * params[name].data
            avg_params[name] = param_sum / total_weight
        
        # 设置合并后的参数
        for name, param in merged_model.named_parameters():
            if name in avg_params:
                param.data.copy_(avg_params[name])
        
        return merged_model
    
    def evaluate_model_performance(self, model: NetworkQualityModel, test_data=None) -> float:
        """评估模型性能（简化版本）"""
        # 这里可以使用验证集进行实际评估
        # 暂时使用模型参数质量作为性能指标
        params = dict(model.named_parameters())
        total_params = 0
        valid_params = 0
        
        for name, param in params.items():
            param_data = param.data.cpu().numpy()
            total_params += param.numel()
            # 检查参数是否有效（非零、非NaN、非Inf）
            valid_params += np.sum(np.isfinite(param_data) & (param_data != 0))
        
        if total_params == 0:
            return 0.0
        
        return valid_params / total_params
    
    def merge_models(self):
        """使用联邦平均算法合并所有未合并的小模型"""
        print("🔍 开始扫描未合并的模型...")
        
        # 获取未合并的模型
        unmerged_models = self._get_unmerged_models()
        
        if not unmerged_models:
            print("✅ 没有发现新的未合并模型")
            return
        
        print(f"📊 发现 {len(unmerged_models)} 个未合并模型")
        
        # 加载所有小模型
        small_models = []
        performance_scores = []
        
        print("📥 加载所有小模型...")
        for i, model_path in enumerate(unmerged_models, 1):
            print(f"  加载进度: {i}/{len(unmerged_models)} - {os.path.basename(model_path)}")
            
            try:
                # 加载小模型
                small_model = self._load_small_model(model_path)
                small_models.append(small_model)
                
                # 评估模型性能
                performance = self.evaluate_model_performance(small_model)
                performance_scores.append(performance)
                
                print(f"    ✅ 加载成功, 性能评分: {performance:.4f}")
                
            except Exception as e:
                print(f"    ❌ 加载失败: {e}")
                continue
        
        if not small_models:
            print("❌ 没有成功加载任何模型")
            return
        
        print(f"🎯 模型性能统计:")
        print(f"  平均性能: {np.mean(performance_scores):.4f}")
        print(f"  最高性能: {np.max(performance_scores):.4f}")
        print(f"  最低性能: {np.min(performance_scores):.4f}")
        
        # 使用联邦平均算法合并
        print("🧠 开始联邦平均合并...")
        best_model = self.federated_average_merge(small_models, performance_scores)
        
        # 保存合并后的最佳模型
        best_model.save_model(self.best_model_path)
        
        # 更新合并记录
        self.merged_models["last_merge_time"] = datetime.now().isoformat()
        self.merged_models["merge_count"] = len(unmerged_models)
        self.merged_models["merged_models"].extend(unmerged_models)
        self._save_merged_records()
        
        # 记录模型参数统计
        self._record_merge_statistics(best_model, len(unmerged_models), unmerged_models)
        
        print(f"\n🎉 联邦平均合并完成!")
        print(f"📈 本次合并了 {len(small_models)} 个模型")
        print(f"📊 累计合并次数: {len(unmerged_models)}")
        print(f"💾 最佳模型已保存: {self.best_model_path}")
    
    def run_continuous(self, interval_minutes: int = 5):
        """持续运行合并监听器"""
        print(f"🚀 启动模型合并监听器")
        print(f"⏰ 检查间隔: {interval_minutes} 分钟")
        print(f"📁 模型目录: {self.models_dir}")
        print(f"💾 最佳模型: {self.best_model_path}")
        
        try:
            while True:
                print(f"\n{'='*50}")
                print(f"🕐 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 开始检查...")
                
                self.merge_models()
                
                print(f"⏳ 等待 {interval_minutes} 分钟后再次检查...")
                time.sleep(interval_minutes * 60)
                
        except KeyboardInterrupt:
            print("\n🛑 手动停止模型合并监听器")
        except Exception as e:
            print(f"❌ 监听器异常: {e}")

def single_merge():
    """单次合并操作"""
    merger = ModelMerger()
    merger.merge_models()

def continuous_merge(interval_minutes: int = 5):
    """持续合并操作"""
    merger = ModelMerger()
    merger.run_continuous(interval_minutes)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="模型合并监听器")
    parser.add_argument("--mode", choices=["single", "continuous"], default="single",
                       help="运行模式: single(单次) 或 continuous(持续)")
    parser.add_argument("--interval", type=int, default=5,
                       help="持续模式下的检查间隔(分钟)")
    
    args = parser.parse_args()
    
    if args.mode == "continuous":
        continuous_merge(args.interval)
    else:
        single_merge()
