"""
配置管理器
提供配置文件的加载、验证和管理功能
"""

import os
import json
import yaml
from typing import Dict, Any, Optional
from pathlib import Path


class ConfigManager:
    """配置管理器类"""
    
    def __init__(self, config_dir: str = "configs"):
        """
        初始化配置管理器
        
        Args:
            config_dir: 配置文件目录
        """
        self.config_dir = Path(config_dir)
        self.configs: Dict[str, Dict[str, Any]] = {}
        self.default_configs = self._get_default_configs()
        
        # 确保配置目录存在
        self.config_dir.mkdir(exist_ok=True)
    
    def _get_default_configs(self) -> Dict[str, Dict[str, Any]]:
        """获取默认配置"""
        return {
            'model': {
                'input_size': 15,
                'hidden_sizes': [64, 32, 16],
                'output_size': 3,
                'activation': 'relu',
                'dropout_rate': 0.2,
                'optimizer': 'adam',
                'learning_rate': 0.001
            },
            'data': {
                'num_samples': 10000,
                'use_existing_data': True,
                'preprocess_config': {
                    'test_size': 0.2,
                    'validation_size': 0.1,
                    'feature_engineering': True,
                    'normalize': True,
                    'shuffle': True
                }
            },
            'training': {
                'epochs': 100,
                'batch_size': 32,
                'early_stopping_patience': 10,
                'learning_rate_scheduler': 'step',
                'hardware_adaptive': True,
                'save_checkpoints': True,
                'checkpoint_interval': 10
            },
            'progressive': {
                'stages': [
                    {'name': 'warmup', 'epochs': 50, 'data_ratio': 0.1, 'lr': 0.01},
                    {'name': 'main', 'epochs': 100, 'data_ratio': 0.5, 'lr': 0.001},
                    {'name': 'refinement', 'epochs': 200, 'data_ratio': 1.0, 'lr': 0.0001}
                ],
                'enable_multi_task': True,
                'task_weights': [0.4, 0.4, 0.2]
            },
            'visualization': {
                'style': 'seaborn',
                'save_plots': True,
                'plot_format': 'html',
                'interactive_plots': True
            }
        }
    
    def load_config(self, config_name: str, config_file: Optional[str] = None) -> Dict[str, Any]:
        """
        加载配置文件
        
        Args:
            config_name: 配置名称
            config_file: 配置文件路径（可选）
            
        Returns:
            配置字典
        """
        if config_name in self.configs:
            return self.configs[config_name]
        
        config = self.default_configs.copy()
        
        # 如果提供了配置文件，则加载并合并
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    if config_file.endswith('.json'):
                        user_config = json.load(f)
                    elif config_file.endswith(('.yaml', '.yml')):
                        user_config = yaml.safe_load(f)
                    else:
                        # 默认使用JSON
                        user_config = json.load(f)
                
                # 深度合并配置
                config = self._deep_merge(config, user_config)
                print(f"配置文件已加载: {config_file}")
                
            except Exception as e:
                print(f"配置文件加载失败: {e}，使用默认配置")
        
        # 保存到缓存
        self.configs[config_name] = config
        return config
    
    def _deep_merge(self, base: Dict[str, Any], update: Dict[str, Any]) -> Dict[str, Any]:
        """
        深度合并两个字典
        
        Args:
            base: 基础字典
            update: 更新字典
            
        Returns:
            合并后的字典
        """
        result = base.copy()
        
        for key, value in update.items():
            if (key in result and isinstance(result[key], dict) and 
                isinstance(value, dict)):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value
        
        return result
    
    def get_config(self, config_name: str, section: Optional[str] = None) -> Any:
        """
        获取配置
        
        Args:
            config_name: 配置名称
            section: 配置节（可选）
            
        Returns:
            配置值
        """
        if config_name not in self.configs:
            self.load_config(config_name)
        
        config = self.configs[config_name]
        
        if section:
            return config.get(section, {})
        
        return config
    
    def update_config(self, config_name: str, updates: Dict[str, Any]):
        """
        更新配置
        
        Args:
            config_name: 配置名称
            updates: 更新内容
        """
        if config_name not in self.configs:
            self.load_config(config_name)
        
        self.configs[config_name] = self._deep_merge(self.configs[config_name], updates)
    
    def save_config(self, config_name: str, file_path: str, format: str = 'json'):
        """
        保存配置到文件
        
        Args:
            config_name: 配置名称
            file_path: 文件路径
            format: 文件格式 ('json' 或 'yaml')
        """
        if config_name not in self.configs:
            print(f"配置 '{config_name}' 不存在")
            return
        
        config = self.configs[config_name]
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                if format.lower() == 'yaml':
                    yaml.dump(config, f, default_flow_style=False, allow_unicode=True)
                else:
                    json.dump(config, f, indent=2, ensure_ascii=False)
            
            print(f"配置已保存到: {file_path}")
            
        except Exception as e:
            print(f"配置保存失败: {e}")
    
    def validate_config(self, config_name: str) -> Dict[str, Any]:
        """
        验证配置的有效性
        
        Args:
            config_name: 配置名称
            
        Returns:
            验证结果字典
        """
        if config_name not in self.configs:
            self.load_config(config_name)
        
        config = self.configs[config_name]
        validation_results = {
            'valid': True,
            'errors': [],
            'warnings': []
        }
        
        # 验证模型配置
        if 'model' in config:
            model_config = config['model']
            if not isinstance(model_config.get('input_size'), int) or model_config['input_size'] <= 0:
                validation_results['errors'].append("模型输入尺寸必须为正整数")
            
            if not isinstance(model_config.get('output_size'), int) or model_config['output_size'] <= 0:
                validation_results['errors'].append("模型输出尺寸必须为正整数")
        
        # 验证训练配置
        if 'training' in config:
            training_config = config['training']
            if not isinstance(training_config.get('epochs'), int) or training_config['epochs'] <= 0:
                validation_results['errors'].append("训练轮次必须为正整数")
            
            if not isinstance(training_config.get('batch_size'), int) or training_config['batch_size'] <= 0:
                validation_results['errors'].append("批次大小必须为正整数")
        
        # 验证数据配置
        if 'data' in config:
            data_config = config['data']
            if not isinstance(data_config.get('num_samples'), int) or data_config['num_samples'] <= 0:
                validation_results['warnings'].append("样本数量应为正整数")
        
        # 检查错误
        if validation_results['errors']:
            validation_results['valid'] = False
        
        return validation_results
    
    def create_template_config(self, config_type: str = 'training') -> Dict[str, Any]:
        """
        创建配置模板
        
        Args:
            config_type: 配置类型 ('training', 'inference', 'evaluation')
            
        Returns:
            配置模板字典
        """
        templates = {
            'training': {
                'description': '训练配置模板',
                'model': self.default_configs['model'],
                'data': self.default_configs['data'],
                'training': self.default_configs['training'],
                'progressive': self.default_configs['progressive']
            },
            'inference': {
                'description': '推理配置模板',
                'model': self.default_configs['model'],
                'preprocessing': {
                    'normalize': True,
                    'feature_scaling': True
                },
                'performance': {
                    'batch_size': 1,
                    'use_gpu': True
                }
            },
            'evaluation': {
                'description': '评估配置模板',
                'metrics': ['mse', 'mae', 'r2'],
                'cross_validation': {
                    'folds': 5,
                    'shuffle': True
                }
            }
        }
        
        return templates.get(config_type, templates['training'])


# 全局配置管理器实例
config_manager = ConfigManager()


def get_config_manager() -> ConfigManager:
    """获取全局配置管理器实例"""
    return config_manager


if __name__ == "__main__":
    # 测试配置管理器
    print("测试配置管理器...")
    
    manager = ConfigManager()
    
    # 测试加载默认配置
    config = manager.load_config('test_config')
    print("默认配置加载成功")
    
    # 测试配置验证
    validation = manager.validate_config('test_config')
    print(f"配置验证结果: {validation}")
    
    # 测试配置更新
    manager.update_config('test_config', {'training': {'epochs': 200}})
    updated_config = manager.get_config('test_config', 'training')
    print(f"更新后的训练配置: {updated_config}")
    
    print("配置管理器测试完成!")
