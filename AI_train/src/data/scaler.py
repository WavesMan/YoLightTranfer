"""
特征缩放器
专门负责网络质量数据的特征缩放和标准化
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional
from sklearn.preprocessing import StandardScaler, MinMaxScaler, RobustScaler
from sklearn.base import BaseEstimator, TransformerMixin


class FeatureScaler(BaseEstimator, TransformerMixin):
    """特征缩放器 - 专门处理网络质量数据的特征缩放"""
    
    def __init__(self, scaling_method: str = 'standard', feature_config: Dict = None):
        """
        初始化特征缩放器
        
        Args:
            scaling_method: 缩放方法 ('standard', 'minmax', 'robust')
            feature_config: 特征配置字典
        """
        self.scaling_method = scaling_method
        self.feature_config = feature_config or {}
        self.scalers = {}
        self.feature_columns = []
        self.is_fitted = False
        
        # 默认特征配置
        self.default_config = {
            'bandwidth_mbps': {'method': 'standard', 'clip_range': (0, 1000)},
            'avg_delay_ms': {'method': 'standard', 'clip_range': (0, 500)},
            'packet_loss_rate': {'method': 'minmax', 'clip_range': (0, 0.1)},
            'hour_of_day': {'method': 'minmax', 'clip_range': (0, 23)},
            'day_of_week': {'method': 'minmax', 'clip_range': (0, 6)},
            'is_weekend': {'method': 'none'},  # 二元特征不缩放
            'is_peak_hour': {'method': 'none'},
            'network_wifi': {'method': 'none'},
            'network_cellular': {'method': 'none'},
            'network_ethernet': {'method': 'none'},
            'network_fiber': {'method': 'none'}
        }
        
        # 更新配置
        self.default_config.update(self.feature_config)
        self.feature_config = self.default_config
    
    def fit(self, X: pd.DataFrame, y=None):
        """
        拟合缩放器
        
        Args:
            X: 训练数据DataFrame
            y: 目标变量（可选）
            
        Returns:
            self
        """
        print("拟合特征缩放器...")
        
        # 确定特征列
        if isinstance(X, pd.DataFrame):
            self.feature_columns = X.columns.tolist()
        else:
            # 如果是numpy数组，创建默认列名
            self.feature_columns = [f'feature_{i}' for i in range(X.shape[1])]
            X = pd.DataFrame(X, columns=self.feature_columns)
        
        # 为每个特征创建合适的缩放器
        for col in self.feature_columns:
            if col in self.feature_config:
                config = self.feature_config[col]
                method = config.get('method', self.scaling_method)
            else:
                method = self.scaling_method
            
            # 根据配置选择缩放方法
            if method == 'standard':
                self.scalers[col] = StandardScaler()
            elif method == 'minmax':
                self.scalers[col] = MinMaxScaler()
            elif method == 'robust':
                self.scalers[col] = RobustScaler()
            elif method == 'none':
                self.scalers[col] = None  # 不缩放
            else:
                self.scalers[col] = StandardScaler()  # 默认使用标准缩放
            
            # 拟合缩放器（如果不为None）
            if self.scalers[col] is not None:
                # 确保数据是二维的
                col_data = X[[col]].values
                self.scalers[col].fit(col_data)
        
        self.is_fitted = True
        print(f"特征缩放器拟合完成，共处理 {len(self.feature_columns)} 个特征")
        return self
    
    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        """
        变换数据
        
        Args:
            X: 要变换的数据
            
        Returns:
            变换后的数据
        """
        if not self.is_fitted:
            raise ValueError("缩放器尚未拟合，请先调用fit方法")
        
        print("变换数据特征...")
        
        # 复制数据避免修改原始数据
        if isinstance(X, pd.DataFrame):
            X_transformed = X.copy()
        else:
            # 如果是numpy数组，转换为DataFrame
            X_transformed = pd.DataFrame(X, columns=self.feature_columns)
        
        # 对每个特征应用缩放
        for col in self.feature_columns:
            if col not in X_transformed.columns:
                continue  # 跳过不存在的列
            
            if self.scalers[col] is not None:
                # 应用缩放
                col_data = X_transformed[[col]].values
                transformed_data = self.scalers[col].transform(col_data)
                X_transformed[col] = transformed_data.flatten()
            
            # 应用裁剪（如果配置了）
            if col in self.feature_config:
                config = self.feature_config[col]
                if 'clip_range' in config:
                    min_val, max_val = config['clip_range']
                    X_transformed[col] = np.clip(X_transformed[col], min_val, max_val)
        
        print("数据特征变换完成")
        return X_transformed
    
    def fit_transform(self, X: pd.DataFrame, y=None) -> pd.DataFrame:
        """
        拟合并变换数据
        
        Args:
            X: 训练数据
            y: 目标变量（可选）
            
        Returns:
            变换后的数据
        """
        return self.fit(X, y).transform(X)
    
    def inverse_transform(self, X: pd.DataFrame) -> pd.DataFrame:
        """
        逆变换数据
        
        Args:
            X: 缩放后的数据
            
        Returns:
            原始尺度数据
        """
        if not self.is_fitted:
            raise ValueError("缩放器尚未拟合，无法进行逆变换")
        
        print("逆变换数据特征...")
        
        # 复制数据
        if isinstance(X, pd.DataFrame):
            X_original = X.copy()
        else:
            X_original = pd.DataFrame(X, columns=self.feature_columns)
        
        # 对每个特征应用逆变换
        for col in self.feature_columns:
            if col not in X_original.columns:
                continue
            
            if self.scalers[col] is not None:
                # 应用逆变换
                col_data = X_original[[col]].values
                original_data = self.scalers[col].inverse_transform(col_data)
                X_original[col] = original_data.flatten()
        
        print("数据特征逆变换完成")
        return X_original
    
    def get_scaling_summary(self) -> Dict:
        """
        获取缩放摘要
        
        Returns:
            缩放配置摘要
        """
        summary = {
            'scaling_method': self.scaling_method,
            'feature_columns': self.feature_columns,
            'scalers_applied': {},
            'is_fitted': self.is_fitted
        }
        
        for col, scaler in self.scalers.items():
            if scaler is not None:
                summary['scalers_applied'][col] = {
                    'type': type(scaler).__name__,
                    'method': self.feature_config.get(col, {}).get('method', self.scaling_method)
                }
            else:
                summary['scalers_applied'][col] = {'type': 'None', 'method': 'none'}
        
        return summary
    
    def save_scalers(self, filepath: str):
        """
        保存缩放器到文件
        
        Args:
            filepath: 文件路径
        """
        import joblib
        
        if not self.is_fitted:
            raise ValueError("缩放器尚未拟合，无法保存")
        
        # 保存缩放器字典
        scaler_data = {
            'scalers': self.scalers,
            'feature_columns': self.feature_columns,
            'feature_config': self.feature_config,
            'scaling_method': self.scaling_method
        }
        
        joblib.dump(scaler_data, filepath)
        print(f"缩放器已保存到: {filepath}")
    
    def load_scalers(self, filepath: str):
        """
        从文件加载缩放器
        
        Args:
            filepath: 文件路径
        """
        import joblib
        
        scaler_data = joblib.load(filepath)
        
        self.scalers = scaler_data['scalers']
        self.feature_columns = scaler_data['feature_columns']
        self.feature_config = scaler_data['feature_config']
        self.scaling_method = scaler_data['scaling_method']
        self.is_fitted = True
        
        print(f"缩放器已从 {filepath} 加载")


class NetworkQualityScaler(FeatureScaler):
    """网络质量专用缩放器 - 针对网络质量数据的特殊处理"""
    
    def __init__(self):
        """初始化网络质量专用缩放器"""
        # 网络质量数据的特殊配置
        network_quality_config = {
            'bandwidth_mbps': {'method': 'standard', 'clip_range': (0, 1000)},
            'avg_delay_ms': {'method': 'robust', 'clip_range': (0, 500)},  # 对异常值鲁棒
            'packet_loss_rate': {'method': 'minmax', 'clip_range': (0, 0.1)},
            'hotspot_probability': {'method': 'none'},  # 目标变量不缩放
            'quality_score': {'method': 'none'},
            'confidence': {'method': 'none'},
            'bandwidth_delay_ratio': {'method': 'standard'},
            'network_efficiency': {'method': 'minmax'},
            'log_packet_loss': {'method': 'standard'},
            'composite_quality': {'method': 'minmax'},
            'network_stability': {'method': 'minmax'}
        }
        
        super().__init__(scaling_method='standard', feature_config=network_quality_config)
    
    def fit_network_data(self, df: pd.DataFrame) -> 'NetworkQualityScaler':
        """
        专门针对网络质量数据拟合
        
        Args:
            df: 网络质量数据DataFrame
            
        Returns:
            self
        """
        # 自动识别网络质量相关特征
        network_features = [
            'bandwidth_mbps', 'avg_delay_ms', 'packet_loss_rate',
            'bandwidth_delay_ratio', 'network_efficiency', 'log_packet_loss',
            'composite_quality', 'network_stability'
        ]
        
        # 只选择存在的特征
        available_features = [col for col in network_features if col in df.columns]
        
        if not available_features:
            raise ValueError("数据中未找到网络质量相关特征")
        
        # 只对网络质量特征进行拟合
        network_df = df[available_features]
        return self.fit(network_df)


# 便捷函数
def create_standard_scaler() -> FeatureScaler:
    """创建标准缩放器"""
    return FeatureScaler(scaling_method='standard')


def create_minmax_scaler() -> FeatureScaler:
    """创建MinMax缩放器"""
    return FeatureScaler(scaling_method='minmax')


def create_network_quality_scaler() -> NetworkQualityScaler:
    """创建网络质量专用缩放器"""
    return NetworkQualityScaler()


if __name__ == "__main__":
    # 测试特征缩放器
    print("测试特征缩放器...")
    
    # 生成示例数据
    from generator import SmartDataGenerator
    generator = SmartDataGenerator(seed=42)
    data = generator.generate_training_data(num_samples=100)
    
    # 测试标准缩放器
    print("\n1. 测试标准缩放器:")
    standard_scaler = create_standard_scaler()
    data_standard = standard_scaler.fit_transform(data)
    print("标准缩放完成")
    
    # 测试逆变换
    data_restored = standard_scaler.inverse_transform(data_standard)
    print("逆变换完成")
    
    # 测试网络质量专用缩放器
    print("\n2. 测试网络质量专用缩放器:")
    network_scaler = create_network_quality_scaler()
    data_network = network_scaler.fit_network_data(data)
    print("网络质量缩放完成")
    
    # 获取摘要
    summary = network_scaler.get_scaling_summary()
    print("\n缩放摘要:")
    for key, value in summary.items():
        if key != 'scalers_applied':
            print(f"{key}: {value}")
    
    print("\n特征缩放器测试完成!")
