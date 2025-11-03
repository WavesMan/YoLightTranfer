#!/usr/bin/env python3
"""
Test Script for AI Network Quality Pipeline

This script tests the basic functionality of the AI network quality pipeline
without running full training. It verifies that all components work correctly.
"""

import os
import sys
import numpy as np

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.models.network_model import NetworkQualityModel
from src.utils.config import Config
from src.utils.metrics import ModelMetrics


def test_data_generation():
    """Test data generation functionality."""
    print("🧪 Testing Data Generation...")
    
    generator = DataGenerator(seed=42)
    
    # Test single sample generation
    sample = generator.generate_sample("strong_network")
    assert 'bandwidthMbps' in sample
    assert 'avgDelayMs' in sample
    assert 'packetLossRate' in sample
    assert 'shouldRecommendHotspot' in sample
    print("✅ Single sample generation: PASS")
    
    # Test dataset generation
    dataset = generator.generate_dataset(n_samples=100)
    assert len(dataset) == 100
    assert all(col in dataset.columns for col in [
        'bandwidthMbps', 'avgDelayMs', 'packetLossRate',
        'shouldRecommendHotspot', 'qualityScore', 'confidence', 'scenario'
    ])
    print("✅ Dataset generation: PASS")
    
    return dataset


def test_data_preprocessing(dataset):
    """Test data preprocessing functionality."""
    print("\n🧪 Testing Data Preprocessing...")
    
    preprocessor = DataPreprocessor()
    
    # Test preprocessing
    X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(
        dataset, test_size=0.2, validation_size=0.1
    )
    
    assert X_train.shape[0] > 0
    assert X_val.shape[0] > 0
    assert X_test.shape[0] > 0
    assert X_train.shape[1] == 3  # 3 features
    assert y_train.shape[1] == 3  # 3 outputs
    print("✅ Data preprocessing: PASS")
    
    return X_train, X_val, X_test, y_train, y_val, y_test


def test_model_creation():
    """Test model creation and basic functionality."""
    print("\n🧪 Testing Model Creation...")
    
    model = NetworkQualityModel()
    
    # Test model parameters
    total_params = sum(p.numel() for p in model.parameters())
    assert total_params > 0
    print(f"✅ Model created with {total_params} parameters: PASS")
    
    # Test forward pass
    sample_input = np.random.randn(5, 3).astype(np.float32)
    output = model.predict(sample_input)
    
    assert 'hotspot_probability' in output
    assert 'quality_score' in output
    assert 'confidence' in output
    assert len(output['hotspot_probability']) == 5
    print("✅ Model forward pass: PASS")
    
    return model


def test_metrics_calculation():
    """Test metrics calculation functionality."""
    print("\n🧪 Testing Metrics Calculation...")
    
    metrics_calc = ModelMetrics()
    
    # Generate sample data for testing
    np.random.seed(42)
    n_samples = 100
    
    y_true_hotspot = np.random.randint(0, 2, n_samples)
    y_prob_hotspot = np.random.uniform(0, 1, n_samples)
    y_pred_hotspot = (y_prob_hotspot >= 0.5).astype(int)
    
    y_true_quality = np.random.uniform(0, 1, n_samples)
    y_pred_quality = y_true_quality + np.random.normal(0, 0.1, n_samples)
    
    y_true_confidence = np.random.uniform(0.3, 1.0, n_samples)
    y_pred_confidence = y_true_confidence + np.random.normal(0, 0.05, n_samples)
    
    # Test comprehensive metrics
    all_metrics = metrics_calc.calculate_comprehensive_metrics(
        y_true_hotspot, y_pred_hotspot, y_prob_hotspot,
        y_true_quality, y_pred_quality,
        y_true_confidence, y_pred_confidence
    )
    
    assert 'hotspot_recommendation' in all_metrics
    assert 'quality_score' in all_metrics
    assert 'confidence' in all_metrics
    assert 'overall' in all_metrics
    print("✅ Comprehensive metrics calculation: PASS")
    
    return all_metrics


def test_configuration():
    """Test configuration management."""
    print("\n🧪 Testing Configuration Management...")
    
    config = Config()
    
    # Test default configuration
    assert config.model.input_size == 3
    assert config.training.learning_rate == 0.001
    assert config.data.dataset_size == 10000
    print("✅ Default configuration: PASS")
    
    # Test configuration updates
    config.update(learning_rate=0.0005, batch_size=64)
    assert config.training.learning_rate == 0.0005
    assert config.training.batch_size == 64
    print("✅ Configuration updates: PASS")
    
    # Test configuration saving/loading
    config.save("test_config.json")
    assert os.path.exists("test_config.json")
    
    new_config = Config("test_config.json")
    assert new_config.training.learning_rate == 0.0005
    print("✅ Configuration save/load: PASS")
    
    # Cleanup
    if os.path.exists("test_config.json"):
        os.remove("test_config.json")
    
    return config


def main():
    """Run all tests."""
    print("🚀 Starting AI Network Quality Pipeline Tests")
    print("=" * 60)
    
    try:
        # Test configuration
        config = test_configuration()
        
        # Test data generation
        dataset = test_data_generation()
        
        # Test data preprocessing
        X_train, X_val, X_test, y_train, y_val, y_test = test_data_preprocessing(dataset)
        
        # Test model creation
        model = test_model_creation()
        
        # Test metrics calculation
        metrics = test_metrics_calculation()
        
        print("\n" + "=" * 60)
        print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
        print("=" * 60)
        
        # Print summary
        print(f"📊 Test Summary:")
        print(f"  - Configuration: ✅ Working")
        print(f"  - Data Generation: ✅ {len(dataset)} samples")
        print(f"  - Data Preprocessing: ✅ {X_train.shape[0]} training samples")
        print(f"  - Model: ✅ {sum(p.numel() for p in model.parameters())} parameters")
        print(f"  - Metrics: ✅ Comprehensive evaluation")
        
        print(f"\n✨ The AI Network Quality pipeline is ready for training!")
        print(f"💡 Run 'python scripts/train_model.py' to start training.")
        
        return 0
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
