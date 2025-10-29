"""
Data Generator for Network Quality Analysis

This module generates synthetic network data for training AI models.
It simulates different network scenarios including strong, weak, and critical networks.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple
import random


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
    
    def __init__(self, seed: int = 42):
        """Initialize data generator with random seed."""
        self.seed = seed
        np.random.seed(seed)
        random.seed(seed)
        
        # Define network scenarios
        self.scenarios = {
            "strong_network": {
                "bandwidth_range": (50.0, 100.0),  # Mbps
                "delay_range": (10.0, 50.0),       # ms
                "loss_range": (0.0, 1.0),          # %
                "hotspot_recommendation": 0,       # Don't recommend hotspot
                "quality_range": (0.8, 1.0)        # High quality
            },
            "weak_network": {
                "bandwidth_range": (1.0, 10.0),    # Mbps
                "delay_range": (100.0, 500.0),     # ms
                "loss_range": (5.0, 20.0),         # %
                "hotspot_recommendation": 1,       # Recommend hotspot
                "quality_range": (0.0, 0.3)        # Low quality
            },
            "critical_network": {
                "bandwidth_range": (10.0, 30.0),   # Mbps
                "delay_range": (50.0, 150.0),      # ms
                "loss_range": (1.0, 8.0),          # %
                "hotspot_recommendation": 1,       # Recommend hotspot
                "quality_range": (0.3, 0.6)        # Medium quality
            }
        }
    
    def generate_sample(self, scenario: str) -> Dict[str, float]:
        """Generate a single data sample for given scenario."""
        if scenario not in self.scenarios:
            raise ValueError(f"Unknown scenario: {scenario}")
        
        params = self.scenarios[scenario]
        
        # Generate features with some noise
        bandwidth = np.random.uniform(*params["bandwidth_range"])
        delay = np.random.uniform(*params["delay_range"])
        loss = np.random.uniform(*params["loss_range"])
        
        # Add realistic noise
        bandwidth += np.random.normal(0, bandwidth * 0.1)
        delay += np.random.normal(0, delay * 0.15)
        loss += np.random.normal(0, loss * 0.2)
        
        # Ensure realistic bounds
        bandwidth = max(0.1, bandwidth)
        delay = max(1.0, delay)
        loss = max(0.0, min(100.0, loss))
        
        # Generate quality score based on features
        quality_score = self._calculate_quality_score(bandwidth, delay, loss)
        
        # Determine hotspot recommendation (with some uncertainty)
        hotspot_rec = params["hotspot_recommendation"]
        confidence = self._calculate_confidence(bandwidth, delay, loss, hotspot_rec)
        
        return {
            "bandwidthMbps": bandwidth,
            "avgDelayMs": delay,
            "packetLossRate": loss,
            "shouldRecommendHotspot": hotspot_rec,
            "qualityScore": quality_score,
            "confidence": confidence
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
                        scenario_weights: Dict[str, float] = None) -> pd.DataFrame:
        """
        Generate a complete dataset with balanced scenarios.
        
        Args:
            n_samples: Total number of samples to generate
            scenario_weights: Dictionary with scenario names and their weights
            
        Returns:
            DataFrame with generated data
        """
        if scenario_weights is None:
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
                sample["scenario"] = scenario
                data.append(sample)
        
        # Shuffle data
        random.shuffle(data)
        
        return pd.DataFrame(data)
    
    def save_dataset(self, df: pd.DataFrame, filepath: str):
        """Save generated dataset to CSV file."""
        df.to_csv(filepath, index=False)
        print(f"Dataset saved to {filepath} with {len(df)} samples")


if __name__ == "__main__":
    # Example usage
    generator = DataGenerator()
    dataset = generator.generate_dataset(n_samples=100)
    print("Generated dataset sample:")
    print(dataset.head())
    print(f"\nDataset shape: {dataset.shape}")
    print(f"Hotspot recommendations: {dataset['shouldRecommendHotspot'].value_counts()}")
