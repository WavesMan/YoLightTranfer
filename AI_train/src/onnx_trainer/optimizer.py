"""
自适应优化器
提供多种优化算法和自适应学习率调整策略
"""

import numpy as np
from typing import Dict, List, Optional, Callable
import math
from enum import Enum


class OptimizerType(Enum):
    """优化器类型枚举"""
    SGD = "sgd"
    ADAM = "adam"
    RMSPROP = "rmsprop"
    ADAGRAD = "adagrad"
    ADADELTA = "adadelta"


class LearningRateScheduler:
    """学习率调度器基类"""
    
    def __init__(self, initial_lr: float = 0.001):
        """
        初始化学习率调度器
        
        Args:
            initial_lr: 初始学习率
        """
        self.initial_lr = initial_lr
        self.current_lr = initial_lr
        self.step_count = 0
    
    def step(self) -> float:
        """
        更新学习率
        
        Returns:
            当前学习率
        """
        self.step_count += 1
        self.current_lr = self._get_lr()
        return self.current_lr
    
    def _get_lr(self) -> float:
        """获取当前学习率（由子类实现）"""
        raise NotImplementedError
    
    def reset(self):
        """重置调度器状态"""
        self.step_count = 0
        self.current_lr = self.initial_lr


class StepLR(LearningRateScheduler):
    """步长学习率调度器"""
    
    def __init__(self, initial_lr: float = 0.001, step_size: int = 30, gamma: float = 0.1):
        """
        初始化步长学习率调度器
        
        Args:
            initial_lr: 初始学习率
            step_size: 步长大小（多少步衰减一次）
            gamma: 衰减系数
        """
        super().__init__(initial_lr)
        self.step_size = step_size
        self.gamma = gamma
    
    def _get_lr(self) -> float:
        """获取当前学习率"""
        return self.initial_lr * (self.gamma ** (self.step_count // self.step_size))


class ExponentialLR(LearningRateScheduler):
    """指数衰减学习率调度器"""
    
    def __init__(self, initial_lr: float = 0.001, gamma: float = 0.95):
        """
        初始化指数衰减学习率调度器
        
        Args:
            initial_lr: 初始学习率
            gamma: 衰减系数
        """
        super().__init__(initial_lr)
        self.gamma = gamma
    
    def _get_lr(self) -> float:
        """获取当前学习率"""
        return self.initial_lr * (self.gamma ** self.step_count)


class CosineAnnealingLR(LearningRateScheduler):
    """余弦退火学习率调度器"""
    
    def __init__(self, initial_lr: float = 0.001, T_max: int = 50, eta_min: float = 0.0001):
        """
        初始化余弦退火学习率调度器
        
        Args:
            initial_lr: 初始学习率
            T_max: 周期长度
            eta_min: 最小学习率
        """
        super().__init__(initial_lr)
        self.T_max = T_max
        self.eta_min = eta_min
    
    def _get_lr(self) -> float:
        """获取当前学习率"""
        if self.step_count == 0:
            return self.initial_lr
        
        return self.eta_min + 0.5 * (self.initial_lr - self.eta_min) * (
            1 + math.cos(math.pi * self.step_count / self.T_max)
        )


class AdaptiveOptimizer:
    """自适应优化器 - 支持多种优化算法和自适应学习率调整"""
    
    def __init__(self, 
                 optimizer_type: OptimizerType = OptimizerType.ADAM,
                 learning_rate: float = 0.001,
                 scheduler: Optional[LearningRateScheduler] = None,
                 config: Dict = None):
        """
        初始化自适应优化器
        
        Args:
            optimizer_type: 优化器类型
            learning_rate: 学习率
            scheduler: 学习率调度器
            config: 优化器配置
        """
        self.optimizer_type = optimizer_type
        self.learning_rate = learning_rate
        self.scheduler = scheduler
        self.config = config or {}
        
        # 优化器状态
        self.step_count = 0
        self.parameters = {}
        self.momentum = {}
        self.velocity = {}
        self.cache = {}
        
        # 默认配置
        self.default_config = {
            'beta1': 0.9,      # Adam/RMSprop的一阶矩衰减率
            'beta2': 0.999,    # Adam的二阶矩衰减率
            'epsilon': 1e-8,   # 数值稳定性常数
            'weight_decay': 0.0,  # 权重衰减
            'momentum': 0.9,   # SGD动量
            'rho': 0.9,        # Adadelta/RMSprop衰减率
        }
        
        # 更新配置
        self.default_config.update(self.config)
        self.config = self.default_config
        
        # 初始化优化器特定状态
        self._initialize_optimizer_state()
    
    def _initialize_optimizer_state(self):
        """初始化优化器特定状态"""
        if self.optimizer_type == OptimizerType.ADAM:
            self.momentum = {}  # 一阶矩估计
            self.velocity = {}  # 二阶矩估计
        elif self.optimizer_type == OptimizerType.RMSPROP:
            self.cache = {}     # 平方梯度缓存
        elif self.optimizer_type == OptimizerType.ADAGRAD:
            self.cache = {}     # 梯度平方和缓存
        elif self.optimizer_type == OptimizerType.ADADELTA:
            self.cache = {}     # 梯度平方和缓存
            self.delta_cache = {}  # 参数更新平方和缓存
    
    def set_parameters(self, parameters: Dict[str, np.ndarray]):
        """
        设置要优化的参数
        
        Args:
            parameters: 参数字典 {参数名: 参数值}
        """
        self.parameters = parameters.copy()
        
        # 为每个参数初始化优化器状态
        for param_name in parameters.keys():
            param_shape = parameters[param_name].shape
            
            if self.optimizer_type == OptimizerType.ADAM:
                self.momentum[param_name] = np.zeros(param_shape)
                self.velocity[param_name] = np.zeros(param_shape)
            elif self.optimizer_type == OptimizerType.RMSPROP:
                self.cache[param_name] = np.zeros(param_shape)
            elif self.optimizer_type == OptimizerType.ADAGRAD:
                self.cache[param_name] = np.zeros(param_shape)
            elif self.optimizer_type == OptimizerType.ADADELTA:
                self.cache[param_name] = np.zeros(param_shape)
                self.delta_cache[param_name] = np.zeros(param_shape)
    
    def step(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """
        执行优化步骤
        
        Args:
            gradients: 梯度字典 {参数名: 梯度值}
            
        Returns:
            参数更新字典
        """
        self.step_count += 1
        
        # 更新学习率（如果使用调度器）
        if self.scheduler is not None:
            self.learning_rate = self.scheduler.step()
        
        # 应用权重衰减
        if self.config['weight_decay'] > 0:
            gradients = self._apply_weight_decay(gradients)
        
        # 根据优化器类型执行更新
        if self.optimizer_type == OptimizerType.SGD:
            updates = self._sgd_update(gradients)
        elif self.optimizer_type == OptimizerType.ADAM:
            updates = self._adam_update(gradients)
        elif self.optimizer_type == OptimizerType.RMSPROP:
            updates = self._rmsprop_update(gradients)
        elif self.optimizer_type == OptimizerType.ADAGRAD:
            updates = self._adagrad_update(gradients)
        elif self.optimizer_type == OptimizerType.ADADELTA:
            updates = self._adadelta_update(gradients)
        else:
            raise ValueError(f"不支持的优化器类型: {self.optimizer_type}")
        
        # 更新参数
        for param_name, update in updates.items():
            if param_name in self.parameters:
                self.parameters[param_name] += update
        
        return updates
    
    def _apply_weight_decay(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """应用权重衰减"""
        decayed_gradients = gradients.copy()
        
        for param_name, gradient in decayed_gradients.items():
            if param_name in self.parameters:
                # 添加权重衰减项
                decayed_gradients[param_name] = gradient + self.config['weight_decay'] * self.parameters[param_name]
        
        return decayed_gradients
    
    def _sgd_update(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """SGD更新"""
        updates = {}
        
        for param_name, gradient in gradients.items():
            if param_name in self.parameters:
                # 基本SGD更新
                update = -self.learning_rate * gradient
                updates[param_name] = update
        
        return updates
    
    def _adam_update(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """Adam更新"""
        updates = {}
        beta1 = self.config['beta1']
        beta2 = self.config['beta2']
        epsilon = self.config['epsilon']
        
        for param_name, gradient in gradients.items():
            if param_name in self.parameters:
                # 更新一阶矩估计
                self.momentum[param_name] = beta1 * self.momentum[param_name] + (1 - beta1) * gradient
                
                # 更新二阶矩估计
                self.velocity[param_name] = beta2 * self.velocity[param_name] + (1 - beta2) * (gradient ** 2)
                
                # 偏差修正
                momentum_hat = self.momentum[param_name] / (1 - beta1 ** self.step_count)
                velocity_hat = self.velocity[param_name] / (1 - beta2 ** self.step_count)
                
                # 计算更新
                update = -self.learning_rate * momentum_hat / (np.sqrt(velocity_hat) + epsilon)
                updates[param_name] = update
        
        return updates
    
    def _rmsprop_update(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """RMSprop更新"""
        updates = {}
        rho = self.config['rho']
        epsilon = self.config['epsilon']
        
        for param_name, gradient in gradients.items():
            if param_name in self.parameters:
                # 更新缓存
                self.cache[param_name] = rho * self.cache[param_name] + (1 - rho) * (gradient ** 2)
                
                # 计算更新
                update = -self.learning_rate * gradient / (np.sqrt(self.cache[param_name]) + epsilon)
                updates[param_name] = update
        
        return updates
    
    def _adagrad_update(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """Adagrad更新"""
        updates = {}
        epsilon = self.config['epsilon']
        
        for param_name, gradient in gradients.items():
            if param_name in self.parameters:
                # 更新缓存（梯度平方和）
                self.cache[param_name] += gradient ** 2
                
                # 计算更新
                update = -self.learning_rate * gradient / (np.sqrt(self.cache[param_name]) + epsilon)
                updates[param_name] = update
        
        return updates
    
    def _adadelta_update(self, gradients: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
        """Adadelta更新"""
        updates = {}
        rho = self.config['rho']
        epsilon = self.config['epsilon']
        
        for param_name, gradient in gradients.items():
            if param_name in self.parameters:
                # 更新梯度平方缓存
                self.cache[param_name] = rho * self.cache[param_name] + (1 - rho) * (gradient ** 2)
                
                # 计算RMS
                rms_gradient = np.sqrt(self.cache[param_name] + epsilon)
                rms_delta = np.sqrt(self.delta_cache[param_name] + epsilon)
                
                # 计算更新
                update = -rms_delta / rms_gradient * gradient
                updates[param_name] = update
                
                # 更新参数更新平方缓存
                self.delta_cache[param_name] = rho * self.delta_cache[param_name] + (1 - rho) * (update ** 2)
        
        return updates
    
    def get_learning_rate(self) -> float:
        """获取当前学习率"""
        return self.learning_rate
    
    def get_optimizer_state(self) -> Dict:
        """获取优化器状态"""
        state = {
            'optimizer_type': self.optimizer_type.value,
            'learning_rate': self.learning_rate,
            'step_count': self.step_count,
            'config': self.config
        }
        
        if self.scheduler is not None:
            state['scheduler'] = {
                'type': type(self.scheduler).__name__,
                'current_lr': self.scheduler.current_lr
            }
        
        return state
    
    def save_state(self, filepath: str):
        """保存优化器状态"""
        import pickle
        
        state = {
            'parameters': self.parameters,
            'momentum': self.momentum,
            'velocity': self.velocity,
            'cache': self.cache,
            'delta_cache': getattr(self, 'delta_cache', {}),
            'step_count': self.step_count,
            'learning_rate': self.learning_rate,
            'config': self.config
        }
        
        with open(filepath, 'wb') as f:
            pickle.dump(state, f)
        
        print(f"优化器状态已保存到: {filepath}")
    
    def load_state(self, filepath: str):
        """加载优化器状态"""
        import pickle
        
        with open(filepath, 'rb') as f:
            state = pickle.load(f)
        
        self.parameters = state['parameters']
        self.momentum = state.get('momentum', {})
        self.velocity = state.get('velocity', {})
        self.cache = state.get('cache', {})
        self.delta_cache = state.get('delta_cache', {})
        self.step_count = state['step_count']
        self.learning_rate = state['learning_rate']
        self.config.update(state['config'])
        
        print(f"优化器状态已从 {filepath} 加载")


# 便捷函数
def create_adam_optimizer(learning_rate: float = 0.001, **kwargs) -> AdaptiveOptimizer:
    """创建Adam优化器"""
    config = {
        'beta1': 0.9,
        'beta2': 0.999,
        'epsilon': 1e-8,
        'weight_decay': 0.0
    }
    config.update(kwargs)
    
    return AdaptiveOptimizer(
        optimizer_type=OptimizerType.ADAM,
        learning_rate=learning_rate,
        config=config
    )


def create_sgd_optimizer(learning_rate: float = 0.001, momentum: float = 0.9, **kwargs) -> AdaptiveOptimizer:
    """创建SGD优化器"""
    config = {
        'momentum': momentum,
        'weight_decay': 0.0
    }
    config.update(kwargs)
    
    return AdaptiveOptimizer(
        optimizer_type=OptimizerType.SGD,
        learning_rate=learning_rate,
        config=config
    )


def create_rmsprop_optimizer(learning_rate: float = 0.001, rho: float = 0.9, **kwargs) -> AdaptiveOptimizer:
    """创建RMSprop优化器"""
    config = {
        'rho': rho,
        'epsilon': 1e-8,
        'weight_decay': 0.0
    }
    config.update(kwargs)
    
    return AdaptiveOptimizer(
        optimizer_type=OptimizerType.RMSPROP,
        learning_rate=learning_rate,
        config=config
    )


def create_adaptive_optimizer_with_scheduler(
    optimizer_type: OptimizerType = OptimizerType.ADAM,
    learning_rate: float = 0.001,
    scheduler_type: str = 'step',
    **scheduler_kwargs
) -> AdaptiveOptimizer:
    """创建带调度器的自适应优化器"""
    
    # 创建调度器
    if scheduler_type == 'step':
        scheduler = StepLR(learning_rate, **scheduler_kwargs)
    elif scheduler_type == 'exponential':
        scheduler = ExponentialLR(learning_rate, **scheduler_kwargs)
    elif scheduler_type == 'cosine':
        scheduler = CosineAnnealingLR(learning_rate, **scheduler_kwargs)
    else:
        scheduler = None
    
    return AdaptiveOptimizer(
        optimizer_type=optimizer_type,
        learning_rate=learning_rate,
        scheduler=scheduler
    )


if __name__ == "__main__":
    # 测试自适应优化器
    print("测试自适应优化器...")
    
    # 创建示例参数和梯度
    parameters = {
        'weight1': np.random.randn(10, 5),
        'weight2': np.random.randn(5, 3),
        'bias1': np.random.randn(5),
        'bias2': np.random.randn(3)
    }
    
    gradients = {
        'weight1': np.random.randn(10, 5) * 0.1,
        'weight2': np.random.randn(5, 3) * 0.1,
        'bias1': np.random.randn(5) * 0.1,
        'bias2': np.random.randn(3) * 0.1
    }
    
    # 测试Adam优化器
    print("1. 测试Adam优化器:")
    adam_optimizer = create_adam_optimizer(learning_rate=0.001)
    adam_optimizer.set_parameters(parameters)
    
    # 执行优化步骤
    updates = adam_optimizer.step(gradients)
    print(f"Adam优化器更新完成，学习率: {adam_optimizer.get_learning_rate()}")
    
    # 测试带调度器的优化器
    print("\n2. 测试带步长调度器的优化器:")
    scheduled_optimizer = create_adaptive_optimizer_with_scheduler(
        optimizer_type=OptimizerType.ADAM,
        learning_rate=0.001,
        scheduler_type='step',
        step_size=10,
        gamma=0.5
    )
    scheduled_optimizer.set_parameters(parameters)
    
    # 执行多个步骤
    for i in range(5):
        updates = scheduled_optimizer.step(gradients)
        print(f"步骤 {i+1}: 学习率 = {scheduled_optimizer.get_learning_rate():.6f}")
    
    # 获取优化器状态
    state = scheduled_optimizer.get_optimizer_state()
    print(f"\n优化器状态: {state}")
    
    print("\n自适应优化器测试完成!")
