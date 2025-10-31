"""
YoLightTransfer AI训练系统主程序
网络质量分析模型的渐进式训练系统
"""

import sys
import os
from pathlib import Path
import argparse
from datetime import datetime

# 添加src目录到Python路径
sys.path.append(str(Path(__file__).parent / 'src'))

from src.onnx_model.model_builder import ONNXModelBuilder
from src.data.loader import DataManager
from src.onnx_trainer.progressive_manager import ProgressiveTrainingManager
from src.utils.visualization import ReportGenerator
from src.hardware.benchmark import PerformanceBenchmark


class YoLightTrainer:
    """YoLightTransfer AI训练系统主类"""
    
    def __init__(self, config_file: str = None):
        """
        初始化训练系统
        
        Args:
            config_file: 配置文件路径
        """
        self.config_file = config_file
        self.config = self._load_config()
        self.model_builder = None
        self.data_manager = None
        self.training_manager = None
        
        # 创建必要的目录
        self._create_directories()
        
        print("=== YoLightTransfer AI训练系统 ===")
        print("网络质量分析模型的渐进式训练系统")
        print("=" * 50)
    
    def _load_config(self) -> dict:
        """加载配置文件"""
        default_config = {
            'model': {
                'input_size': 15,  # 特征数量
                'hidden_sizes': [64, 32, 16],
                'output_size': 3,  # 热点概率, 质量评分, 置信度
                'activation': 'relu',
                'dropout_rate': 0.2
            },
            'data': {
                'num_samples': 10000,
                'use_existing_data': True,
                'preprocess_config': {
                    'test_size': 0.2,
                    'validation_size': 0.1,
                    'feature_engineering': True
                }
            },
            'training': {
                'learning_rate': 0.001,
                'epochs': 100,
                'batch_size': 32,
                'early_stopping_patience': 10,
                'hardware_adaptive': True
            },
            'progressive': {
                'stages': [
                    {'name': 'warmup', 'epochs': 50, 'data_ratio': 0.1, 'lr': 0.01},
                    {'name': 'main', 'epochs': 100, 'data_ratio': 0.5, 'lr': 0.001},
                    {'name': 'refinement', 'epochs': 200, 'data_ratio': 1.0, 'lr': 0.0001}
                ],
                'enable_multi_task': True,
                'task_weights': [0.4, 0.4, 0.2]
            }
        }
        
        # 如果提供了配置文件，则加载并更新默认配置
        if self.config_file and os.path.exists(self.config_file):
            import json
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    user_config = json.load(f)
                # 深度更新配置
                self._deep_update(default_config, user_config)
                print(f"配置文件已加载: {self.config_file}")
            except Exception as e:
                print(f"配置文件加载失败: {e}，使用默认配置")
        
        return default_config
    
    def _deep_update(self, d: dict, u: dict):
        """深度更新字典"""
        for k, v in u.items():
            if isinstance(v, dict) and k in d and isinstance(d[k], dict):
                self._deep_update(d[k], v)
            else:
                d[k] = v
    
    def _create_directories(self):
        """创建必要的目录"""
        directories = [
            'checkpoints',
            'data/processed',
            'data/raw',
            'models',
            'reports',
            'training_results',
            'evaluation_results'
        ]
        
        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
        
        print("目录结构已创建")
    
    def setup_environment(self) -> bool:
        """
        设置训练环境
        
        Returns:
            设置是否成功
        """
        print("\n=== 设置训练环境 ===")
        
        try:
            # 1. 运行性能基准测试
            print("1. 运行性能基准测试...")
            benchmark = PerformanceBenchmark()
            benchmark_results = benchmark.run_comprehensive_benchmark()
            print("性能基准测试完成")
            
            # 2. 构建模型
            print("2. 构建ONNX模型...")
            self.model_builder = ONNXModelBuilder(self.config['model'])
            # 创建模型
            self.model_builder.create_model(self.config['model'].get('hidden_sizes', [64, 32, 16]))
            # 保存模型
            model_path = "checkpoints/network_quality_model.onnx"
            self.model_builder.save_model(model_path)
            print(f"模型已构建并保存到: {model_path}")
            
            # 3. 设置数据管理器
            print("3. 设置数据管理器...")
            self.data_manager = DataManager(
                data_dir="data",
                config=self.config['data']
            )
            print("数据管理器设置完成")
            
            # 4. 设置训练管理器
            print("4. 设置训练管理器...")
            self.training_manager = ProgressiveTrainingManager({
                'data_config': self.config['data'],
                'training_config': self.config['training'],
                'progressive_config': self.config['progressive']
            })
            
            # 设置训练环境
            if not self.training_manager.setup_training_environment():
                raise Exception("训练环境设置失败")
            
            print("训练环境设置完成!")
            return True
            
        except Exception as e:
            print(f"训练环境设置失败: {e}")
            return False
    
    def run_training(self) -> dict:
        """
        运行训练流程
        
        Returns:
            训练结果字典
        """
        if not hasattr(self, 'training_manager') or self.training_manager is None:
            print("请先设置训练环境")
            return {}
        
        print("\n=== 开始训练流程 ===")
        
        try:
            # 运行渐进式训练
            training_results = self.training_manager.run_progressive_training()
            
            # 保存训练结果
            self.training_manager.save_training_results()
            
            # 生成训练报告
            report_generator = ReportGenerator()
            report_dir = report_generator.generate_comprehensive_report(
                self.training_manager.training_results
            )
            
            print(f"\n训练完成!")
            print(f"训练报告已生成到: {report_dir}")
            
            return training_results
            
        except Exception as e:
            print(f"训练过程中出现错误: {e}")
            return {'error': str(e)}
    
    def evaluate_model(self, model_path: str = None) -> dict:
        """
        评估模型性能
        
        Args:
            model_path: 模型文件路径
            
        Returns:
            评估结果字典
        """
        if model_path is None:
            # 使用最新训练的模型
            model_path = "checkpoints/network_quality_model.onnx"
        
        if not os.path.exists(model_path):
            print(f"模型文件不存在: {model_path}")
            return {}
        
        print(f"\n=== 评估模型: {model_path} ===")
        
        try:
            # 加载数据
            data_manager = DataManager(data_dir="data", config=self.config['data'])
            data_loader = data_manager.setup_training_data()
            
            # 获取测试数据
            test_data = data_loader.data_splits['X_test'], data_loader.data_splits['y_test']
            
            # 创建训练器进行评估
            from src.onnx_trainer.trainer import ONNXTrainer
            trainer = ONNXTrainer(model_path=model_path)
            
            # 评估模型
            evaluation_results = trainer.evaluate(*test_data)
            
            print("模型评估完成!")
            return evaluation_results
            
        except Exception as e:
            print(f"模型评估失败: {e}")
            return {'error': str(e)}
    
    def generate_data(self, num_samples: int = 10000):
        """
        生成训练数据
        
        Args:
            num_samples: 样本数量
        """
        print(f"\n=== 生成训练数据 ({num_samples}个样本) ===")
        
        try:
            data_manager = DataManager(data_dir="data", config=self.config['data'])
            data_loader = data_manager.setup_training_data(
                num_samples=num_samples,
                use_existing=False  # 强制重新生成
            )
            
            # 显示数据摘要
            data_summary = data_loader.get_data_summary()
            print(data_summary)
            
            print("训练数据生成完成!")
            
        except Exception as e:
            print(f"数据生成失败: {e}")
    
    def show_system_info(self):
        """显示系统信息"""
        print("\n=== 系统信息 ===")
        
        # 硬件信息
        benchmark = PerformanceBenchmark()
        hardware_info = benchmark.hardware_detector.detect_hardware()
        
        print("硬件配置:")
        print(f"  CPU: {hardware_info['cpu']['vendor']} ({hardware_info['cpu']['logical_cores']}核心)")
        if hardware_info['gpu']['available']:
            print(f"  GPU: {hardware_info['gpu']['name']} ({hardware_info['gpu']['memory_gb']:.1f}GB)")
        else:
            print("  GPU: 不可用")
        print(f"  内存: {hardware_info['memory']['total_gb']:.1f}GB")
        
        # 软件信息
        print("\n软件环境:")
        print(f"  Python版本: {sys.version.split()[0]}")
        try:
            import onnxruntime as ort
            print(f"  ONNX Runtime版本: {ort.__version__}")
        except ImportError:
            print("  ONNX Runtime: 未安装")
        
        # 项目信息
        print("\n项目信息:")
        print("  YoLightTransfer AI训练系统")
        print("  网络质量分析模型的渐进式训练")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='YoLightTransfer AI训练系统')
    parser.add_argument('--config', type=str, help='配置文件路径')
    parser.add_argument('--mode', type=str, choices=['train', 'evaluate', 'generate_data', 'info'], 
                       default='train', help='运行模式')
    parser.add_argument('--model', type=str, help='模型文件路径（评估模式使用）')
    parser.add_argument('--samples', type=int, default=10000, help='生成数据样本数量')
    
    args = parser.parse_args()
    
    # 创建训练系统实例
    trainer = YoLightTrainer(config_file=args.config)
    
    # 根据模式执行相应操作
    if args.mode == 'info':
        trainer.show_system_info()
    
    elif args.mode == 'generate_data':
        trainer.generate_data(num_samples=args.samples)
    
    elif args.mode == 'evaluate':
        if args.model:
            results = trainer.evaluate_model(args.model)
            print("评估结果:", results)
        else:
            print("请提供模型文件路径: --model <path>")
    
    elif args.mode == 'train':
        # 设置环境
        if trainer.setup_environment():
            # 运行训练
            results = trainer.run_training()
            print("训练结果:", results)
        else:
            print("训练环境设置失败，无法进行训练")
    
    else:
        print("未知的运行模式")


if __name__ == "__main__":
    main()
