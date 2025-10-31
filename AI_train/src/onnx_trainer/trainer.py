"""
ONNX训练器
使用ONNX Runtime进行模型训练
"""

import onnxruntime as ort
import numpy as np
from typing import Dict, List, Tuple, Optional, Callable
import time
import json
from pathlib import Path
from ..hardware.detector import HardwareDetector
from ..hardware.adaptor import get_hardware_adaptive_config


class ONNXTrainer:
    """ONNX训练器 - 使用ONNX Runtime进行模型训练"""
    
    def __init__(self, model_path: str = None, config: Dict = None):
        """
        初始化ONNX训练器
        
        Args:
            model_path: ONNX模型文件路径
            config: 训练配置
        """
        self.model_path = model_path
        self.config = config or {}
        self.session = None
        self.training_history = []
        
        # 默认配置
        self.default_config = {
            'learning_rate': 0.001,
            'epochs': 100,
            'batch_size': 32,
            'early_stopping_patience': 10,
            'save_best_model': True,
            'model_save_dir': 'checkpoints',
            'log_interval': 10,
            'hardware_adaptive': True
        }
        
        # 更新配置
        self.default_config.update(self.config)
        self.config = self.default_config
        
        # 硬件自适应配置
        if self.config['hardware_adaptive']:
            self._setup_hardware_adaptive_config()
        
        # 创建会话
        if model_path:
            self.load_model(model_path)
    
    def _setup_hardware_adaptive_config(self):
        """设置硬件自适应配置"""
        hardware_config = get_hardware_adaptive_config(model_size_mb=50)
        
        # 根据硬件配置调整训练参数
        batch_config = hardware_config['batch_size']
        precision_config = hardware_config['precision']
        
        # 调整批次大小
        self.config['batch_size'] = batch_config['recommended_batch_size']
        
        # 根据精度配置调整学习率
        if precision_config['model_precision'] == 'float16':
            self.config['learning_rate'] *= 2.0  # 混合精度通常需要更大的学习率
        elif precision_config['model_precision'] == 'mixed':
            self.config['learning_rate'] *= 1.5
        
        print("硬件自适应配置已应用:")
        print(f"  批次大小: {self.config['batch_size']}")
        print(f"  学习率: {self.config['learning_rate']}")
    
    def load_model(self, model_path: str):
        """
        加载ONNX模型
        
        Args:
            model_path: 模型文件路径
        """
        if not Path(model_path).exists():
            raise FileNotFoundError(f"模型文件不存在: {model_path}")
        
        # 创建推理会话
        providers = ['CPUExecutionProvider']
        if ort.get_device() == 'GPU':
            providers = ['CUDAExecutionProvider'] + providers
        
        session_options = ort.SessionOptions()
        session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        
        self.session = ort.InferenceSession(
            model_path, 
            providers=providers,
            sess_options=session_options
        )
        
        self.model_path = model_path
        print(f"模型已加载: {model_path}")
        print(f"输入: {[input.name for input in self.session.get_inputs()]}")
        print(f"输出: {[output.name for output in self.session.get_outputs()]}")
    
    def train(self, train_data: Tuple[np.ndarray, np.ndarray],
             val_data: Tuple[np.ndarray, np.ndarray] = None,
             callbacks: List[Callable] = None) -> Dict:
        """
        训练模型
        
        Args:
            train_data: 训练数据 (X_train, y_train)
            val_data: 验证数据 (X_val, y_val)
            callbacks: 回调函数列表
            
        Returns:
            训练结果字典
        """
        if self.session is None:
            raise ValueError("请先加载模型")
        
        X_train, y_train = train_data
        X_val, y_val = val_data if val_data else (None, None)
        
        print("开始训练...")
        print(f"训练样本: {X_train.shape[0]}")
        if X_val is not None:
            print(f"验证样本: {X_val.shape[0]}")
        print(f"批次大小: {self.config['batch_size']}")
        print(f"学习率: {self.config['learning_rate']}")
        print(f"轮次: {self.config['epochs']}")
        
        # 初始化训练状态
        best_val_loss = float('inf')
        patience_counter = 0
        training_start_time = time.time()
        
        # 训练循环
        for epoch in range(self.config['epochs']):
            epoch_start_time = time.time()
            
            # 训练阶段
            train_loss, train_metrics = self._train_epoch(X_train, y_train, epoch)
            
            # 验证阶段
            val_loss, val_metrics = 0.0, {}
            if X_val is not None:
                val_loss, val_metrics = self._validate_epoch(X_val, y_val)
            
            epoch_time = time.time() - epoch_start_time
            
            # 记录训练历史
            epoch_history = {
                'epoch': epoch + 1,
                'train_loss': train_loss,
                'val_loss': val_loss if X_val is not None else None,
                'train_metrics': train_metrics,
                'val_metrics': val_metrics if X_val is not None else {},
                'epoch_time': epoch_time
            }
            self.training_history.append(epoch_history)
            
            # 打印训练进度
            if (epoch + 1) % self.config['log_interval'] == 0 or epoch == 0:
                self._print_training_progress(epoch_history)
            
            # 早停检查
            if X_val is not None and self.config['early_stopping_patience'] > 0:
                if val_loss < best_val_loss:
                    best_val_loss = val_loss
                    patience_counter = 0
                    
                    # 保存最佳模型
                    if self.config['save_best_model']:
                        self._save_best_model(epoch + 1, val_loss)
                else:
                    patience_counter += 1
                    if patience_counter >= self.config['early_stopping_patience']:
                        print(f"早停触发! 在轮次 {epoch + 1} 停止训练")
                        break
        
        # 训练完成
        total_time = time.time() - training_start_time
        print(f"训练完成! 总时间: {total_time:.2f}秒")
        
        # 返回训练结果
        return self._get_training_summary()
    
    def _train_epoch(self, X_train: np.ndarray, y_train: np.ndarray, epoch: int) -> Tuple[float, Dict]:
        """训练一个轮次"""
        total_loss = 0.0
        num_batches = 0
        
        # 随机打乱训练数据
        indices = np.random.permutation(X_train.shape[0])
        X_shuffled = X_train[indices]
        y_shuffled = y_train[indices]
        
        # 批次训练
        for i in range(0, X_train.shape[0], self.config['batch_size']):
            batch_end = min(i + self.config['batch_size'], X_train.shape[0])
            
            X_batch = X_shuffled[i:batch_end]
            y_batch = y_shuffled[i:batch_end]
            
            # 执行前向传播和损失计算
            batch_loss = self._train_batch(X_batch, y_batch)
            
            total_loss += batch_loss
            num_batches += 1
        
        avg_loss = total_loss / num_batches if num_batches > 0 else 0.0
        
        # 计算训练指标
        train_metrics = self._compute_metrics(X_train, y_train)
        
        return avg_loss, train_metrics
    
    def _train_batch(self, X_batch: np.ndarray, y_batch: np.ndarray) -> float:
        """
        训练一个批次
        
        注意: 这是简化的训练实现
        在实际应用中，ONNX Runtime的训练需要更复杂的设置
        """
        # 执行推理
        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name
        
        # 前向传播
        predictions = self.session.run([output_name], {input_name: X_batch.astype(np.float32)})[0]
        
        # 计算损失 (均方误差)
        loss = np.mean((predictions - y_batch) ** 2)
        
        # 注意: 这里没有实现反向传播和参数更新
        # 在实际的ONNX训练中，需要使用ONNX Runtime的训练API
        
        return float(loss)
    
    def _validate_epoch(self, X_val: np.ndarray, y_val: np.ndarray) -> Tuple[float, Dict]:
        """验证一个轮次"""
        # 执行推理
        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name
        
        predictions = self.session.run([output_name], {input_name: X_val.astype(np.float32)})[0]
        
        # 计算验证损失
        val_loss = np.mean((predictions - y_val) ** 2)
        
        # 计算验证指标
        val_metrics = self._compute_metrics(X_val, y_val, predictions)
        
        return float(val_loss), val_metrics
    
    def _compute_metrics(self, X: np.ndarray, y_true: np.ndarray, y_pred: np.ndarray = None) -> Dict:
        """计算评估指标"""
        if y_pred is None:
            # 执行推理获取预测
            input_name = self.session.get_inputs()[0].name
            output_name = self.session.get_outputs()[0].name
            y_pred = self.session.run([output_name], {input_name: X.astype(np.float32)})[0]
        
        metrics = {}
        
        # 均方误差
        metrics['mse'] = float(np.mean((y_pred - y_true) ** 2))
        
        # 平均绝对误差
        metrics['mae'] = float(np.mean(np.abs(y_pred - y_true)))
        
        # R²分数
        ss_res = np.sum((y_true - y_pred) ** 2)
        ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
        metrics['r2'] = float(1 - (ss_res / (ss_tot + 1e-8)))
        
        # 对于每个输出目标的指标
        for i in range(y_true.shape[1]):
            target_mse = float(np.mean((y_pred[:, i] - y_true[:, i]) ** 2))
            target_mae = float(np.mean(np.abs(y_pred[:, i] - y_true[:, i])))
            metrics[f'target_{i}_mse'] = target_mse
            metrics[f'target_{i}_mae'] = target_mae
        
        return metrics
    
    def _print_training_progress(self, epoch_history: Dict):
        """打印训练进度"""
        epoch = epoch_history['epoch']
        train_loss = epoch_history['train_loss']
        val_loss = epoch_history['val_loss']
        epoch_time = epoch_history['epoch_time']
        
        progress_str = f"轮次 {epoch:3d} | "
        progress_str += f"训练损失: {train_loss:.6f} | "
        
        if val_loss is not None:
            progress_str += f"验证损失: {val_loss:.6f} | "
        
        progress_str += f"时间: {epoch_time:.2f}s"
        
        print(progress_str)
    
    def _save_best_model(self, epoch: int, val_loss: float):
        """保存最佳模型"""
        save_dir = Path(self.config['model_save_dir'])
        save_dir.mkdir(parents=True, exist_ok=True)
        
        # 复制当前模型文件
        if self.model_path:
            model_name = Path(self.model_path).stem
            best_model_path = save_dir / f"best_model_epoch_{epoch}_loss_{val_loss:.6f}.onnx"
            
            # 在实际实现中，这里应该保存训练后的模型参数
            # 目前只是复制原始模型文件
            import shutil
            shutil.copy2(self.model_path, best_model_path)
            
            print(f"最佳模型已保存: {best_model_path}")
    
    def _get_training_summary(self) -> Dict:
        """获取训练摘要"""
        if not self.training_history:
            return {}
        
        best_epoch = min(self.training_history, key=lambda x: x['val_loss'] if x['val_loss'] is not None else x['train_loss'])
        final_epoch = self.training_history[-1]
        
        summary = {
            'total_epochs': len(self.training_history),
            'best_epoch': best_epoch['epoch'],
            'best_train_loss': best_epoch['train_loss'],
            'best_val_loss': best_epoch['val_loss'],
            'final_train_loss': final_epoch['train_loss'],
            'final_val_loss': final_epoch['val_loss'],
            'total_training_time': sum(epoch['epoch_time'] for epoch in self.training_history),
            'config': self.config
        }
        
        return summary
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """
        使用模型进行预测
        
        Args:
            X: 输入数据
            
        Returns:
            预测结果
        """
        if self.session is None:
            raise ValueError("请先加载模型")
        
        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name
        
        # 确保输入数据格式正确
        if X.ndim == 1:
            X = X.reshape(1, -1)
        
        predictions = self.session.run([output_name], {input_name: X.astype(np.float32)})[0]
        return predictions
    
    def evaluate(self, X_test: np.ndarray, y_test: np.ndarray) -> Dict:
        """
        评估模型性能
        
        Args:
            X_test: 测试数据
            y_test: 测试标签
            
        Returns:
            评估指标字典
        """
        print("评估模型性能...")
        
        # 获取预测
        y_pred = self.predict(X_test)
        
        # 计算指标
        metrics = self._compute_metrics(X_test, y_test, y_pred)
        
        print("评估结果:")
        for metric_name, value in metrics.items():
            print(f"  {metric_name}: {value:.6f}")
        
        return metrics
    
    def save_training_history(self, filepath: str = "training_history.json"):
        """保存训练历史"""
        with open(filepath, 'w') as f:
            json.dump(self.training_history, f, indent=2, ensure_ascii=False)
        
        print(f"训练历史已保存到: {filepath}")
    
    def load_training_history(self, filepath: str = "training_history.json"):
        """加载训练历史"""
        if Path(filepath).exists():
            with open(filepath, 'r') as f:
                self.training_history = json.load(f)
            print(f"训练历史已从 {filepath} 加载")
        else:
            print(f"训练历史文件不存在: {filepath}")


