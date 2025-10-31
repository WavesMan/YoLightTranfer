"""
渐进式训练管理器
管理渐进式训练策略和流程
"""

import numpy as np
from typing import Dict, List, Tuple, Optional, Callable
import time
import json
from pathlib import Path
from datetime import datetime
from .trainer import ONNXTrainer, ProgressiveTrainer, MultiTaskTrainer
from ..data.loader import DataLoader, DataManager
from ..hardware.benchmark import PerformanceBenchmark


class ProgressiveTrainingManager:
    """渐进式训练管理器 - 管理完整的渐进式训练流程"""
    
    def __init__(self, config: Dict = None):
        """
        初始化渐进式训练管理器
        
        Args:
            config: 训练管理器配置
        """
        self.config = config or {}
        self.data_manager = None
        self.trainer = None
        self.training_results = {}
        
        # 默认配置
        self.default_config = {
            'data_config': {
                'num_samples': 10000,
                'use_existing_data': True,
                'preprocess_config': {
                    'test_size': 0.2,
                    'validation_size': 0.1,
                    'feature_engineering': True
                }
            },
            'training_config': {
                'learning_rate': 0.001,
                'epochs': 100,
                'batch_size': 32,
                'early_stopping_patience': 10,
                'hardware_adaptive': True
            },
            'progressive_config': {
                'stages': [
                    {'name': 'warmup', 'epochs': 50, 'data_ratio': 0.1, 'lr': 0.01},
                    {'name': 'main', 'epochs': 100, 'data_ratio': 0.5, 'lr': 0.001},
                    {'name': 'refinement', 'epochs': 200, 'data_ratio': 1.0, 'lr': 0.0001}
                ],
                'enable_multi_task': True,
                'task_weights': [0.4, 0.4, 0.2]
            },
            'monitoring_config': {
                'save_checkpoints': True,
                'checkpoint_interval': 10,
                'log_metrics': True,
                'performance_monitoring': True
            }
        }
        
        # 更新配置
        self.default_config.update(self.config)
        self.config = self.default_config
    
    def setup_training_environment(self) -> bool:
        """
        设置训练环境
        
        Returns:
            设置是否成功
        """
        print("设置训练环境...")
        
        try:
            # 1. 设置数据管理器
            self.data_manager = DataManager(
                data_dir="data",
                config=self.config['data_config']
            )
            
            # 2. 加载或生成数据
            self.data_loader = self.data_manager.setup_training_data(
                num_samples=self.config['data_config']['num_samples'],
                use_existing=self.config['data_config']['use_existing_data']
            )
            
            # 3. 运行性能基准测试
            if self.config['training_config']['hardware_adaptive']:
                self._run_performance_benchmark()
            
            # 4. 创建模型训练器
            self._create_trainer()
            
            print("训练环境设置完成!")
            return True
            
        except Exception as e:
            print(f"训练环境设置失败: {e}")
            return False
    
    def _run_performance_benchmark(self):
        """运行性能基准测试"""
        print("运行性能基准测试...")
        
        benchmark = PerformanceBenchmark()
        results = benchmark.run_comprehensive_benchmark()
        
        # 根据性能结果调整配置
        overall_score = results['overall_score']
        
        if overall_score < 30:
            # 低性能系统，减少批次大小
            self.config['training_config']['batch_size'] = max(8, self.config['training_config']['batch_size'] // 2)
            print("检测到低性能系统，调整批次大小")
        elif overall_score > 80:
            # 高性能系统，增加批次大小
            self.config['training_config']['batch_size'] = min(128, self.config['training_config']['batch_size'] * 2)
            print("检测到高性能系统，调整批次大小")
        
        # 保存基准测试结果
        self.training_results['benchmark'] = results
    
    def _create_trainer(self):
        """创建训练器"""
        # 这里需要先有模型文件，暂时使用占位符
        model_path = "checkpoints/network_quality_model.onnx"  # 假设的模型路径
        
        # 创建基础训练器
        base_trainer = ONNXTrainer(
            model_path=model_path,
            config=self.config['training_config']
        )
        
        # 创建渐进式训练器
        progressive_config = self.config['progressive_config']
        self.trainer = ProgressiveTrainer(base_trainer, {
            'progressive_epochs': [stage['epochs'] for stage in progressive_config['stages']],
            'progressive_learning_rates': [stage['lr'] for stage in progressive_config['stages']],
            'data_subsets': [stage['data_ratio'] for stage in progressive_config['stages']]
        })
        
        # 如果启用多任务训练，包装多任务训练器
        if progressive_config['enable_multi_task']:
            self.trainer = MultiTaskTrainer(
                self.trainer.base_trainer,
                {'task_weights': progressive_config['task_weights']}
            )
    
    def run_progressive_training(self) -> Dict:
        """
        运行渐进式训练
        
        Returns:
            训练结果字典
        """
        if self.trainer is None or self.data_loader is None:
            raise ValueError("请先设置训练环境")
        
        print("开始渐进式训练...")
        training_start_time = time.time()
        
        # 获取训练数据
        training_data = self.data_manager.get_data_for_training(
            batch_size=self.config['training_config']['batch_size']
        )
        
        # 执行训练
        try:
            if isinstance(self.trainer, MultiTaskTrainer):
                # 多任务训练
                result = self.trainer.multi_task_train(
                    (training_data['train_data'][0], training_data['train_data'][1]),
                    training_data['val_data']
                )
            elif isinstance(self.trainer, ProgressiveTrainer):
                # 渐进式训练
                result = self.trainer.progressive_train(
                    (training_data['train_data'][0], training_data['train_data'][1]),
                    training_data['val_data']
                )
            else:
                # 基础训练
                result = self.trainer.train(
                    (training_data['train_data'][0], training_data['train_data'][1]),
                    training_data['val_data']
                )
            
            # 记录训练结果
            result['total_training_time'] = time.time() - training_start_time
            result['dataset_info'] = training_data['dataset_info']
            self.training_results['training'] = result
            
            # 评估模型性能
            self._evaluate_model_performance(training_data['test_data'])
            
            print("渐进式训练完成!")
            return result
            
        except Exception as e:
            print(f"训练过程中出现错误: {e}")
            return {'error': str(e)}
    
    def _evaluate_model_performance(self, test_data: Tuple[np.ndarray, np.ndarray]):
        """评估模型性能"""
        print("评估模型性能...")
        
        X_test, y_test = test_data
        
        # 使用训练器评估
        if hasattr(self.trainer, 'evaluate'):
            evaluation_results = self.trainer.evaluate(X_test, y_test)
            self.training_results['evaluation'] = evaluation_results
        
        # 计算额外指标
        additional_metrics = self._compute_additional_metrics(X_test, y_test)
        self.training_results['additional_metrics'] = additional_metrics
    
    def _compute_additional_metrics(self, X_test: np.ndarray, y_test: np.ndarray) -> Dict:
        """计算额外评估指标"""
        metrics = {}
        
        # 获取预测
        y_pred = self.trainer.predict(X_test)
        
        # 计算每个目标的准确率（对于分类任务）
        for i in range(y_test.shape[1]):
            # 假设目标在 [0, 1] 范围内，转换为二分类
            y_true_binary = (y_test[:, i] > 0.5).astype(int)
            y_pred_binary = (y_pred[:, i] > 0.5).astype(int)
            
            accuracy = np.mean(y_true_binary == y_pred_binary)
            metrics[f'target_{i}_accuracy'] = float(accuracy)
        
        # 计算相关性
        for i in range(y_test.shape[1]):
            correlation = np.corrcoef(y_test[:, i], y_pred[:, i])[0, 1]
            metrics[f'target_{i}_correlation'] = float(correlation)
        
        return metrics
    
    def save_training_results(self, save_dir: str = "training_results"):
        """
        保存训练结果
        
        Args:
            save_dir: 保存目录
        """
        save_path = Path(save_dir)
        save_path.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 保存训练结果
        results_file = save_path / f"training_results_{timestamp}.json"
        with open(results_file, 'w') as f:
            json.dump(self.training_results, f, indent=2, ensure_ascii=False)
        
        # 保存配置
        config_file = save_path / f"training_config_{timestamp}.json"
        with open(config_file, 'w') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
        
        print(f"训练结果已保存到: {save_path}")
    
    def generate_training_report(self) -> str:
        """生成训练报告"""
        if not self.training_results:
            return "训练尚未执行"
        
        report = []
        report.append("=== 渐进式训练报告 ===")
        report.append("")
        
        # 训练基本信息
        if 'training' in self.training_results:
            training_info = self.training_results['training']
            report.append("训练信息:")
            report.append(f"  总轮次: {training_info.get('total_epochs', 'N/A')}")
            report.append(f"  最佳轮次: {training_info.get('best_epoch', 'N/A')}")
            report.append(f"  最终训练损失: {training_info.get('final_train_loss', 'N/A'):.6f}")
            report.append(f"  最终验证损失: {training_info.get('final_val_loss', 'N/A'):.6f}")
            report.append(f"  总训练时间: {training_info.get('total_training_time', 'N/A'):.2f}秒")
            report.append("")
        
        # 评估结果
        if 'evaluation' in self.training_results:
            eval_info = self.training_results['evaluation']
            report.append("评估结果:")
            for metric, value in eval_info.items():
                if isinstance(value, (int, float)):
                    report.append(f"  {metric}: {value:.6f}")
            report.append("")
        
        # 额外指标
        if 'additional_metrics' in self.training_results:
            additional_metrics = self.training_results['additional_metrics']
            report.append("额外指标:")
            for metric, value in additional_metrics.items():
                if isinstance(value, (int, float)):
                    report.append(f"  {metric}: {value:.6f}")
            report.append("")
        
        # 硬件信息
        if 'benchmark' in self.training_results:
            benchmark = self.training_results['benchmark']
            report.append("硬件性能:")
            report.append(f"  综合性能评分: {benchmark.get('overall_score', 'N/A'):.1f}/100")
            report.append("")
        
        return "\n".join(report)
    
    def get_training_progress(self) -> Dict:
        """获取训练进度"""
        if not hasattr(self.trainer, 'training_history'):
            return {'status': 'training_not_started'}
        
        progress = {
            'status': 'training_in_progress',
            'current_epoch': len(self.trainer.training_history) if self.trainer.training_history else 0,
            'total_epochs': self.config['training_config']['epochs']
        }
        
        if self.trainer.training_history:
            latest_epoch = self.trainer.training_history[-1]
            progress.update({
                'current_train_loss': latest_epoch['train_loss'],
                'current_val_loss': latest_epoch.get('val_loss', None),
                'epoch_time': latest_epoch['epoch_time']
            })
        
        return progress


class TrainingMonitor:
    """训练监控器 - 实时监控训练过程"""
    
    def __init__(self, training_manager: ProgressiveTrainingManager):
        """
        初始化训练监控器
        
        Args:
            training_manager: 训练管理器实例
        """
        self.training_manager = training_manager
        self.monitoring_data = []
    
    def start_monitoring(self, update_interval: int = 10):
        """
        开始监控训练过程
        
        Args:
            update_interval: 更新间隔（秒）
        """
        print("开始训练监控...")
        
        # 这里可以实现实时监控逻辑
        # 在实际应用中，可以使用线程或异步任务来监控
        
        print(f"监控间隔: {update_interval}秒")
        print("监控已启动（在实际实现中会实时更新）")
    
    def get_monitoring_summary(self) -> Dict:
        """获取监控摘要"""
        progress = self.training_manager.get_training_progress()
        
        summary = {
            'progress': progress,
            'monitoring_points': len(self.monitoring_data),
            'latest_metrics': self.monitoring_data[-1] if self.monitoring_data else {}
        }
        
        return summary


class TrainingAnalyzer:
    """训练分析器 - 分析训练结果和性能"""
    
    def __init__(self, training_results: Dict):
        """
        初始化训练分析器
        
        Args:
            training_results: 训练结果字典
        """
        self.training_results = training_results
    
    def analyze_training_performance(self) -> Dict:
        """分析训练性能"""
        analysis = {}
        
        if 'training' not in self.training_results:
            return {'error': '训练结果不存在'}
        
        training_info = self.training_results['training']
        
        # 分析训练效率
        total_time = training_info.get('total_training_time', 0)
        total_epochs = training_info.get('total_epochs', 1)
        
        analysis['training_efficiency'] = {
            'epochs_per_minute': total_epochs / (total_time / 60) if total_time > 0 else 0,
            'average_epoch_time': total_time / total_epochs if total_epochs > 0 else 0,
            'total_training_time': total_time
        }
        
        # 分析收敛性
        if hasattr(self.training_results, 'training_history'):
            training_history = self.training_results.training_history
            if training_history:
                # 计算收敛速度
                initial_loss = training_history[0]['train_loss']
                final_loss = training_history[-1]['train_loss']
                convergence_rate = (initial_loss - final_loss) / len(training_history)
                
                analysis['convergence'] = {
                    'initial_loss': initial_loss,
                    'final_loss': final_loss,
                    'convergence_rate': convergence_rate,
                    'improvement_ratio': (initial_loss - final_loss) / initial_loss if initial_loss > 0 else 0
                }
        
        # 分析模型质量
        if 'evaluation' in self.training_results:
            eval_info = self.training_results['evaluation']
            analysis['model_quality'] = {
                'mse': eval_info.get('mse', 0),
                'mae': eval_info.get('mae', 0),
                'r2': eval_info.get('r2', 0)
            }
        
        return analysis
    
    def generate_recommendations(self) -> List[str]:
        """生成优化建议"""
        recommendations = []
        
        analysis = self.analyze_training_performance()
        
        # 基于分析结果生成建议
        if 'training_efficiency' in analysis:
            efficiency = analysis['training_efficiency']
            
            if efficiency['average_epoch_time'] > 10:
                recommendations.append("训练速度较慢，建议优化数据加载或减少模型复杂度")
            
            if efficiency['epochs_per_minute'] < 1:
                recommendations.append("训练效率较低，建议增加批次大小或使用GPU加速")
        
        if 'convergence' in analysis:
            convergence = analysis['convergence']
            
            if convergence['improvement_ratio'] < 0.1:
                recommendations.append("模型收敛较慢，建议调整学习率或优化器参数")
            
            if convergence['convergence_rate'] < 0.001:
                recommendations.append("收敛速度较慢，建议检查数据质量或增加训练轮次")
        
        if 'model_quality' in analysis:
            quality = analysis['model_quality']
            
            if quality['mse'] > 0.1:
                recommendations.append("模型预测误差较大，建议增加训练数据或调整模型结构")
            
            if quality['r2'] < 0.7:
                recommendations.append("模型解释能力不足，建议优化特征工程或增加模型复杂度")
        
        return recommendations


if __name__ == "__main__":
    # 测试渐进式训练管理器
    print("测试渐进式训练管理器...")
    
    # 创建训练管理器
    manager = ProgressiveTrainingManager()
    
    # 设置训练环境
    if manager.setup_training_environment():
        print("训练环境设置成功")
        
        # 生成训练报告（模拟）
        report = manager.generate_training_report()
        print(report)
    else:
        print("训练环境设置失败")
    
    print("渐进式训练管理器实现完成!")
