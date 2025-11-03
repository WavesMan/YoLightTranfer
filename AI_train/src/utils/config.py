"""
Configuration Management for AI Network Quality Analysis

This module handles configuration management for the entire project,
including model parameters, training settings, and data paths.
"""

import os
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class ModelConfig:
    """Configuration for the neural network model."""
    input_size: int = 3
    hidden_sizes: tuple = (64, 32, 16)
    dropout_rate: float = 0.2
    use_batch_norm: bool = True
    activation: str = "relu"


@dataclass
class TrainingConfig:
    """Configuration for model training."""
    learning_rate: float = 0.001
    weight_decay: float = 1e-4
    batch_size: int = 32
    epochs: int = 100
    early_stopping_patience: int = 10
    validation_split: float = 0.2
    test_split: float = 0.1
    random_seed: int = 42
    optimizer: str = "AdamW"
    scheduler: str = "ReduceLROnPlateau"


@dataclass
class DataConfig:
    """Configuration for data handling."""
    data_dir: str = "data"
    raw_data_dir: str = "data/raw"
    processed_data_dir: str = "data/processed"
    models_dir: str = "models"
    checkpoint_dir: str = "checkpoints"
    dataset_size: int = 10000
    scenario_weights: Dict[str, float] = None
    
    def __post_init__(self):
        if self.scenario_weights is None:
            self.scenario_weights = {
                "strong_network": 0.4,
                "weak_network": 0.3,
                "critical_network": 0.3
            }


@dataclass
class EvaluationConfig:
    """Configuration for model evaluation."""
    test_size: int = 1000
    metrics: tuple = ("accuracy", "precision", "recall", "f1", "auc_roc")
    confidence_threshold: float = 0.5
    save_predictions: bool = True
    plot_results: bool = True


class Config:
    """
    Main configuration class that combines all configuration sections.
    
    This class provides a centralized way to manage all project settings
    and supports loading/saving configurations from/to JSON files.
    """
    
    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize configuration.
        
        Args:
            config_file: Path to JSON configuration file (optional)
        """
        # Initialize default configurations
        self.model = ModelConfig()
        self.training = TrainingConfig()
        self.data = DataConfig()
        self.evaluation = EvaluationConfig()
        
        # Additional settings
        self.project_name: str = "AI Network Quality Analysis"
        self.version: str = "1.0.0"
        self.author: str = "YoLightTransfer Team"
        self.description: str = "AI model for network quality prediction and hotspot recommendation"
        
        # Load configuration from file if provided
        if config_file and os.path.exists(config_file):
            self.load(config_file)
        
        # Create directories
        self._create_directories()
    
    def _create_directories(self):
        """Create necessary directories for the project."""
        directories = [
            self.data.data_dir,
            self.data.raw_data_dir,
            self.data.processed_data_dir,
            self.data.models_dir,
            self.data.checkpoint_dir,
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary."""
        return {
            "project": {
                "name": self.project_name,
                "version": self.version,
                "author": self.author,
                "description": self.description
            },
            "model": asdict(self.model),
            "training": asdict(self.training),
            "data": asdict(self.data),
            "evaluation": asdict(self.evaluation)
        }
    
    def from_dict(self, config_dict: Dict[str, Any]):
        """Load configuration from dictionary."""
        # Project settings
        project_settings = config_dict.get("project", {})
        self.project_name = project_settings.get("name", self.project_name)
        self.version = project_settings.get("version", self.version)
        self.author = project_settings.get("author", self.author)
        self.description = project_settings.get("description", self.description)
        
        # Model configuration
        model_settings = config_dict.get("model", {})
        self.model = ModelConfig(**model_settings)
        
        # Training configuration
        training_settings = config_dict.get("training", {})
        self.training = TrainingConfig(**training_settings)
        
        # Data configuration
        data_settings = config_dict.get("data", {})
        self.data = DataConfig(**data_settings)
        
        # Evaluation configuration
        evaluation_settings = config_dict.get("evaluation", {})
        self.evaluation = EvaluationConfig(**evaluation_settings)
    
    def save(self, filepath: str):
        """Save configuration to JSON file."""
        config_dict = self.to_dict()
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(config_dict, f, indent=2, ensure_ascii=False)
        
        print(f"Configuration saved to {filepath}")
    
    def load(self, filepath: str):
        """Load configuration from JSON file."""
        with open(filepath, 'r', encoding='utf-8') as f:
            config_dict = json.load(f)
        
        self.from_dict(config_dict)
        print(f"Configuration loaded from {filepath}")
    
    def update(self, **kwargs):
        """
        Update configuration settings.
        
        Args:
            **kwargs: Configuration settings to update
        """
        for key, value in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
            elif hasattr(self.model, key):
                setattr(self.model, key, value)
            elif hasattr(self.training, key):
                setattr(self.training, key, value)
            elif hasattr(self.data, key):
                setattr(self.data, key, value)
            elif hasattr(self.evaluation, key):
                setattr(self.evaluation, key, value)
            else:
                print(f"Warning: Unknown configuration key '{key}'")
    
    def print_summary(self):
        """Print configuration summary."""
        print("=" * 60)
        print("CONFIGURATION SUMMARY")
        print("=" * 60)
        print(f"Project: {self.project_name} v{self.version}")
        print(f"Author: {self.author}")
        print(f"Description: {self.description}")
        print()
        
        print("Model Configuration:")
        print(f"  Input Size: {self.model.input_size}")
        print(f"  Hidden Sizes: {self.model.hidden_sizes}")
        print(f"  Dropout Rate: {self.model.dropout_rate}")
        print(f"  Batch Normalization: {self.model.use_batch_norm}")
        print()
        
        print("Training Configuration:")
        print(f"  Learning Rate: {self.training.learning_rate}")
        print(f"  Batch Size: {self.training.batch_size}")
        print(f"  Epochs: {self.training.epochs}")
        print(f"  Early Stopping Patience: {self.training.early_stopping_patience}")
        print()
        
        print("Data Configuration:")
        print(f"  Dataset Size: {self.data.dataset_size}")
        print(f"  Scenario Weights: {self.data.scenario_weights}")
        print(f"  Data Directory: {self.data.data_dir}")
        print()
        
        print("Evaluation Configuration:")
        print(f"  Test Size: {self.evaluation.test_size}")
        print(f"  Confidence Threshold: {self.evaluation.confidence_threshold}")
        print("=" * 60)


# Default configuration instance
default_config = Config()


# Example usage
if __name__ == "__main__":
    # Create and display default configuration
    config = Config()
    config.print_summary()
    
    # Save configuration to file
    config.save("default_config.json")
    
    # Load configuration from file
    new_config = Config("default_config.json")
    new_config.print_summary()
    
    # Update configuration
    new_config.update(
        learning_rate=0.0005,
        batch_size=64,
        dataset_size=5000
    )
    new_config.print_summary()
