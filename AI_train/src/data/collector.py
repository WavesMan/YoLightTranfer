"""
Network Data Collector

This module collects real network quality data from various sources
and prepares it for model training.
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Optional
import time
import json
import os


class NetworkDataCollector:
    """
    Collects and manages network quality data for AI model training.
    
    This class handles:
    - Real-time network data collection
    - Data storage and management
    - Data preprocessing and cleaning
    - Integration with existing network monitoring systems
    """
    
    def __init__(self, data_dir: str = "data/raw"):
        """Initialize data collector with storage directory."""
        self.data_dir = data_dir
        os.makedirs(data_dir, exist_ok=True)
        
        # Data schema
        self.columns = [
            "timestamp",
            "bandwidthMbps", 
            "avgDelayMs",
            "packetLossRate",
            "networkType",
            "location",
            "deviceInfo",
            "userFeedback",  # Optional: user acceptance/rejection of recommendations
            "shouldRecommendHotspot",  # Ground truth label
            "qualityScore",
            "confidence"
        ]
    
    def collect_sample(self, network_data: Dict) -> Dict:
        """
        Collect a single network data sample.
        
        Args:
            network_data: Dictionary containing network metrics
            
        Returns:
            Complete data sample with timestamp and metadata
        """
        sample = {
            "timestamp": time.time(),
            "bandwidthMbps": network_data.get("bandwidthMbps", 0.0),
            "avgDelayMs": network_data.get("avgDelayMs", 0.0),
            "packetLossRate": network_data.get("packetLossRate", 0.0),
            "networkType": network_data.get("networkType", "unknown"),
            "location": network_data.get("location", "unknown"),
            "deviceInfo": network_data.get("deviceInfo", "unknown"),
            "userFeedback": network_data.get("userFeedback", None),
        }
        
        # Generate labels based on network conditions
        sample.update(self._generate_labels(sample))
        
        return sample
    
    def _generate_labels(self, sample: Dict) -> Dict:
        """Generate training labels based on network conditions."""
        bandwidth = sample["bandwidthMbps"]
        delay = sample["avgDelayMs"]
        loss = sample["packetLossRate"]
        
        # Rule-based labeling for training data
        should_recommend = 0  # Default: don't recommend
        
        # Recommend hotspot in weak network conditions
        if (bandwidth < 10.0 or 
            delay > 200.0 or 
            loss > 5.0):
            should_recommend = 1
        
        # Calculate quality score
        quality_score = self._calculate_quality_score(bandwidth, delay, loss)
        
        # Calculate confidence based on feature clarity
        confidence = self._calculate_confidence(bandwidth, delay, loss, should_recommend)
        
        return {
            "shouldRecommendHotspot": should_recommend,
            "qualityScore": quality_score,
            "confidence": confidence
        }
    
    def _calculate_quality_score(self, bandwidth: float, delay: float, loss: float) -> float:
        """Calculate network quality score (0.0-1.0)."""
        # Normalize features
        bandwidth_score = min(bandwidth / 100.0, 1.0)
        delay_score = max(0.0, 1.0 - (delay / 500.0))
        loss_score = max(0.0, 1.0 - (loss / 20.0))
        
        # Weighted combination
        quality = (0.5 * bandwidth_score + 0.3 * delay_score + 0.2 * loss_score)
        return min(max(quality, 0.0), 1.0)
    
    def _calculate_confidence(self, bandwidth: float, delay: float, loss: float, 
                            should_recommend: int) -> float:
        """Calculate confidence score based on feature clarity."""
        if should_recommend == 1:  # Weak network
            confidence = (1.0 - min(bandwidth / 30.0, 1.0)) * 0.6 + \
                        (min(delay / 200.0, 1.0)) * 0.3 + \
                        (min(loss / 15.0, 1.0)) * 0.1
        else:  # Strong network
            confidence = (min(bandwidth / 50.0, 1.0)) * 0.6 + \
                        (1.0 - min(delay / 100.0, 1.0)) * 0.3 + \
                        (1.0 - min(loss / 5.0, 1.0)) * 0.1
        
        return min(max(confidence, 0.3), 1.0)
    
    def save_sample(self, sample: Dict, filename: str = None):
        """Save a single data sample to file."""
        if filename is None:
            filename = f"network_data_{int(time.time())}.json"
        
        filepath = os.path.join(self.data_dir, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(sample, f, indent=2, ensure_ascii=False)
    
    def load_samples(self, pattern: str = "*.json") -> pd.DataFrame:
        """Load all data samples matching pattern into DataFrame."""
        import glob
        
        files = glob.glob(os.path.join(self.data_dir, pattern))
        data = []
        
        for file in files:
            try:
                with open(file, 'r', encoding='utf-8') as f:
                    sample = json.load(f)
                    data.append(sample)
            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"Error loading {file}: {e}")
                continue
        
        return pd.DataFrame(data)
    
    def export_training_data(self, output_file: str = "training_data.csv") -> pd.DataFrame:
        """
        Export collected data in training-ready format.
        
        Returns:
            DataFrame with features and labels for training
        """
        df = self.load_samples()
        
        if df.empty:
            print("No data found to export")
            return pd.DataFrame()
        
        # Select relevant columns for training
        training_columns = [
            "bandwidthMbps", "avgDelayMs", "packetLossRate",
            "shouldRecommendHotspot", "qualityScore", "confidence"
        ]
        
        # Filter available columns
        available_columns = [col for col in training_columns if col in df.columns]
        training_df = df[available_columns].copy()
        
        # Save to CSV
        training_df.to_csv(output_file, index=False)
        print(f"Training data exported to {output_file} with {len(training_df)} samples")
        
        return training_df
    
    def get_statistics(self) -> Dict:
        """Get statistics about collected data."""
        df = self.load_samples()
        
        if df.empty:
            return {"total_samples": 0}
        
        stats = {
            "total_samples": len(df),
            "hotspot_recommendations": df.get("shouldRecommendHotspot", pd.Series()).value_counts().to_dict(),
            "avg_bandwidth": df["bandwidthMbps"].mean() if "bandwidthMbps" in df.columns else 0,
            "avg_delay": df["avgDelayMs"].mean() if "avgDelayMs" in df.columns else 0,
            "avg_loss": df["packetLossRate"].mean() if "packetLossRate" in df.columns else 0,
        }
        
        return stats


# Example usage and testing
if __name__ == "__main__":
    collector = NetworkDataCollector()
    
    # Example: Collect a sample network data
    sample_data = {
        "bandwidthMbps": 25.5,
        "avgDelayMs": 85.2,
        "packetLossRate": 2.1,
        "networkType": "WiFi",
        "location": "office",
        "deviceInfo": "Android 12"
    }
    
    sample = collector.collect_sample(sample_data)
    print("Collected sample:")
    print(json.dumps(sample, indent=2))
    
    # Save sample
    collector.save_sample(sample)
    
    # Get statistics
    stats = collector.get_statistics()
    print(f"\nData statistics: {stats}")
