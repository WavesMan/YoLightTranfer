"""
智能数据生成器
生成高质量的网络质量训练数据
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import random
from datetime import datetime, timedelta


class SmartDataGenerator:
    """智能数据生成器 - 生成网络质量分析训练数据"""
    
    def __init__(self, seed: int = 42):
        """
        初始化数据生成器
        
        Args:
            seed: 随机种子
        """
        self.seed = seed
        np.random.seed(seed)
        random.seed(seed)
        
        # 网络质量参数范围
        self.parameter_ranges = {
            'bandwidth_mbps': (1.0, 1000.0),      # 带宽范围 1-1000 Mbps
            'avg_delay_ms': (1.0, 500.0),         # 平均延迟 1-500 ms
            'packet_loss_rate': (0.0, 0.1)        # 丢包率 0-10%
        }
        
        # 网络质量类别定义
        self.quality_categories = {
            'excellent': {'bandwidth_min': 100, 'delay_max': 20, 'loss_max': 0.01},
            'good': {'bandwidth_min': 50, 'delay_max': 50, 'loss_max': 0.02},
            'fair': {'bandwidth_min': 20, 'delay_max': 100, 'loss_max': 0.05},
            'poor': {'bandwidth_min': 5, 'delay_max': 200, 'loss_max': 0.08},
            'very_poor': {'bandwidth_min': 1, 'delay_max': 500, 'loss_max': 0.10}
        }
    
    def generate_training_data(self, num_samples: int = 10000, 
                             include_temporal_features: bool = True,
                             include_network_types: bool = True) -> pd.DataFrame:
        """
        生成训练数据
        
        Args:
            num_samples: 样本数量
            include_temporal_features: 是否包含时间特征
            include_network_types: 是否包含网络类型
            
        Returns:
            训练数据DataFrame
        """
        print(f"生成 {num_samples} 个训练样本...")
        
        data = []
        
        for i in range(num_samples):
            sample = self._generate_single_sample(
                include_temporal_features=include_temporal_features,
                include_network_types=include_network_types
            )
            data.append(sample)
        
        df = pd.DataFrame(data)
        
        # 添加数据质量检查
        self._validate_data_quality(df)
        
        print(f"数据生成完成! 共生成 {len(df)} 个样本")
        return df
    
    def _generate_single_sample(self, include_temporal_features: bool = True,
                              include_network_types: bool = True) -> Dict:
        """生成单个数据样本"""
        # 基础网络参数
        bandwidth = self._generate_bandwidth()
        delay = self._generate_delay()
        loss_rate = self._generate_packet_loss()
        
        # 计算目标变量
        hotspot_probability = self._calculate_hotspot_probability(bandwidth, delay, loss_rate)
        quality_score = self._calculate_quality_score(bandwidth, delay, loss_rate)
        confidence = self._calculate_confidence(bandwidth, delay, loss_rate)
        
        sample = {
            'bandwidth_mbps': bandwidth,
            'avg_delay_ms': delay,
            'packet_loss_rate': loss_rate,
            'hotspot_probability': hotspot_probability,
            'quality_score': quality_score,
            'confidence': confidence
        }
        
        # 添加时间特征
        if include_temporal_features:
            temporal_features = self._generate_temporal_features()
            sample.update(temporal_features)
        
        # 添加网络类型
        if include_network_types:
            network_features = self._generate_network_type_features()
            sample.update(network_features)
        
        return sample
    
    def _generate_bandwidth(self) -> float:
        """生成带宽数据"""
        # 使用混合分布生成更真实的带宽数据
        distribution_type = random.choices(
            ['normal', 'lognormal', 'bimodal'],
            weights=[0.6, 0.3, 0.1]
        )[0]
        
        if distribution_type == 'normal':
            # 正态分布 - 大多数网络
            mean = 100.0
            std = 50.0
            bandwidth = np.random.normal(mean, std)
        elif distribution_type == 'lognormal':
            # 对数正态分布 - 高速网络
            mu, sigma = 4.0, 0.8
            bandwidth = np.random.lognormal(mu, sigma)
        else:
            # 双峰分布 - 混合网络环境
            if random.random() < 0.7:
                bandwidth = np.random.normal(50, 20)  # 低速网络
            else:
                bandwidth = np.random.normal(300, 100)  # 高速网络
        
        # 限制在合理范围内
        bandwidth = np.clip(bandwidth, 
                          self.parameter_ranges['bandwidth_mbps'][0],
                          self.parameter_ranges['bandwidth_mbps'][1])
        
        return round(bandwidth, 2)
    
    def _generate_delay(self) -> float:
        """生成延迟数据"""
        # 延迟与带宽负相关
        bandwidth = self._generate_bandwidth()
        
        # 基础延迟
        if bandwidth > 200:
            base_delay = np.random.normal(10, 5)  # 高速网络低延迟
        elif bandwidth > 50:
            base_delay = np.random.normal(30, 15)  # 中等网络中等延迟
        else:
            base_delay = np.random.normal(100, 50)  # 低速网络高延迟
        
        # 添加随机波动
        delay_variation = np.random.exponential(10)
        delay = base_delay + delay_variation
        
        # 限制在合理范围内
        delay = np.clip(delay,
                       self.parameter_ranges['avg_delay_ms'][0],
                       self.parameter_ranges['avg_delay_ms'][1])
        
        return round(delay, 2)
    
    def _generate_packet_loss(self) -> float:
        """生成丢包率数据"""
        # 丢包率与延迟正相关
        delay = self._generate_delay()
        
        if delay < 20:
            base_loss = np.random.exponential(0.001)  # 低延迟网络低丢包
        elif delay < 100:
            base_loss = np.random.exponential(0.005)  # 中等延迟网络中等丢包
        else:
            base_loss = np.random.exponential(0.02)   # 高延迟网络高丢包
        
        # 添加突发丢包
        if random.random() < 0.05:  # 5%的概率发生突发丢包
            base_loss += np.random.uniform(0.01, 0.05)
        
        # 限制在合理范围内
        loss_rate = np.clip(base_loss,
                          self.parameter_ranges['packet_loss_rate'][0],
                          self.parameter_ranges['packet_loss_rate'][1])
        
        return round(loss_rate, 4)
    
    def _calculate_hotspot_probability(self, bandwidth: float, delay: float, loss_rate: float) -> float:
        """计算热点推荐概率"""
        # 基于网络质量计算热点推荐概率
        bandwidth_score = min(bandwidth / 100.0, 1.0)  # 归一化带宽评分
        delay_score = max(0, 1 - (delay / 200.0))      # 归一化延迟评分
        loss_score = max(0, 1 - (loss_rate / 0.05))    # 归一化丢包评分
        
        # 加权综合评分
        hotspot_score = (
            0.5 * bandwidth_score +
            0.3 * delay_score +
            0.2 * loss_score
        )
        
        # 应用sigmoid函数得到概率
        probability = 1 / (1 + np.exp(-10 * (hotspot_score - 0.5)))
        
        return round(probability, 4)
    
    def _calculate_quality_score(self, bandwidth: float, delay: float, loss_rate: float) -> float:
        """计算网络质量评分"""
        # 网络质量评分计算
        if bandwidth >= 100 and delay <= 20 and loss_rate <= 0.01:
            quality_score = 0.9 + random.uniform(0, 0.1)  # 优秀
        elif bandwidth >= 50 and delay <= 50 and loss_rate <= 0.02:
            quality_score = 0.7 + random.uniform(0, 0.2)  # 良好
        elif bandwidth >= 20 and delay <= 100 and loss_rate <= 0.05:
            quality_score = 0.5 + random.uniform(0, 0.2)  # 一般
        elif bandwidth >= 5 and delay <= 200 and loss_rate <= 0.08:
            quality_score = 0.3 + random.uniform(0, 0.2)  # 较差
        else:
            quality_score = 0.1 + random.uniform(0, 0.2)  # 很差
        
        return round(quality_score, 4)
    
    def _calculate_confidence(self, bandwidth: float, delay: float, loss_rate: float) -> float:
        """计算预测置信度"""
        # 置信度基于网络参数的稳定性
        bandwidth_stability = min(1.0, bandwidth / 50.0)  # 带宽越高越稳定
        delay_stability = max(0, 1 - (delay / 100.0))     # 延迟越低越稳定
        loss_stability = max(0, 1 - (loss_rate / 0.03))   # 丢包率越低越稳定
        
        confidence = (
            0.4 * bandwidth_stability +
            0.4 * delay_stability +
            0.2 * loss_stability
        )
        
        # 添加随机噪声
        confidence += random.uniform(-0.05, 0.05)
        confidence = np.clip(confidence, 0.1, 0.99)
        
        return round(confidence, 4)
    
    def _generate_temporal_features(self) -> Dict:
        """生成时间相关特征"""
        # 模拟时间特征
        hour = random.randint(0, 23)
        day_of_week = random.randint(0, 6)  # 0=周一, 6=周日
        is_weekend = 1 if day_of_week >= 5 else 0
        is_peak_hour = 1 if (7 <= hour <= 9) or (17 <= hour <= 19) else 0
        
        return {
            'hour_of_day': hour,
            'day_of_week': day_of_week,
            'is_weekend': is_weekend,
            'is_peak_hour': is_peak_hour
        }
    
    def _generate_network_type_features(self) -> Dict:
        """生成网络类型特征"""
        network_types = ['wifi', 'cellular', 'ethernet', 'fiber']
        weights = [0.5, 0.3, 0.15, 0.05]  # 不同类型网络的概率
        
        network_type = random.choices(network_types, weights=weights)[0]
        
        # 独热编码
        features = {f'network_{nt}': 1 if nt == network_type else 0 
                   for nt in network_types}
        
        return features
    
    def _validate_data_quality(self, df: pd.DataFrame):
        """验证数据质量"""
        print("验证数据质量...")
        
        # 检查缺失值
        missing_values = df.isnull().sum().sum()
        if missing_values > 0:
            print(f"警告: 发现 {missing_values} 个缺失值")
        
        # 检查数据范围
        for col in ['bandwidth_mbps', 'avg_delay_ms', 'packet_loss_rate']:
            min_val = df[col].min()
            max_val = df[col].max()
            expected_min, expected_max = self.parameter_ranges[col]
            
            if min_val < expected_min or max_val > expected_max:
                print(f"警告: {col} 超出预期范围 [{expected_min}, {expected_max}]")
        
        # 检查目标变量范围
        for col in ['hotspot_probability', 'quality_score', 'confidence']:
            if df[col].min() < 0 or df[col].max() > 1:
                print(f"警告: {col} 超出 [0, 1] 范围")
        
        print("数据质量验证完成")
    
    def generate_test_scenarios(self, num_scenarios: int = 100) -> pd.DataFrame:
        """
        生成特定测试场景数据
        
        Args:
            num_scenarios: 场景数量
            
        Returns:
            测试场景数据
        """
        scenarios = []
        
        # 定义典型测试场景
        test_cases = [
            # (带宽, 延迟, 丢包率, 描述)
            (1000, 5, 0.001, "理想光纤网络"),
            (100, 20, 0.005, "良好WiFi网络"),
            (50, 50, 0.01, "一般4G网络"),
            (20, 100, 0.03, "较差3G网络"),
            (5, 200, 0.08, "边缘网络"),
            (2, 300, 0.1, "极限网络")
        ]
        
        for bandwidth, delay, loss_rate, description in test_cases:
            for _ in range(num_scenarios // len(test_cases)):
                # 在基础值上添加随机波动
                bw_var = bandwidth * random.uniform(0.8, 1.2)
                delay_var = delay * random.uniform(0.8, 1.2)
                loss_var = loss_rate * random.uniform(0.5, 2.0)
                
                scenario = {
                    'bandwidth_mbps': round(bw_var, 2),
                    'avg_delay_ms': round(delay_var, 2),
                    'packet_loss_rate': round(loss_var, 4),
                    'hotspot_probability': self._calculate_hotspot_probability(bw_var, delay_var, loss_var),
                    'quality_score': self._calculate_quality_score(bw_var, delay_var, loss_var),
                    'confidence': self._calculate_confidence(bw_var, delay_var, loss_var),
                    'scenario_description': description
                }
                scenarios.append(scenario)
        
        return pd.DataFrame(scenarios)
    
    def save_data(self, df: pd.DataFrame, filepath: str):
        """
        保存数据到文件
        
        Args:
            df: 数据DataFrame
            filepath: 文件路径
        """
        df.to_csv(filepath, index=False)
        print(f"数据已保存到: {filepath}")


if __name__ == "__main__":
    # 测试数据生成器
    print("测试智能数据生成器...")
    
    generator = SmartDataGenerator(seed=42)
    
    # 生成训练数据
    training_data = generator.generate_training_data(num_samples=1000)
    print(f"训练数据形状: {training_data.shape}")
    print("\n数据前5行:")
    print(training_data.head())
    
    # 生成测试场景
    test_scenarios = generator.generate_test_scenarios(num_scenarios=50)
    print(f"\n测试场景数据形状: {test_scenarios.shape}")
    print("\n测试场景前5行:")
    print(test_scenarios.head())
    
    # 保存示例数据
    generator.save_data(training_data, "example_training_data.csv")
    generator.save_data(test_scenarios, "example_test_scenarios.csv")
