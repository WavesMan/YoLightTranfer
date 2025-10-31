"""
Data Generator for Network Quality Analysis

This module generates synthetic network data for training AI models.
It simulates different network scenarios including strong, weak, and critical networks.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import random
import math


class DataGenerator:
    """
    Generates synthetic network quality data for model training.
    
    Features:
    - bandwidthMbps: Network bandwidth in Mbps
    - avgDelayMs: Average round-trip delay in milliseconds  
    - packetLossRate: Packet loss rate in percentage
    
    Labels:
    - shouldRecommendHotspot: Whether to recommend hotspot (0 or 1)
    - qualityScore: Network quality score (0.0-1.0)
    - confidence: Model confidence score (0.0-1.0)
    """
    
    def __init__(self, seed: int = 42, uncertainty_level: float = 0.5):
        """Initialize data generator with random seed and uncertainty level."""
        self.seed = seed
        self.uncertainty_level = min(max(uncertainty_level, 0.0), 1.0)  # 0.0-1.0
        np.random.seed(seed)
        random.seed(seed)
        
        # Define network scenarios with enhanced variability
        self.scenarios = {
            "strong_network": {
                "bandwidth_range": (50.0, 100.0),  # Mbps
                "delay_range": (10.0, 50.0),       # ms
                "loss_range": (0.0, 1.0),          # %
                "hotspot_recommendation": 0,       # Don't recommend hotspot
                "quality_range": (0.8, 1.0),       # High quality
                "distribution_type": "gaussian"    # Distribution type for this scenario
            },
            "weak_network": {
                "bandwidth_range": (1.0, 10.0),    # Mbps
                "delay_range": (100.0, 500.0),     # ms
                "loss_range": (5.0, 20.0),         # %
                "hotspot_recommendation": 1,       # Recommend hotspot
                "quality_range": (0.0, 0.3),       # Low quality
                "distribution_type": "exponential" # Heavy-tailed for weak networks
            },
            "critical_network": {
                "bandwidth_range": (10.0, 30.0),   # Mbps
                "delay_range": (50.0, 150.0),      # ms
                "loss_range": (1.0, 8.0),          # %
                "hotspot_recommendation": 1,       # Recommend hotspot
                "quality_range": (0.3, 0.6),       # Medium quality
                "distribution_type": "mixed"       # Mixed distribution for critical cases
            },
            "mixed_network": {
                "bandwidth_range": (5.0, 80.0),    # Wide range for mixed scenarios
                "delay_range": (20.0, 300.0),      # Wide range
                "loss_range": (0.5, 15.0),         # Wide range
                "hotspot_recommendation": None,    # Will be determined probabilistically
                "quality_range": (0.2, 0.8),       # Mixed quality
                "distribution_type": "mixed"       # Highly variable
            }
        }
        
        # Network types with different characteristics
        self.network_types = {
            "WiFi": {"stability": 0.8, "max_bandwidth": 100.0},
            "4G": {"stability": 0.6, "max_bandwidth": 50.0},
            "5G": {"stability": 0.9, "max_bandwidth": 200.0},
            "Satellite": {"stability": 0.4, "max_bandwidth": 25.0}
        }
    
    def _generate_feature_with_distribution(self, range_tuple: Tuple[float, float], 
                                          distribution_type: str) -> float:
        """Generate feature value using different distributions."""
        min_val, max_val = range_tuple
        mean_val = (min_val + max_val) / 2.0
        std_val = (max_val - min_val) / 6.0  # Approx 99.7% within range for normal
        
        if distribution_type == "gaussian":
            value = np.random.normal(mean_val, std_val)
        elif distribution_type == "exponential":
            # Exponential distribution with mean adjusted to range
            scale = (max_val - min_val) / 3.0
            value = min_val + np.random.exponential(scale)
        elif distribution_type == "mixed":
            # Mix of distributions for variability
            if np.random.random() < 0.7:
                value = np.random.normal(mean_val, std_val)
            else:
                value = np.random.exponential((max_val - min_val) / 4.0) + min_val
        else:
            # Default to uniform
            value = np.random.uniform(min_val, max_val)
        
        # Apply bounds
        return max(min_val, min(max_val, value))
    
    def _add_nonlinear_interactions(self, bandwidth: float, delay: float, loss: float) -> Tuple[float, float, float]:
        """Add enhanced nonlinear interactions between features."""
        # Bandwidth-delay tradeoff (higher bandwidth often means lower delay)
        if np.random.random() < 0.4:
            delay = delay * (1.0 - 0.25 * (bandwidth / 100.0))
        
        # Loss-delay correlation (higher loss often means higher delay)
        if np.random.random() < 0.5:
            delay = delay * (1.0 + 0.15 * (loss / 20.0))
        
        # Bandwidth-loss inverse relationship (poor bandwidth often means higher loss)
        if np.random.random() < 0.35:
            loss = loss * (1.0 + 0.2 * (1.0 - bandwidth / 100.0))
        
        # Enhanced feature interactions
        # Bandwidth-delay-loss complex interaction
        if np.random.random() < 0.3:
            interaction_factor = (bandwidth * delay * loss) / 10000.0
            delay = delay * (1.0 + 0.1 * interaction_factor)
        
        # Quadratic effects
        if np.random.random() < 0.25:
            # Bandwidth squared effect on delay (diminishing returns)
            delay = delay * (1.0 - 0.05 * (bandwidth / 100.0) ** 2)
        
        # Logarithmic scaling for extreme values
        if np.random.random() < 0.2:
            # Apply log scaling to delay for very high values
            if delay > 300:
                delay = 300 + np.log(delay - 299) * 50
        
        # Conditional interactions based on network quality
        quality_estimate = (bandwidth / 100.0 * 0.5 + 
                           (1 - delay / 500.0) * 0.3 + 
                           (1 - loss / 20.0) * 0.2)
        
        if quality_estimate < 0.3:  # Poor network
            # In poor networks, small changes have bigger impact
            if np.random.random() < 0.4:
                delay = delay * (1.0 + 0.1 * (1.0 - quality_estimate))
        elif quality_estimate > 0.7:  # Good network
            # In good networks, features are more stable
            if np.random.random() < 0.3:
                delay = delay * (1.0 - 0.05 * quality_estimate)
        
        return bandwidth, delay, loss
    
    def _generate_network_type_effects(self, bandwidth: float, delay: float, loss: float, 
                                     network_type: str) -> Tuple[float, float, float]:
        """Apply network type specific effects to features."""
        if network_type not in self.network_types:
            return bandwidth, delay, loss
            
        network_info = self.network_types[network_type]
        stability = network_info["stability"]
        max_bw = network_info["max_bandwidth"]
        
        # Apply network type constraints
        bandwidth = min(bandwidth, max_bw * np.random.uniform(0.8, 1.2))
        
        # Apply stability effects
        delay_variation = 1.0 + (1.0 - stability) * np.random.normal(0, 0.3)
        loss_variation = 1.0 + (1.0 - stability) * np.random.exponential(0.2)
        
        delay = delay * delay_variation
        loss = loss * loss_variation
        
        return bandwidth, delay, loss
    
    def _calculate_enhanced_quality_score(self, bandwidth: float, delay: float, loss: float, 
                                        network_type: str) -> float:
        """Calculate enhanced quality score with network type consideration."""
        # Base quality calculation
        base_quality = self._calculate_quality_score(bandwidth, delay, loss)
        
        # Apply network type adjustments
        if network_type in self.network_types:
            stability = self.network_types[network_type]["stability"]
            # More stable networks get slight quality boost
            quality_adjustment = (stability - 0.7) * 0.1  # ±0.03 adjustment
            base_quality = min(max(base_quality + quality_adjustment, 0.0), 1.0)
        
        # Add small random variation
        random_variation = np.random.normal(0, 0.05 * self.uncertainty_level)
        final_quality = min(max(base_quality + random_variation, 0.0), 1.0)
        
        return final_quality
    
    def _determine_hotspot_recommendation(self, bandwidth: float, delay: float, loss: float,
                                        quality_score: float, base_recommendation: Optional[int]) -> Tuple[int, float]:
        """Determine hotspot recommendation with probabilistic uncertainty."""
        # Calculate recommendation probability based on features
        bandwidth_factor = max(0.0, 1.0 - bandwidth / 30.0)  # Higher bandwidth = lower probability
        delay_factor = min(1.0, delay / 200.0)  # Higher delay = higher probability
        loss_factor = min(1.0, loss / 15.0)  # Higher loss = higher probability
        quality_factor = 1.0 - quality_score  # Lower quality = higher probability
        
        # Combined probability with weights
        probability = (0.4 * bandwidth_factor + 0.3 * delay_factor + 
                      0.2 * loss_factor + 0.1 * quality_factor)
        
        # Apply uncertainty level to make probabilities more ambiguous
        uncertainty_effect = np.random.normal(0, 0.2 * self.uncertainty_level)
        probability = min(max(probability + uncertainty_effect, 0.0), 1.0)
        
        # If base recommendation is provided, blend with calculated probability
        if base_recommendation is not None:
            blend_factor = 0.7 - 0.4 * self.uncertainty_level  # More uncertainty = less base influence
            probability = blend_factor * probability + (1 - blend_factor) * base_recommendation
        
        # Convert probability to binary decision with some randomness near threshold
        threshold = 0.5
        if abs(probability - threshold) < 0.1 * self.uncertainty_level:
            # Near threshold, add more randomness
            threshold += np.random.normal(0, 0.1)
        
        recommendation = 1 if probability > threshold else 0
        
        return recommendation, probability
    
    def _calculate_enhanced_confidence(self, bandwidth: float, delay: float, loss: float,
                                     recommendation: int, probability: float) -> float:
        """Calculate enhanced confidence score considering uncertainty."""
        base_confidence = self._calculate_confidence(bandwidth, delay, loss, recommendation)
        
        # Adjust confidence based on how close probability is to decision threshold
        distance_from_threshold = abs(probability - 0.5)
        threshold_penalty = max(0.0, 0.3 - distance_from_threshold * 0.6)  # Penalty for ambiguous cases
        
        # Apply uncertainty level to confidence
        uncertainty_penalty = self.uncertainty_level * 0.2
        
        final_confidence = base_confidence * (1.0 - threshold_penalty - uncertainty_penalty)
        
        return min(max(final_confidence, 0.1), 1.0)  # Minimum 10% confidence
    
    def generate_sample(self, scenario: str, network_type: Optional[str] = None) -> Dict[str, float]:
        """Generate a single data sample for given scenario with enhanced randomness."""
        if scenario not in self.scenarios:
            raise ValueError(f"Unknown scenario: {scenario}")
        
        params = self.scenarios[scenario]
        
        # Randomly select network type if not provided
        if network_type is None:
            network_type = random.choice(list(self.network_types.keys()))
        
        # Generate features using enhanced distribution methods
        distribution_type = params.get("distribution_type", "uniform")
        bandwidth = self._generate_feature_with_distribution(params["bandwidth_range"], distribution_type)
        delay = self._generate_feature_with_distribution(params["delay_range"], distribution_type)
        loss = self._generate_feature_with_distribution(params["loss_range"], distribution_type)
        
        # Add enhanced noise based on uncertainty level
        noise_scale = 0.1 + 0.2 * self.uncertainty_level
        bandwidth += np.random.normal(0, bandwidth * noise_scale)
        delay += np.random.normal(0, delay * noise_scale * 1.5)
        loss += np.random.normal(0, loss * noise_scale * 2.0)
        
        # Apply nonlinear interactions between features
        bandwidth, delay, loss = self._add_nonlinear_interactions(bandwidth, delay, loss)
        
        # Apply network type specific effects
        bandwidth, delay, loss = self._generate_network_type_effects(bandwidth, delay, loss, network_type)
        
        # Ensure realistic bounds
        bandwidth = max(0.1, bandwidth)
        delay = max(1.0, delay)
        loss = max(0.0, min(100.0, loss))
        
        # Generate quality score with enhanced calculation
        quality_score = self._calculate_enhanced_quality_score(bandwidth, delay, loss, network_type)
        
        # Determine hotspot recommendation with probabilistic uncertainty
        hotspot_rec, recommendation_prob = self._determine_hotspot_recommendation(
            bandwidth, delay, loss, quality_score, params.get("hotspot_recommendation")
        )
        
        # Calculate confidence with uncertainty consideration
        confidence = self._calculate_enhanced_confidence(
            bandwidth, delay, loss, hotspot_rec, recommendation_prob
        )
        
        # Add label noise based on uncertainty level
        if np.random.random() < self.uncertainty_level * 0.15:
            hotspot_rec = 1 - hotspot_rec  # Flip label
        
        return {
            "bandwidthMbps": bandwidth,
            "avgDelayMs": delay,
            "packetLossRate": loss,
            "networkType": network_type,
            "shouldRecommendHotspot": hotspot_rec,
            "recommendationProbability": recommendation_prob,
            "qualityScore": quality_score,
            "confidence": confidence,
            "scenario": scenario
        }
    
    def _calculate_quality_score(self, bandwidth: float, delay: float, loss: float) -> float:
        """Calculate network quality score based on features."""
        # Normalize features
        bandwidth_score = min(bandwidth / 100.0, 1.0)  # Max 100 Mbps
        delay_score = max(0.0, 1.0 - (delay / 500.0))  # Max 500 ms
        loss_score = max(0.0, 1.0 - (loss / 20.0))     # Max 20% loss
        
        # Weighted combination
        quality = (0.5 * bandwidth_score + 0.3 * delay_score + 0.2 * loss_score)
        return min(max(quality, 0.0), 1.0)
    
    def _calculate_confidence(self, bandwidth: float, delay: float, loss: float, 
                            hotspot_rec: int) -> float:
        """Calculate model confidence based on feature clarity."""
        # Higher confidence when features clearly indicate a scenario
        if hotspot_rec == 1:  # Weak network
            confidence = (1.0 - min(bandwidth / 30.0, 1.0)) * 0.6 + \
                        (min(delay / 200.0, 1.0)) * 0.3 + \
                        (min(loss / 15.0, 1.0)) * 0.1
        else:  # Strong network
            confidence = (min(bandwidth / 50.0, 1.0)) * 0.6 + \
                        (1.0 - min(delay / 100.0, 1.0)) * 0.3 + \
                        (1.0 - min(loss / 5.0, 1.0)) * 0.1
        
        return min(max(confidence, 0.3), 1.0)  # Minimum 30% confidence
    
    def generate_dataset(self, n_samples: int = 1000, 
                        scenario_weights: Dict[str, float] = None,
                        include_mixed_scenarios: bool = True) -> pd.DataFrame:
        """
        Generate a complete dataset with balanced scenarios and enhanced randomness.
        
        Args:
            n_samples: Total number of samples to generate
            scenario_weights: Dictionary with scenario names and their weights
            include_mixed_scenarios: Whether to include mixed network scenarios
            
        Returns:
            DataFrame with generated data
        """
        if scenario_weights is None:
            if include_mixed_scenarios:
                scenario_weights = {
                    "strong_network": 0.3,
                    "weak_network": 0.25,
                    "critical_network": 0.25,
                    "mixed_network": 0.2
                }
            else:
                scenario_weights = {
                    "strong_network": 0.4,
                    "weak_network": 0.3,
                    "critical_network": 0.3
                }
        
        # Calculate samples per scenario
        samples_per_scenario = {}
        remaining_samples = n_samples
        
        for scenario, weight in scenario_weights.items():
            samples = int(n_samples * weight)
            samples_per_scenario[scenario] = samples
            remaining_samples -= samples
        
        # Distribute remaining samples
        scenarios = list(scenario_weights.keys())
        for i in range(remaining_samples):
            samples_per_scenario[scenarios[i % len(scenarios)]] += 1
        
        # Generate data
        data = []
        for scenario, count in samples_per_scenario.items():
            for _ in range(count):
                sample = self.generate_sample(scenario)
                data.append(sample)
        
        # Shuffle data
        random.shuffle(data)
        
        return pd.DataFrame(data)
    
    def generate_decision_boundary_samples(self, n_samples: int = 100) -> pd.DataFrame:
        """
        Generate samples specifically near the decision boundary (probability 0.4-0.6).
        
        Args:
            n_samples: Number of boundary samples to generate
            
        Returns:
            DataFrame with boundary samples
        """
        boundary_data = []
        
        for _ in range(n_samples):
            # Generate features that result in probabilities near 0.5
            # Mix of different boundary scenarios
            scenario_type = np.random.choice(['balanced', 'conflicting', 'moderate'])
            
            if scenario_type == 'balanced':
                # Balanced features that naturally result in ~0.5 probability
                bandwidth = np.random.uniform(15.0, 35.0)
                delay = np.random.uniform(80.0, 180.0)
                loss = np.random.uniform(3.0, 8.0)
            elif scenario_type == 'conflicting':
                # Conflicting features that push probability in opposite directions
                if np.random.random() < 0.5:
                    bandwidth = np.random.uniform(25.0, 45.0)  # Good bandwidth
                    delay = np.random.uniform(150.0, 300.0)    # Bad delay
                    loss = np.random.uniform(2.0, 6.0)         # Moderate loss
                else:
                    bandwidth = np.random.uniform(8.0, 20.0)   # Poor bandwidth
                    delay = np.random.uniform(30.0, 80.0)      # Good delay
                    loss = np.random.uniform(1.0, 4.0)         # Good loss
            else:  # moderate
                # Moderate values across all features
                bandwidth = np.random.uniform(20.0, 40.0)
                delay = np.random.uniform(100.0, 200.0)
                loss = np.random.uniform(4.0, 10.0)
            
            # Apply enhanced processing
            bandwidth, delay, loss = self._add_nonlinear_interactions(bandwidth, delay, loss)
            network_type = random.choice(list(self.network_types.keys()))
            bandwidth, delay, loss = self._generate_network_type_effects(bandwidth, delay, loss, network_type)
            
            # Ensure realistic bounds
            bandwidth = max(0.1, bandwidth)
            delay = max(1.0, delay)
            loss = max(0.0, min(100.0, loss))
            
            quality_score = self._calculate_enhanced_quality_score(bandwidth, delay, loss, network_type)
            hotspot_rec, recommendation_prob = self._determine_hotspot_recommendation(
                bandwidth, delay, loss, quality_score, None
            )
            
            # Force probability to be near boundary if needed
            if abs(recommendation_prob - 0.5) > 0.15:
                # Adjust features to push probability toward boundary
                adjustment_factor = 0.5 - recommendation_prob
                if adjustment_factor > 0:  # Need to increase probability
                    bandwidth = bandwidth * (1.0 - 0.1 * adjustment_factor)
                    delay = delay * (1.0 + 0.15 * adjustment_factor)
                else:  # Need to decrease probability
                    bandwidth = bandwidth * (1.0 + 0.1 * abs(adjustment_factor))
                    delay = delay * (1.0 - 0.15 * abs(adjustment_factor))
                
                # Recalculate with adjusted features
                quality_score = self._calculate_enhanced_quality_score(bandwidth, delay, loss, network_type)
                hotspot_rec, recommendation_prob = self._determine_hotspot_recommendation(
                    bandwidth, delay, loss, quality_score, None
                )
            
            confidence = self._calculate_enhanced_confidence(
                bandwidth, delay, loss, hotspot_rec, recommendation_prob
            )
            
            boundary_data.append({
                "bandwidthMbps": bandwidth,
                "avgDelayMs": delay,
                "packetLossRate": loss,
                "networkType": network_type,
                "shouldRecommendHotspot": hotspot_rec,
                "recommendationProbability": recommendation_prob,
                "qualityScore": quality_score,
                "confidence": confidence,
                "scenario": "boundary"
            })
        
        return pd.DataFrame(boundary_data)
    
    def generate_conflict_samples(self, n_samples: int = 100) -> pd.DataFrame:
        """
        Generate samples with conflicting features to test model robustness.
        
        Args:
            n_samples: Number of conflict samples to generate
            
        Returns:
            DataFrame with conflict samples
        """
        conflict_data = []
        
        for _ in range(n_samples):
            # Generate features that create ambiguity
            if np.random.random() < 0.5:
                # High bandwidth but poor other metrics
                bandwidth = np.random.uniform(40.0, 80.0)
                delay = np.random.uniform(150.0, 400.0)
                loss = np.random.uniform(8.0, 20.0)
            else:
                # Low bandwidth but good other metrics
                bandwidth = np.random.uniform(5.0, 15.0)
                delay = np.random.uniform(10.0, 50.0)
                loss = np.random.uniform(0.1, 2.0)
            
            # Apply enhanced processing
            bandwidth, delay, loss = self._add_nonlinear_interactions(bandwidth, delay, loss)
            network_type = random.choice(list(self.network_types.keys()))
            bandwidth, delay, loss = self._generate_network_type_effects(bandwidth, delay, loss, network_type)
            
            quality_score = self._calculate_enhanced_quality_score(bandwidth, delay, loss, network_type)
            hotspot_rec, recommendation_prob = self._determine_hotspot_recommendation(
                bandwidth, delay, loss, quality_score, None
            )
            confidence = self._calculate_enhanced_confidence(
                bandwidth, delay, loss, hotspot_rec, recommendation_prob
            )
            
            conflict_data.append({
                "bandwidthMbps": bandwidth,
                "avgDelayMs": delay,
                "packetLossRate": loss,
                "networkType": network_type,
                "shouldRecommendHotspot": hotspot_rec,
                "recommendationProbability": recommendation_prob,
                "qualityScore": quality_score,
                "confidence": confidence,
                "scenario": "conflict"
            })
        
        return pd.DataFrame(conflict_data)
    
    def save_dataset(self, df: pd.DataFrame, filepath: str):
        """Save generated dataset to CSV file."""
        df.to_csv(filepath, index=False)
        print(f"Dataset saved to {filepath} with {len(df)} samples")


if __name__ == "__main__":
    # 测试增强数据生成器的不同不确定性水平
    print("=== 增强数据生成器测试 ===\n")
    
    # 测试不同的不确定性水平
    for uncertainty in [0.0, 0.5, 1.0]:
        print(f"测试不确定性水平: {uncertainty}")
        generator = DataGenerator(uncertainty_level=uncertainty)
        
        # 生成常规数据集
        dataset = generator.generate_dataset(n_samples=200, include_mixed_scenarios=True)
        
        # 生成冲突样本
        conflict_dataset = generator.generate_conflict_samples(n_samples=50)
        
        # 合并数据集
        combined_dataset = pd.concat([dataset, conflict_dataset], ignore_index=True)
        
        print(f"总样本数: {len(combined_dataset)}")
        print(f"热点推荐分布: {combined_dataset['shouldRecommendHotspot'].value_counts()}")
        print(f"场景分布: {combined_dataset['scenario'].value_counts()}")
        print(f"网络类型分布: {combined_dataset['networkType'].value_counts()}")
        
        # 显示统计信息
        print(f"平均推荐概率: {combined_dataset['recommendationProbability'].mean():.3f}")
        print(f"平均置信度: {combined_dataset['confidence'].mean():.3f}")
        print(f"平均质量分数: {combined_dataset['qualityScore'].mean():.3f}")
        
        # 显示模糊案例（概率接近0.5）
        ambiguous_cases = combined_dataset[
            (combined_dataset['recommendationProbability'] > 0.4) & 
            (combined_dataset['recommendationProbability'] < 0.6)
        ]
        print(f"模糊案例数（概率0.4-0.6）: {len(ambiguous_cases)}")
        
        print("-" * 50)
    
    # 测试特定场景
    print("\n=== 测试特定场景 ===")
    generator = DataGenerator(uncertainty_level=0.7)
    
    scenarios_to_test = ["strong_network", "weak_network", "critical_network", "mixed_network"]
    for scenario in scenarios_to_test:
        print(f"\n测试 {scenario}:")
        sample = generator.generate_sample(scenario)
        print(f"  带宽: {sample['bandwidthMbps']:.1f} Mbps")
        print(f"  延迟: {sample['avgDelayMs']:.1f} ms") 
        print(f"  丢包率: {sample['packetLossRate']:.1f}%")
        print(f"  网络类型: {sample['networkType']}")
        print(f"  热点推荐: {sample['shouldRecommendHotspot']}")
        print(f"  推荐概率: {sample['recommendationProbability']:.3f}")
        print(f"  质量分数: {sample['qualityScore']:.3f}")
        print(f"  置信度: {sample['confidence']:.3f}")
