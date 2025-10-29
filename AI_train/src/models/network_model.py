"""
Neural Network Model for Network Quality Analysis

This module defines the neural network architecture for predicting
network quality and hotspot recommendations.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import Tuple, Dict, Optional
import numpy as np


class NetworkQualityModel(nn.Module):
    """
    Neural network model for network quality analysis and hotspot recommendation.
    
    Input features (3):
    - bandwidthMbps: Network bandwidth in Mbps
    - avgDelayMs: Average round-trip delay in milliseconds
    - packetLossRate: Packet loss rate in percentage
    
    Outputs (3):
    - hotspot_probability: Probability of recommending hotspot (0.0-1.0)
    - quality_score: Predicted network quality score (0.0-1.0)
    - confidence: Model confidence in prediction (0.0-1.0)
    """
    
    def __init__(self, 
                 input_size: int = 3,
                 hidden_sizes: Tuple[int, ...] = (64, 32, 16),
                 dropout_rate: float = 0.2,
                 use_batch_norm: bool = True):
        """
        Initialize the network quality model.
        
        Args:
            input_size: Number of input features
            hidden_sizes: Tuple of hidden layer sizes
            dropout_rate: Dropout rate for regularization
            use_batch_norm: Whether to use batch normalization
        """
        super(NetworkQualityModel, self).__init__()
        
        self.input_size = input_size
        self.hidden_sizes = hidden_sizes
        self.dropout_rate = dropout_rate
        self.use_batch_norm = use_batch_norm
        
        # Input layer
        self.input_layer = nn.Linear(input_size, hidden_sizes[0])
        
        # Hidden layers
        self.hidden_layers = nn.ModuleList()
        self.batch_norms = nn.ModuleList() if use_batch_norm else None
        
        for i in range(len(hidden_sizes) - 1):
            self.hidden_layers.append(
                nn.Linear(hidden_sizes[i], hidden_sizes[i + 1])
            )
            if use_batch_norm:
                self.batch_norms.append(nn.BatchNorm1d(hidden_sizes[i + 1]))
        
        # Output layer - 3 outputs: hotspot probability, quality score, confidence
        self.output_layer = nn.Linear(hidden_sizes[-1], 3)
        
        # Dropout for regularization
        self.dropout = nn.Dropout(dropout_rate)
        
        # Initialize weights
        self._initialize_weights()
    
    def _initialize_weights(self):
        """Initialize model weights using Xavier initialization."""
        for module in self.modules():
            if isinstance(module, nn.Linear):
                nn.init.xavier_uniform_(module.weight)
                if module.bias is not None:
                    nn.init.constant_(module.bias, 0)
    
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass through the network.
        
        Args:
            x: Input tensor of shape (batch_size, 3)
            
        Returns:
            Output tensor of shape (batch_size, 3) containing:
            [hotspot_probability, quality_score, confidence]
        """
        # Input layer
        x = F.relu(self.input_layer(x))
        x = self.dropout(x)
        
        # Hidden layers
        for i, layer in enumerate(self.hidden_layers):
            x = F.relu(layer(x))
            if self.use_batch_norm and self.batch_norms:
                x = self.batch_norms[i](x)
            x = self.dropout(x)
        
        # Output layer with appropriate activations
        outputs = self.output_layer(x)
        
        # Apply different activations to different outputs
        hotspot_prob = torch.sigmoid(outputs[:, 0:1])  # Binary classification
        quality_score = torch.sigmoid(outputs[:, 1:2])  # Regression 0-1
        confidence = torch.sigmoid(outputs[:, 2:3])     # Confidence 0-1
        
        # Combine outputs
        result = torch.cat([hotspot_prob, quality_score, confidence], dim=1)
        
        return result
    
    def predict(self, 
                x: np.ndarray, 
                device: str = 'cpu',
                threshold: float = 0.5) -> Dict[str, np.ndarray]:
        """
        Make predictions on new data.
        
        Args:
            x: Input features as numpy array
            device: Device to run inference on
            threshold: Decision threshold for hotspot recommendation
            
        Returns:
            Dictionary with predictions
        """
        self.eval()
        
        if isinstance(x, np.ndarray):
            x = torch.FloatTensor(x)
        
        if len(x.shape) == 1:
            x = x.unsqueeze(0)
        
        x = x.to(device)
        
        with torch.no_grad():
            outputs = self.forward(x)
            
            hotspot_probs = outputs[:, 0].cpu().numpy()
            quality_scores = outputs[:, 1].cpu().numpy()
            confidences = outputs[:, 2].cpu().numpy()
            
            # Apply threshold to get binary recommendations
            hotspot_recommendations = (hotspot_probs >= threshold).astype(int)
        
        return {
            'hotspot_probability': hotspot_probs,
            'hotspot_recommendation': hotspot_recommendations,
            'quality_score': quality_scores,
            'confidence': confidences
        }
    
    def get_feature_importance(self, 
                              x: torch.Tensor,
                              method: str = 'gradient') -> np.ndarray:
        """
        Estimate feature importance using gradient-based methods.
        
        Args:
            x: Input tensor
            method: Method for importance calculation ('gradient' or 'permutation')
            
        Returns:
            Array of feature importance scores
        """
        if method == 'gradient':
            return self._gradient_importance(x)
        elif method == 'permutation':
            return self._permutation_importance(x)
        else:
            raise ValueError(f"Unknown importance method: {method}")
    
    def _gradient_importance(self, x: torch.Tensor) -> np.ndarray:
        """Calculate feature importance using gradients."""
        x.requires_grad_(True)
        
        # Forward pass
        outputs = self.forward(x)
        hotspot_probs = outputs[:, 0]
        
        # Backward pass for hotspot probability
        hotspot_probs.sum().backward()
        
        # Importance is absolute value of gradients
        importance = torch.abs(x.grad).mean(dim=0).cpu().numpy()
        
        return importance
    
    def _permutation_importance(self, x: torch.Tensor, n_permutations: int = 10) -> np.ndarray:
        """Calculate feature importance using permutation method."""
        baseline_output = self.forward(x).detach()
        baseline_score = baseline_output[:, 0].mean().item()
        
        importance_scores = np.zeros(x.shape[1])
        
        for feature_idx in range(x.shape[1]):
            permutation_scores = []
            
            for _ in range(n_permutations):
                # Permute the feature
                x_permuted = x.clone()
                perm_indices = torch.randperm(x.shape[0])
                x_permuted[:, feature_idx] = x_permuted[perm_indices, feature_idx]
                
                # Get prediction with permuted feature
                perm_output = self.forward(x_permuted).detach()
                perm_score = perm_output[:, 0].mean().item()
                
                permutation_scores.append(perm_score)
            
            # Importance is the drop in performance
            avg_perm_score = np.mean(permutation_scores)
            importance_scores[feature_idx] = baseline_score - avg_perm_score
        
        return importance_scores
    
    def save_model(self, filepath: str):
        """Save model to file."""
        torch.save({
            'model_state_dict': self.state_dict(),
            'model_config': {
                'input_size': self.input_size,
                'hidden_sizes': self.hidden_sizes,
                'dropout_rate': self.dropout_rate,
                'use_batch_norm': self.use_batch_norm
            }
        }, filepath)
    
    @classmethod
    def load_model(cls, filepath: str, device: str = 'cpu'):
        """Load model from file."""
        checkpoint = torch.load(filepath, map_location=device)
        model_config = checkpoint['model_config']
        
        model = cls(
            input_size=model_config['input_size'],
            hidden_sizes=model_config['hidden_sizes'],
            dropout_rate=model_config['dropout_rate'],
            use_batch_norm=model_config['use_batch_norm']
        )
        
        model.load_state_dict(checkpoint['model_state_dict'])
        model.to(device)
        
        return model


# Example usage and testing
if __name__ == "__main__":
    # Test model creation
    model = NetworkQualityModel()
    print(f"Model created with {sum(p.numel() for p in model.parameters())} parameters")
    
    # Test forward pass
    sample_input = torch.randn(5, 3)  # Batch of 5 samples, 3 features
    output = model(sample_input)
    print(f"Input shape: {sample_input.shape}")
    print(f"Output shape: {output.shape}")
    print(f"Output range: {output.min().item():.3f} to {output.max().item():.3f}")
    
    # Test prediction
    sample_np = np.random.randn(3, 3)
    predictions = model.predict(sample_np)
    print(f"\nPredictions keys: {list(predictions.keys())}")
    print(f"Hotspot recommendations: {predictions['hotspot_recommendation']}")