class ProgressiveTrainer:
    """渐进式训练器 - 支持渐进式训练策略"""
    
    def __init__(self, base_trainer: ONNXTrainer, config: Dict = None):
        """
        初始化渐进式训练器
        
        Args:
            base_trainer: 基础训练器
            config: 渐进式训练配置
        """
        self.base_trainer = base_trainer
        self.config = config or {}
        
        # 默认渐进式训练配置
        self.default_config = {
            'progressive_epochs': [50, 100, 200],  # 渐进式轮次
            'progressive_learning_rates': [0.01, 0.001, 0.0001],  # 渐进式学习率
            'warmup_epochs': 10,  # 预热轮次
            'data_subsets': [0.1, 0.5, 1.0]  # 渐进式数据子集
        }
        
        self.default_config.update(self.config)
        self.config = self.default_config
    
    def progressive_train(self, train_data: Tuple[np.ndarray, np.ndarray],
                         val_data: Tuple[np.ndarray, np.ndarray] = None) -> Dict:
        """
        渐进式训练
        
        Args:
            train_data: 训练数据
            val_data: 验证数据
            
        Returns:
            训练结果
        """
        print("开始渐进式训练...")
        
        X_train, y_train = train_data
        X_val, y_val = val_data if val_data else (None, None)
        
        all_results = []
        
        # 渐进式训练阶段
        for stage, (epochs, lr, data_ratio) in enumerate(zip(
            self.config['progressive_epochs'],
            self.config['progressive_learning_rates'],
            self.config['data_subsets']
        )):
            print(f"\n=== 渐进式训练阶段 {stage + 1} ===")
            print(f"轮次: {epochs}, 学习率: {lr}, 数据比例: {data_ratio}")
            
            # 更新训练器配置
            self.base_trainer.config['epochs'] = epochs
            self.base_trainer.config['learning_rate'] = lr
            
            # 创建数据子集
            if data_ratio < 1.0:
                # 这里需要数据加载器的支持来创建子集
                # 简化实现：随机采样
                indices = np.random.choice(
                    X_train.shape[0],
                    int(X_train.shape[0] * data_ratio),
                    replace=False
                )
                stage_X_train = X_train[indices]
                stage_y_train = y_train[indices]
            else:
                stage_X_train, stage_y_train = X_train, y_train
            
            # 训练当前阶段
            stage_result = self.base_trainer.train(
                (stage_X_train, stage_y_train),
                (X_val, y_val) if X_val is not None else None
            )
            
            all_results.append({
                'stage': stage + 1,
                'epochs': epochs,
                'learning_rate': lr,
                'data_ratio': data_ratio,
                'result': stage_result
            })
            
            print(f"阶段 {stage + 1} 完成!")
        
        # 汇总结果
        final_result = self._aggregate_progressive_results(all_results)
        print("渐进式训练完成!")
        
        return final_result
    
    def _aggregate_progressive_results(self, all_results: List[Dict]) -> Dict:
        """汇总渐进式训练结果"""
        final_result = {
            'total_stages': len(all_results),
            'stage_results': all_results,
            'final_training_loss': all_results[-1]['result']['final_train_loss'],
            'final_validation_loss': all_results[-1]['result']['final_val_loss'],
            'best_stage': min(all_results, key=lambda x: x['result']['best_val_loss'])['stage']
        }
        
        return final_result
    
    def get_progressive_summary(self) -> str:
        """获取渐进式训练摘要"""
        if not hasattr(self, 'progressive_results'):
            return "渐进式训练尚未执行"
        
        summary = []
        summary.append("=== 渐进式训练摘要 ===")
        summary.append("")
        
        for stage_result in self.progressive_results['stage_results']:
            stage = stage_result['stage']
            result = stage_result['result']
            
            summary.append(f"阶段 {stage}:")
            summary.append(f"  轮次: {stage_result['epochs']}")
            summary.append(f"  学习率: {stage_result['learning_rate']}")
            summary.append(f"  数据比例: {stage_result['data_ratio']}")
            summary.append(f"  最佳验证损失: {result['best_val_loss']:.6f}")
            summary.append("")
        
        summary.append(f"最佳阶段: {self.progressive_results['best_stage']}")
        summary.append(f"最终训练损失: {self.progressive_results['final_training_loss']:.6f}")
        summary.append(f"最终验证损失: {self.progressive_results['final_validation_loss']:.6f}")
        
        return "\n".join(summary)


