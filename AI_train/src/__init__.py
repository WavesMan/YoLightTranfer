"""
AI Network Quality Analysis Package

This package provides AI models for network quality analysis
and hotspot recommendation based on network metrics.
"""

__version__ = "0.1.0"
__author__ = "YoLightTransfer Team"

from .models.network_model import NetworkQualityModel
from .data.collector import NetworkDataCollector
from .data.generator import DataGenerator
from .models.trainer import ModelTrainer

__all__ = [
    "NetworkQualityModel",
    "NetworkDataCollector", 
    "DataGenerator",
    "ModelTrainer",
]
