"""
数据预处理器
对网络质量数据进行预处理和特征工程
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.model_selection import train_test_split
import warnings
warnings.filterwarnings('ignore')


class DataPreprocessor:
    """数据预处理器 - 处理网络质量数据"""
    
    def __init__(self, config: Dict = None):
        """
        初始化数据预处理器
        
        Args:
            config: 预处理配置
        """
        self.config = config or {}
        self.scalers = {}
        self.feature_columns = []
        self.target_columns = []
        
        # 默认配置
        self.default_config = {
            'test_size': 0.2,
            'validation_size': 0.1,
            'random_state': 42,
            'scale_features': True,
            'feature_engineering': True,
            'handle_outliers': True
        }
        
        # 更新配置
        self.default_config.update(self.config)
        self.config = self.default_config
    
    def preprocess_data(self, df: pd.DataFrame, 
                       feature_columns: List[str] = None,
                       target_columns: List[str] = None) -> Dict[str, np.ndarray]:
        """
        预处理数据
        
        Args:
            df: 原始数据DataFrame
            feature_columns: 特征列名列表
            target_columns: 目标列名列表
            
        Returns:
            预处理后的数据字典
        """
        print("开始数据预处理...")
        
        # 设置特征和目标列
        self._setup_columns(df, feature_columns, target_columns)
        
        # 复制数据避免修改原始数据
        processed_df = df.copy()
        
        # 数据清洗
        processed_df = self._clean_data(processed_df)
        
        # 特征工程
        if self.config['feature_engineering']:
            processed_df = self._feature_engineering(processed_df)
        
        # 处理异常值
        if self.config['handle_outliers']:
            processed_df = self._handle_outliers(processed_df)
        
        # 特征缩放
        if self.config['scale_features']:
            processed_df = self._scale_features(processed_df)
        
        # 分割数据集
        data_splits = self._split_data(processed_df)
        
        print("数据预处理完成!")
        return data_splits
    
    def _setup_columns(self, df: pd.DataFrame, feature_columns: List[str], target_columns: List[str]):
        """设置特征和目标列"""
        if feature_columns is None:
            # 默认特征列
            self.feature_columns = [
                'bandwidth_mbps', 'avg_delay_ms', 'packet_loss_rate',
                'hour_of_day', 'day_of_week', 'is_weekend', 'is_peak_hour',
                'network_wifi', 'network_cellular', 'network_ethernet', 'network_fiber'
            ]
            # 只保留数据中存在的列
            self.feature_columns = [col for col in self.feature_columns if col in df.columns]
        else:
            self.feature_columns = feature_columns
        
        if target_columns is None:
            # 默认目标列
            self.target_columns = [
                'hotspot_probability', 'quality_score', 'confidence'
            ]
            # 只保留数据中存在的列
            self.target_columns = [col for col in self.target_columns if col in df.columns]
        else:
            self.target_columns = target_columns
        
        print(f"特征列: {self.feature_columns}")
        print(f"目标列: {self.target_columns}")
    
    def _clean_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """数据清洗"""
        print("数据清洗...")
        
        # 检查缺失值
        missing_count = df.isnull().sum().sum()
        if missing_count > 0:
            print(f"发现 {missing_count} 个缺失值，进行填充...")
            # 数值列用中位数填充
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            for col in numeric_cols:
                if df[col].isnull().any():
                    df[col].fillna(df[col].median(), inplace=True)
        
        # 检查重复值
        duplicate_count = df.duplicated().sum()
        if duplicate_count > 0:
            print(f"发现 {duplicate_count} 个重复值，进行去重...")
            df = df.drop_duplicates()
        
        # 检查无限值
        inf_count = np.isinf(df.select_dtypes(include=[np.number])).sum().sum()
        if inf_count > 0:
            print(f"发现 {inf_count} 个无限值，进行替换...")
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            for col in numeric_cols:
                df[col] = df[col].replace([np.inf, -np.inf], np.nan)
                df[col].fillna(df[col].median(), inplace=True)
        
        return df
    
    def _feature_engineering(self, df: pd.DataFrame) -> pd.DataFrame:
        """特征工程"""
        print("特征工程...")
        
        # 基础特征
        if 'bandwidth_mbps' in df.columns and 'avg_delay_ms' in df.columns:
            # 带宽延迟比 (越高越好)
            df['bandwidth_delay_ratio'] = df['bandwidth_mbps'] / (df['avg_delay_ms'] + 1e-6)
            
            # 网络效率指标
            df['network_efficiency'] = (
                df['bandwidth_mbps'] / 100.0 * 
                (1 - df['avg_delay_ms'] / 500.0) * 
                (1 - df.get('packet_loss_rate', 0) / 0.1)
            )
        
        if 'packet_loss_rate' in df.columns:
            # 丢包率的对数变换
            df['log_packet_loss'] = np.log(df['packet_loss_rate'] + 1e-6)
        
        if 'bandwidth_mbps' in df.columns:
            # 带宽分类特征
            df['bandwidth_category'] = pd.cut(
                df['bandwidth_mbps'],
                bins=[0, 10, 50, 100, 200, float('inf')],
                labels=['very_low', 'low', 'medium', 'high', 'very_high']
            )
            # 转换为独热编码
            bandwidth_dummies = pd.get_dummies(df['bandwidth_category'], prefix='bandwidth')
            df = pd.concat([df, bandwidth_dummies], axis=1)
            df.drop('bandwidth_category', axis=1, inplace=True)
        
        if 'avg_delay_ms' in df.columns:
            # 延迟分类特征
            df['delay_category'] = pd.cut(
                df['avg_delay_ms'],
                bins=[0, 20, 50, 100, 200, float('inf')],
                labels=['very_low', 'low', 'medium', 'high', 'very_high']
            )
            # 转换为独热编码
            delay_dummies = pd.get_dummies(df['delay_category'], prefix='delay')
            df = pd.concat([df, delay_dummies], axis=1)
            df.drop('delay_category', axis=1, inplace=True)
        
        # 时间特征工程
        if 'hour_of_day' in df.columns:
            # 小时的正弦余弦编码 (处理周期性)
            df['hour_sin'] = np.sin(2 * np.pi * df['hour_of_day'] / 24)
            df['hour_cos'] = np.cos(2 * np.pi * df['hour_of_day'] / 24)
        
        if 'day_of_week' in df.columns:
            # 周几的正弦余弦编码
            df['day_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
            df['day_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
        
        # 交互特征
        if all(col in df.columns for col in ['bandwidth_mbps', 'avg_delay_ms', 'packet_loss_rate']):
            # 综合网络质量指标
            df['composite_quality'] = (
                (df['bandwidth_mbps'] / 100.0) * 0.4 +
                (1 - df['avg_delay_ms'] / 500.0) * 0.4 +
                (1 - df['packet_loss_rate'] / 0.1) * 0.2
            )
            
            # 网络稳定性指标
            df['network_stability'] = (
                (df['bandwidth_mbps'] / df['bandwidth_mbps'].std()) * 0.3 +
                (1 / (df['avg_delay_ms'] + 1e-6)) * 0.4 +
                (1 / (df['packet_loss_rate'] + 1e-6)) * 0.3
            )
        
        # 更新特征列
        new_features = [col for col in df.columns 
                       if col not in self.feature_columns + self.target_columns 
                       and col not in ['scenario_description']]
        self.feature_columns.extend(new_features)
        
        print(f"新增特征: {new_features}")
        
        return df
    
    def _handle_outliers(self, df: pd.DataFrame) -> pd.DataFrame:
        """处理异常值"""
        print("处理异常值...")
        
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        
        for col in numeric_cols:
            if col in self.target_columns:
                continue  # 不对目标变量处理异常值
            
            Q1 = df[col].quantile(0.25)
            Q3 = df[col].quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            
            # 统计异常值数量
            outliers = ((df[col] < lower_bound) | (df[col] > upper_bound)).sum()
            if outliers > 0:
                print(f"  {col}: 发现 {outliers} 个异常值")
                
                # 使用缩尾法处理异常值
                df[col] = np.clip(df[col], lower_bound, upper_bound)
        
        return df
    
    def _scale_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """特征缩放"""
        print("特征缩放...")
        
        # 只对特征列进行缩放，不对目标列缩放
        feature_df = df[self.feature_columns].copy()
        
        for col in self.feature_columns:
            if col in df.columns:
                # 根据特征类型选择缩放方法
                if col in ['bandwidth_mbps', 'avg_delay_ms', 'packet_loss_rate']:
                    # 使用StandardScaler对主要网络参数
                    scaler = StandardScaler()
                    feature_df[col] = scaler.fit_transform(feature_df[[col]]).flatten()
                    self.scalers[col] = scaler
                else:
                    # 对其他特征使用MinMaxScaler
                    scaler = MinMaxScaler()
                    feature_df[col] = scaler.fit_transform(feature_df[[col]]).flatten()
                    self.scalers[col] = scaler
        
        # 更新DataFrame中的特征列
        df[self.feature_columns] = feature_df[self.feature_columns]
        
        return df
    
    def _split_data(self, df: pd.DataFrame) -> Dict[str, np.ndarray]:
        """分割数据集"""
        print("分割数据集...")
        
        # 提取特征和目标
        X = df[self.feature_columns].values
        y = df[self.target_columns].values
        
        # 第一次分割：训练+验证 vs 测试
        X_train_val, X_test, y_train_val, y_test = train_test_split(
            X, y, 
            test_size=self.config['test_size'],
            random_state=self.config['random_state']
        )
        
        # 第二次分割：训练 vs 验证
        val_size_adjusted = self.config['validation_size'] / (1 - self.config['test_size'])
        X_train, X_val, y_train, y_val = train_test_split(
            X_train_val, y_train_val,
            test_size=val_size_adjusted,
            random_state=self.config['random_state']
        )
        
        data_splits = {
            'X_train': X_train.astype(np.float32),
            'X_val': X_val.astype(np.float32),
            'X_test': X_test.astype(np.float32),
            'y_train': y_train.astype(np.float32),
            'y_val': y_val.astype(np.float32),
            'y_test': y_test.astype(np.float32),
            'feature_names': self.feature_columns,
            'target_names': self.target_columns
        }
        
        print(f"训练集: {X_train.shape[0]} 样本")
        print(f"验证集: {X_val.shape[0]} 样本")
        print(f"测试集: {X_test.shape[0]} 样本")
        print(f"特征维度: {X_train.shape[1]}")
        print(f"目标维度: {y_train.shape[1]}")
        
        return data_splits
    
    def transform_new_data(self, df: pd.DataFrame) -> np.ndarray:
        """
        对新数据进行相同的预处理变换
        
        Args:
            df: 新数据DataFrame
            
        Returns:
            变换后的特征数组
        """
        # 复制数据
        processed_df = df.copy()
        
        # 应用相同的特征工程
        if self.config['feature_engineering']:
            processed_df = self._feature_engineering(processed_df)
        
        # 应用相同的特征缩放
        if self.config['scale_features']:
            for col in self.feature_columns:
                if col in processed_df.columns and col in self.scalers:
                    scaler = self.scalers[col]
                    processed_df[col] = scaler.transform(processed_df[[col]]).flatten()
        
        # 提取特征
        available_features = [col for col in self.feature_columns if col in processed_df.columns]
        X_new = processed_df[available_features].values.astype(np.float32)
        
        return X_new
    
    def get_preprocessing_summary(self) -> Dict:
        """获取预处理摘要"""
        summary = {
            'feature_columns': self.feature_columns,
            'target_columns': self.target_columns,
            'scalers_applied': list(self.scalers.keys()),
            'config': self.config
        }
        return summary


if __name__ == "__main__":
    # 测试数据预处理器
    print("测试数据预处理器...")
    
    # 生成示例数据
    from generator import SmartDataGenerator
    generator = SmartDataGenerator(seed=42)
    data = generator.generate_training_data(num_samples=1000)
    
    # 预处理数据
    preprocessor = DataPreprocessor()
    processed_data = preprocessor.preprocess_data(data)
    
    print("\n预处理摘要:")
    summary = preprocessor.get_preprocessing_summary()
    for key, value in summary.items():
        if key != 'config':
            print(f"{key}: {value}")
    
    print("\n数据形状:")
    for key in ['X_train', 'X_val', 'X_test', 'y_train', 'y_val', 'y_test']:
        print(f"{key}: {processed_data[key].shape}")