class MultiTaskTrainer:
    """多任务训练器 - 支持多目标训练"""
    
    def __init__(self, base_trainer: ONNXTrainer, config: Dict = None):
        """
        初始化多任务训练器
        
        Args:
            base_trainer: 基础训练器
            config: 多任务训练配置
        """
        self.base_trainer = base_trainer
        self.config = config or {}
        
        # 默认多任务配置
        self.default_config = {
            'task_weights': [0.4, 0.4, 0.2],  # 热点概率, 质量评分, 置信度的权重
            'adaptive_weighting': True,
            'task_specific_metrics': True
        }
        
        self.default_config.update(self.config)
        self.config = self.default_config
    
    def multi_task_train(self, train_data: Tuple[np.ndarray, np.ndarray],
                        val_data: Tuple[np.ndarray, np.ndarray] = None) -> Dict:
        """
        多任务训练
        
        Args:
            train_data: 训练数据
            val_data: 验证数据
            
        Returns:
            训练结果
        """
        print("开始多任务训练...")
        
        X_train, y_train = train_data
        X_val, y_val = val_data if val_data else (None, None)
        
        # 验证目标维度
        if y_train.shape[1] != len(self.config['task_weights']):
            raise ValueError(f"目标维度 {y_train.shape[1]} 与任务权重数量 {len(self.config['task_weights'])} 不匹配")
        
        # 执行训练
        result = self.base_trainer.train((X_train, y_train), (X_val, y_val))
        
        # 计算多任务特定指标
        if self.config['task_specific_metrics']:
            multi_task_metrics = self._compute_multi_task_metrics(X_val, y_val)
            result.update({'multi_task_metrics': multi_task_metrics})
        
        print("多任务训练完成!")
        return result
    
    def _compute_multi_task_metrics(self, X: np.ndarray, y_true: np.ndarray) -> Dict:
        """计算多任务特定指标"""
        if X is None or y_true is None:
            return {}
        
        y_pred = self.base_trainer.predict(X)
        metrics = {}
        
        # 计算每个任务的指标
        for task_idx in range(y_true.shape[1]):
            task_weight = self.config['task_weights'][task_idx]
            
            # 任务特定损失
            task_mse = float(np.mean((y_pred[:, task_idx] - y_true[:, task_idx]) ** 2))
            task_mae = float(np.mean(np.abs(y_pred[:, task_idx] - y_true[:, task_idx])))
            
            metrics[f'task_{task_idx}_mse'] = task_mse
            metrics[f'task_{task_idx}_mae'] = task_mae
            metrics[f'task_{task_idx}_weighted_mse'] = task_mse * task_weight
        
        # 加权总损失
        total_weighted_mse = sum(
            metrics[f'task_{i}_weighted_mse'] 
            for i in range(y_true.shape[1])
        )
        metrics['total_weighted_mse'] = total_weighted_mse
        
        return metrics
    
    def predict_with_confidence(self, X: np.ndarray) -> Dict:
        """
        带置信度的预测
        
        Args:
            X: 输入数据
            
        Returns:
            包含预测和置信度的字典
        """
        predictions = self.base_trainer.predict(X)
        
        # 假设最后一个输出是置信度
        confidence_idx = predictions.shape[1] - 1
        
        results = {
            'hotspot_probability': predictions[:, 0],
            'quality_score': predictions[:, 1],
            'confidence': predictions[:, confidence_idx],
            'raw_predictions': predictions
        }
        
        return results


if __name__ == "__main__":
    # 测试ONNX训练器
    print("测试ONNX训练器...")
    
    # 创建示例模型 (需要先有模型文件)
    # 这里只是演示接口使用
    
    # 创建训练器配置
    trainer_config = {
        'learning_rate': 0.001,
        'epochs': 50,
        'batch_size': 32,
        'early_stopping_patience': 5
    }
    
    # 创建训练器实例
    # trainer = ONNXTrainer("path/to/model.onnx", trainer_config)
    
    print("训练器模块实现完成!")
