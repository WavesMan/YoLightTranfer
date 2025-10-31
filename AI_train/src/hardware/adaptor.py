"""
硬件适配器
根据硬件配置自动调整训练参数
"""

import numpy as np
from typing import Dict, Any, List
from .detector import HardwareDetector


class PrecisionAdaptor:
    """精度适配器 - 根据硬件自动调整数值精度"""
    
    def __init__(self, hardware_detector: HardwareDetector = None):
        """
        初始化精度适配器
        
        Args:
            hardware_detector: 硬件探测器实例
        """
        self.hardware_detector = hardware_detector or HardwareDetector()
        self.hardware_info = self.hardware_detector.detect_hardware()
        
    def get_recommended_precision(self) -> Dict[str, Any]:
        """
        获取推荐的精度配置
        
        Returns:
            精度配置字典
        """
        gpu_info = self.hardware_info['gpu']
        cpu_info = self.hardware_info['cpu']
        memory_info = self.hardware_info['memory']
        
        # 根据GPU计算能力推荐精度
        if gpu_info['available']:
            compute_capability = gpu_info['compute_capability']
            gpu_memory_gb = gpu_info['memory_gb']
            
            # 现代GPU支持混合精度训练
            if compute_capability >= (7, 0):  # Volta及以后
                precision_config = {
                    'model_precision': 'mixed',  # 混合精度
                    'data_precision': 'float32',  # 数据保持float32
                    'gradient_precision': 'float16',  # 梯度使用float16
                    'accumulation_precision': 'float32',  # 累加使用float32
                    'recommendation_reason': '现代GPU支持混合精度训练'
                }
            elif compute_capability >= (6, 0):  # Pascal
                precision_config = {
                    'model_precision': 'float32',
                    'data_precision': 'float32',
                    'gradient_precision': 'float32',
                    'accumulation_precision': 'float32',
                    'recommendation_reason': 'Pascal架构建议使用float32'
                }
            else:  # 较老GPU
                precision_config = {
                    'model_precision': 'float32',
                    'data_precision': 'float32',
                    'gradient_precision': 'float32',
                    'accumulation_precision': 'float32',
                    'recommendation_reason': '较老GPU建议使用float32'
                }
            
            # 根据显存大小调整
            if gpu_memory_gb < 4:
                precision_config['model_precision'] = 'float16'
                precision_config['recommendation_reason'] += '，显存较小使用float16'
            elif gpu_memory_gb < 8:
                precision_config['model_precision'] = 'mixed'
                precision_config['recommendation_reason'] += '，中等显存使用混合精度'
                
        else:
            # CPU训练配置
            cpu_cores = cpu_info['logical_cores']
            available_memory = memory_info['available_gb']
            
            if available_memory < 8:
                precision_config = {
                    'model_precision': 'float16',
                    'data_precision': 'float16',
                    'gradient_precision': 'float16',
                    'accumulation_precision': 'float32',
                    'recommendation_reason': 'CPU训练且内存较小，使用float16'
                }
            else:
                precision_config = {
                    'model_precision': 'float32',
                    'data_precision': 'float32',
                    'gradient_precision': 'float32',
                    'accumulation_precision': 'float32',
                    'recommendation_reason': 'CPU训练且内存充足，使用float32'
                }
        
        return precision_config
    
    def get_batch_size_recommendation(self, model_size_mb: float = 100) -> Dict[str, Any]:
        """
        获取批次大小推荐
        
        Args:
            model_size_mb: 模型大小(MB)
            
        Returns:
            批次大小配置
        """
        gpu_info = self.hardware_info['gpu']
        memory_info = self.hardware_info['memory']
        
        if gpu_info['available']:
            # GPU训练
            gpu_memory_gb = gpu_info['memory_gb']
            
            # 估算可用显存 (保留20%作为系统使用)
            available_gpu_memory_gb = gpu_memory_gb * 0.8
            
            # 估算每个样本的内存占用 (假设每个特征约4字节)
            sample_memory_mb = model_size_mb * 0.1  # 简化估算
            
            # 计算最大批次大小
            max_batch_size = int((available_gpu_memory_gb * 1024) / sample_memory_mb)
            
            # 根据GPU性能调整
            if gpu_memory_gb >= 16:
                recommended_batch_size = min(256, max_batch_size)
            elif gpu_memory_gb >= 8:
                recommended_batch_size = min(128, max_batch_size)
            elif gpu_memory_gb >= 4:
                recommended_batch_size = min(64, max_batch_size)
            else:
                recommended_batch_size = min(32, max_batch_size)
                
            batch_config = {
                'max_batch_size': max_batch_size,
                'recommended_batch_size': recommended_batch_size,
                'gradient_accumulation_steps': max(1, 256 // recommended_batch_size),
                'recommendation_reason': f'GPU显存{gpu_memory_gb:.1f}GB'
            }
            
        else:
            # CPU训练
            available_memory_gb = memory_info['available_gb']
            
            # 估算每个样本的内存占用
            sample_memory_mb = model_size_mb * 0.05  # CPU训练内存占用较小
            
            # 计算最大批次大小
            max_batch_size = int((available_memory_gb * 1024) / sample_memory_mb)
            
            # 根据CPU核心数调整
            cpu_cores = self.hardware_info['cpu']['logical_cores']
            recommended_batch_size = min(cpu_cores * 4, max_batch_size)
            
            batch_config = {
                'max_batch_size': max_batch_size,
                'recommended_batch_size': recommended_batch_size,
                'gradient_accumulation_steps': 1,  # CPU训练通常不需要梯度累积
                'recommendation_reason': f'CPU {cpu_cores}核心，内存{available_memory_gb:.1f}GB'
            }
        
        return batch_config


class ParallelismAdaptor:
    """并行度适配器 - 根据硬件自动调整并行策略"""
    
    def __init__(self, hardware_detector: HardwareDetector = None):
        """
        初始化并行度适配器
        
        Args:
            hardware_detector: 硬件探测器实例
        """
        self.hardware_detector = hardware_detector or HardwareDetector()
        self.hardware_info = self.hardware_detector.detect_hardware()
        
    def get_parallelism_config(self) -> Dict[str, Any]:
        """
        获取并行度配置
        
        Returns:
            并行度配置字典
        """
        gpu_info = self.hardware_info['gpu']
        cpu_info = self.hardware_info['cpu']
        
        if gpu_info['available']:
            # GPU并行配置
            gpu_memory_gb = gpu_info['memory_gb']
            compute_capability = gpu_info['compute_capability']
            
            if gpu_memory_gb >= 16:
                parallelism_config = {
                    'data_parallelism': True,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(8, cpu_info['logical_cores']),
                    'pin_memory': True,
                    'recommendation_reason': '大显存GPU，使用数据并行'
                }
            elif gpu_memory_gb >= 8:
                parallelism_config = {
                    'data_parallelism': True,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(4, cpu_info['logical_cores']),
                    'pin_memory': True,
                    'recommendation_reason': '中等显存GPU，使用数据并行'
                }
            else:
                parallelism_config = {
                    'data_parallelism': False,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(2, cpu_info['logical_cores']),
                    'pin_memory': False,
                    'recommendation_reason': '小显存GPU，单GPU训练'
                }
                
        else:
            # CPU并行配置
            cpu_cores = cpu_info['logical_cores']
            
            if cpu_cores >= 16:
                parallelism_config = {
                    'data_parallelism': True,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(8, cpu_cores),
                    'pin_memory': False,
                    'recommendation_reason': f'多核心CPU({cpu_cores}核心)，使用数据并行'
                }
            elif cpu_cores >= 8:
                parallelism_config = {
                    'data_parallelism': True,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(4, cpu_cores),
                    'pin_memory': False,
                    'recommendation_reason': f'中等核心CPU({cpu_cores}核心)，使用数据并行'
                }
            else:
                parallelism_config = {
                    'data_parallelism': False,
                    'model_parallelism': False,
                    'pipeline_parallelism': False,
                    'num_workers': min(2, cpu_cores),
                    'pin_memory': False,
                    'recommendation_reason': f'少核心CPU({cpu_cores}核心)，单线程训练'
                }
        
        return parallelism_config
    
    def get_optimization_config(self) -> Dict[str, Any]:
        """
        获取优化配置
        
        Returns:
            优化配置字典
        """
        gpu_info = self.hardware_info['gpu']
        cpu_info = self.hardware_info['cpu']
        
        if gpu_info['available']:
            # GPU优化配置
            optimization_config = {
                'use_cudnn': True,
                'cudnn_benchmark': True,
                'cudnn_deterministic': False,
                'use_tensor_cores': gpu_info['compute_capability'] >= (7, 0),
                'memory_efficient': gpu_info['memory_gb'] < 8,
                'recommendation_reason': 'GPU优化配置'
            }
        else:
            # CPU优化配置
            optimization_config = {
                'use_cudnn': False,
                'cudnn_benchmark': False,
                'cudnn_deterministic': False,
                'use_tensor_cores': False,
                'memory_efficient': True,
                'recommendation_reason': 'CPU优化配置'
            }
        
        return optimization_config


def get_hardware_adaptive_config(model_size_mb: float = 100) -> Dict[str, Any]:
    """
    获取完整的硬件自适应配置
    
    Args:
        model_size_mb: 模型大小(MB)
        
    Returns:
        完整的硬件自适应配置
    """
    detector = HardwareDetector()
    precision_adaptor = PrecisionAdaptor(detector)
    parallelism_adaptor = ParallelismAdaptor(detector)
    
    config = {
        'hardware_summary': detector.get_hardware_summary(),
        'precision': precision_adaptor.get_recommended_precision(),
        'batch_size': precision_adaptor.get_batch_size_recommendation(model_size_mb),
        'parallelism': parallelism_adaptor.get_parallelism_config(),
        'optimization': parallelism_adaptor.get_optimization_config()
    }
    
    return config


if __name__ == "__main__":
    # 测试硬件适配器
    print("测试硬件适配器...")
    
    config = get_hardware_adaptive_config(model_size_mb=50)
    
    print("硬件自适应配置:")
    import json
    print(json.dumps(config, indent=2, ensure_ascii=False))
