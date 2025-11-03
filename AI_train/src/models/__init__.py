"""
AI Models for Network Quality Analysis

This package contains neural network models and training utilities
for network quality prediction and hotspot recommendation.
"""

from .network_model import NetworkQualityModel
from .trainer import ModelTrainer

__all__ = [
    "NetworkQualityModel",
    "ModelTrainer",
]
