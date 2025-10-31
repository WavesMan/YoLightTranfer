"""
数据加载器
加载和管理网络质量训练数据
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Generator
import os
from pathlib import Path
from .generator import SmartDataGenerator
from .preprocessor import DataPreprocessor


class DataLoader:
    """数据加载器 - 管理训练数据的加载和批处理"""
    
    def __init__(self, data_dir: str = "data", config: Dict = None):
        """
        初始化数据加载器
        
        Args:
            data_dir: 数据目录路径
            config: 数据加载配置
        """
        self.data_dir = Path(data_dir)
        self.config = config or {}
        self.preprocessor = None
        self.data_splits = None
        
        # 默认配置
        self.default_config = {
            'batch_size': 32,
            'shuffle': True,
            'num_workers': 0,
            'pin_memory': False,
            'drop_last': False,
            'preprocess_config': {}
        }
        
        # 更新配置
        self.default_config.update(self.config)
        self.config = self.default_config
    
    def load_or_generate_data(self, num_samples: int = 10000, 
                            force_regenerate: bool = False) -> Dict[str, np.ndarray]:
        """
        加载或生成训练数据
        
        Args:
            num_samples: 样本数量
            force_regenerate: 是否强制重新生成数据
            
        Returns:
            数据分割字典
        """
        data_file = self.data_dir / "processed" / "training_dataset.csv"
        
        # 检查数据文件是否存在
        if data_file.exists() and not force_regenerate:
            print(f"加载现有数据: {data_file}")
            df = pd.read_csv(data_file)
        else:
            print("生成新的训练数据...")
            # 确保目录存在
            self.data_dir.mkdir(parents=True, exist_ok=True)
            (self.data_dir / "processed").mkdir(parents=True, exist_ok=True)
            
            # 生成数据
            generator = SmartDataGenerator(seed=42)
            df = generator.generate_training_data(
                num_samples=num_samples,
                include_temporal_features=True,
                include_network_types=True
            )
            
            # 保存数据
            generator.save_data(df, data_file)
        
        # 预处理数据
        self.preprocessor = DataPreprocessor(self.config['preprocess_config'])
        self.data_splits = self.preprocessor.preprocess_data(df)
        
        print(f"数据加载完成! 总共 {len(df)} 个样本")
        return self.data_splits
    
    def get_data_iterator(self, split: str = 'train', 
                         batch_size: int = None) -> Generator[Tuple[np.ndarray, np.ndarray], None, None]:
        """
        获取数据迭代器
        
        Args:
            split: 数据分割类型 ('train', 'val', 'test')
            batch_size: 批次大小
            
        Yields:
            批次数据 (X_batch, y_batch)
        """
        if self.data_splits is None:
            raise ValueError("请先加载数据")
        
        if split not in ['train', 'val', 'test']:
            raise ValueError("split 必须是 'train', 'val' 或 'test'")
        
        batch_size = batch_size or self.config['batch_size']
        X = self.data_splits[f'X_{split}']
        y = self.data_splits[f'y_{split}']
        
        num_samples = X.shape[0]
        indices = np.arange(num_samples)
        
        if self.config['shuffle'] and split == 'train':
            np.random.shuffle(indices)
        
        for start_idx in range(0, num_samples, batch_size):
            end_idx = min(start_idx + batch_size, num_samples)
            
            # 如果 drop_last 为 True 且最后一个批次不完整，则跳过
            if self.config['drop_last'] and (end_idx - start_idx) < batch_size:
                continue
            
            batch_indices = indices[start_idx:end_idx]
            X_batch = X[batch_indices]
            y_batch = y[batch_indices]
            
            yield X_batch, y_batch
    
    def get_dataset_info(self) -> Dict:
        """获取数据集信息"""
        if self.data_splits is None:
            return {}
        
        info = {
            'feature_names': self.data_splits.get('feature_names', []),
            'target_names': self.data_splits.get('target_names', []),
            'num_features': self.data_splits['X_train'].shape[1],
            'num_targets': self.data_splits['y_train'].shape[1],
            'train_samples': self.data_splits['X_train'].shape[0],
            'val_samples': self.data_splits['X_val'].shape[0],
            'test_samples': self.data_splits['X_test'].shape[0],
            'total_samples': (
                self.data_splits['X_train'].shape[0] +
                self.data_splits['X_val'].shape[0] +
                self.data_splits['X_test'].shape[0]
            )
        }
        
        return info
    
    def get_feature_statistics(self) -> Dict:
        """获取特征统计信息"""
        if self.data_splits is None:
            return {}
        
        X_train = self.data_splits['X_train']
        feature_names = self.data_splits.get('feature_names', [f'feature_{i}' for i in range(X_train.shape[1])])
        
        stats = {}
        for i, name in enumerate(feature_names):
            feature_data = X_train[:, i]
            stats[name] = {
                'mean': float(np.mean(feature_data)),
                'std': float(np.std(feature_data)),
                'min': float(np.min(feature_data)),
                'max': float(np.max(feature_data)),
                'median': float(np.median(feature_data))
            }
        
        return stats
    
    def get_target_statistics(self) -> Dict:
        """获取目标变量统计信息"""
        if self.data_splits is None:
            return {}
        
        y_train = self.data_splits['y_train']
        target_names = self.data_splits.get('target_names', [f'target_{i}' for i in range(y_train.shape[1])])
        
        stats = {}
        for i, name in enumerate(target_names):
            target_data = y_train[:, i]
            stats[name] = {
                'mean': float(np.mean(target_data)),
                'std': float(np.std(target_data)),
                'min': float(np.min(target_data)),
                'max': float(np.max(target_data)),
                'median': float(np.median(target_data))
            }
        
        return stats
    
    def create_data_subset(self, split: str = 'train', 
                          sample_ratio: float = 1.0,
                          random_state: int = 42) -> Tuple[np.ndarray, np.ndarray]:
        """
        创建数据子集
        
        Args:
            split: 数据分割类型
            sample_ratio: 采样比例
            random_state: 随机种子
            
        Returns:
            子集数据 (X_subset, y_subset)
        """
        if self.data_splits is None:
            raise ValueError("请先加载数据")
        
        X = self.data_splits[f'X_{split}']
        y = self.data_splits[f'y_{split}']
        
        if sample_ratio >= 1.0:
            return X, y
        
        num_samples = X.shape[0]
        subset_size = int(num_samples * sample_ratio)
        
        # 随机采样
        rng = np.random.RandomState(random_state)
        indices = rng.choice(num_samples, subset_size, replace=False)
        
        return X[indices], y[indices]
    
    def save_preprocessed_data(self, save_dir: str = "data/processed"):
        """
        保存预处理后的数据
        
        Args:
            save_dir: 保存目录
        """
        if self.data_splits is None:
            raise ValueError("没有可保存的数据")
        
        save_path = Path(save_dir)
        save_path.mkdir(parents=True, exist_ok=True)
        
        # 保存数据分割
        for key, value in self.data_splits.items():
            if isinstance(value, np.ndarray):
                np.save(save_path / f"{key}.npy", value)
            elif isinstance(value, list):
                # 保存列表为文本文件
                with open(save_path / f"{key}.txt", 'w') as f:
                    for item in value:
                        f.write(f"{item}\n")
        
        # 保存预处理配置
        if self.preprocessor:
            import json
            summary = self.preprocessor.get_preprocessing_summary()
            with open(save_path / "preprocessing_summary.json", 'w') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
        
        print(f"预处理数据已保存到: {save_path}")
    
    def load_preprocessed_data(self, load_dir: str = "data/processed") -> Dict[str, np.ndarray]:
        """
        加载预处理后的数据
        
        Args:
            load_dir: 加载目录
            
        Returns:
            数据分割字典
        """
        load_path = Path(load_dir)
        
        if not load_path.exists():
            raise FileNotFoundError(f"数据目录不存在: {load_path}")
        
        data_splits = {}
        
        # 加载数据分割
        for key in ['X_train', 'X_val', 'X_test', 'y_train', 'y_val', 'y_test']:
            file_path = load_path / f"{key}.npy"
            if file_path.exists():
                data_splits[key] = np.load(file_path)
        
        # 加载特征和目标名称
        for key in ['feature_names', 'target_names']:
            file_path = load_path / f"{key}.txt"
            if file_path.exists():
                with open(file_path, 'r') as f:
                    data_splits[key] = [line.strip() for line in f.readlines()]
        
        self.data_splits = data_splits
        
        print(f"预处理数据已从 {load_path} 加载")
        return data_splits
    
    def get_data_summary(self) -> str:
        """获取数据摘要"""
        if self.data_splits is None:
            return "数据未加载"
        
        info = self.get_dataset_info()
        feature_stats = self.get_feature_statistics()
        target_stats = self.get_target_statistics()
        
        summary = []
        summary.append("=== 数据摘要 ===")
        summary.append("")
        
        # 数据集信息
        summary.append("数据集信息:")
        summary.append(f"  总样本数: {info['total_samples']}")
        summary.append(f"  训练集: {info['train_samples']}")
        summary.append(f"  验证集: {info['val_samples']}")
        summary.append(f"  测试集: {info['test_samples']}")
        summary.append(f"  特征数: {info['num_features']}")
        summary.append(f"  目标数: {info['num_targets']}")
        summary.append("")
        
        # 特征信息
        summary.append("特征信息:")
        for i, name in enumerate(info['feature_names'][:5]):  # 只显示前5个特征
            stats = feature_stats.get(name, {})
            summary.append(f"  {name}: 均值={stats.get('mean', 0):.3f}, 标准差={stats.get('std', 0):.3f}")
        if len(info['feature_names']) > 5:
            summary.append(f"  ... 还有 {len(info['feature_names']) - 5} 个特征")
        summary.append("")
        
        # 目标信息
        summary.append("目标变量信息:")
        for name in info['target_names']:
            stats = target_stats.get(name, {})
            summary.append(f"  {name}: 均值={stats.get('mean', 0):.3f}, 标准差={stats.get('std', 0):.3f}")
        
        return "\n".join(summary)


class DataManager:
    """数据管理器 - 高级数据管理功能"""
    
    def __init__(self, data_dir: str = "data", config: Dict = None):
        """
        初始化数据管理器
        
        Args:
            data_dir: 数据目录
            config: 配置字典
        """
        self.data_loader = DataLoader(data_dir, config)
        self.config = config or {}
    
    def setup_training_data(self, num_samples: int = 10000, 
                          use_existing: bool = True) -> DataLoader:
        """
        设置训练数据
        
        Args:
            num_samples: 样本数量
            use_existing: 是否使用现有数据
            
        Returns:
            数据加载器实例
        """
        self.data_loader.load_or_generate_data(
            num_samples=num_samples,
            force_regenerate=not use_existing
        )
        return self.data_loader
    
    def get_data_for_training(self, batch_size: int = None) -> Dict:
        """
        获取训练用数据
        
        Args:
            batch_size: 批次大小
            
        Returns:
            训练数据字典
        """
        if self.data_loader.data_splits is None:
            self.setup_training_data()
        
        batch_size = batch_size or self.config.get('batch_size', 32)
        
        return {
            'train_iterator': self.data_loader.get_data_iterator('train', batch_size),
            'val_data': (
                self.data_loader.data_splits['X_val'],
                self.data_loader.data_splits['y_val']
            ),
            'test_data': (
                self.data_loader.data_splits['X_test'],
                self.data_loader.data_splits['y_test']
            ),
            'dataset_info': self.data_loader.get_dataset_info()
        }


if __name__ == "__main__":
    # 测试数据加载器
    print("测试数据加载器...")
    
    # 创建数据管理器
    data_manager = DataManager()
    
    # 设置训练数据
    data_loader = data_manager.setup_training_data(num_samples=1000)
    
    # 获取数据摘要
    print(data_loader.get_data_summary())
    
    # 测试数据迭代器
    print("\n测试数据迭代器...")
    train_iterator = data_loader.get_data_iterator('train', batch_size=16)
    
    for i, (X_batch, y_batch) in enumerate(train_iterator):
        print(f"批次 {i+1}: X形状={X_batch.shape}, y形状={y_batch.shape}")
        if i >= 2:  # 只显示前3个批次
            break
    
    # 获取数据统计信息
    print("\n特征统计:")
    feature_stats = data_loader.get_feature_statistics()
    for name, stats in list(feature_stats.items())[:3]:
        print(f"  {name}: {stats}")
    
    print("\n目标统计:")
    target_stats = data_loader.get_target_statistics()
    for name, stats in target_stats.items():
        print(f"  {name}: {stats}")
