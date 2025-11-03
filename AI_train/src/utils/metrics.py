"""
Model Metrics and Evaluation Utilities

This module provides comprehensive metrics calculation and evaluation
utilities for the network quality analysis model.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report,
    mean_squared_error, mean_absolute_error, r2_score
)
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats


class ModelMetrics:
    """
    Comprehensive metrics calculator for network quality model evaluation.
    
    This class provides:
    - Classification metrics for hotspot recommendation
    - Regression metrics for quality score and confidence
    - Statistical analysis and hypothesis testing
    - Visualization tools for model performance
    """
    
    def __init__(self):
        """Initialize metrics calculator."""
        self.metrics_history = {}
    
    def calculate_classification_metrics(self, 
                                       y_true: np.ndarray, 
                                       y_pred: np.ndarray,
                                       y_prob: np.ndarray,
                                       threshold: float = 0.5) -> Dict[str, float]:
        """
        Calculate classification metrics for hotspot recommendation.
        
        Args:
            y_true: True binary labels
            y_pred: Predicted binary labels
            y_prob: Predicted probabilities
            threshold: Decision threshold for binary classification
            
        Returns:
            Dictionary with classification metrics
        """
        # Ensure binary predictions
        y_pred_binary = (y_prob >= threshold).astype(int)
        
        metrics = {
            'accuracy': accuracy_score(y_true, y_pred_binary),
            'precision': precision_score(y_true, y_pred_binary, zero_division=0),
            'recall': recall_score(y_true, y_pred_binary, zero_division=0),
            'f1_score': f1_score(y_true, y_pred_binary, zero_division=0),
            'auc_roc': roc_auc_score(y_true, y_prob),
            'threshold': threshold
        }
        
        # Additional metrics
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred_binary).ravel()
        metrics.update({
            'true_negative': tn,
            'false_positive': fp,
            'false_negative': fn,
            'true_positive': tp,
            'specificity': tn / (tn + fp) if (tn + fp) > 0 else 0,
            'false_positive_rate': fp / (fp + tn) if (fp + tn) > 0 else 0,
            'false_negative_rate': fn / (fn + tp) if (fn + tp) > 0 else 0
        })
        
        return metrics
    
    def calculate_regression_metrics(self, 
                                   y_true: np.ndarray, 
                                   y_pred: np.ndarray) -> Dict[str, float]:
        """
        Calculate regression metrics for quality score and confidence.
        
        Args:
            y_true: True values
            y_pred: Predicted values
            
        Returns:
            Dictionary with regression metrics
        """
        metrics = {
            'mse': mean_squared_error(y_true, y_pred),
            'rmse': np.sqrt(mean_squared_error(y_true, y_pred)),
            'mae': mean_absolute_error(y_true, y_pred),
            'r2': r2_score(y_true, y_pred),
            'mape': self._mean_absolute_percentage_error(y_true, y_pred),
            'max_error': np.max(np.abs(y_true - y_pred))
        }
        
        # Additional statistical metrics
        residuals = y_true - y_pred
        metrics.update({
            'mean_residual': np.mean(residuals),
            'std_residual': np.std(residuals),
            'residual_skewness': stats.skew(residuals),
            'residual_kurtosis': stats.kurtosis(residuals)
        })
        
        return metrics
    
    def _mean_absolute_percentage_error(self, y_true: np.ndarray, y_pred: np.ndarray) -> float:
        """Calculate Mean Absolute Percentage Error (MAPE)."""
        # Avoid division by zero
        mask = y_true != 0
        if np.sum(mask) == 0:
            return float('inf')
        
        return np.mean(np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])) * 100
    
    def calculate_comprehensive_metrics(self,
                                      y_true_hotspot: np.ndarray,
                                      y_pred_hotspot: np.ndarray,
                                      y_prob_hotspot: np.ndarray,
                                      y_true_quality: np.ndarray,
                                      y_pred_quality: np.ndarray,
                                      y_true_confidence: np.ndarray,
                                      y_pred_confidence: np.ndarray,
                                      threshold: float = 0.5) -> Dict[str, Dict]:
        """
        Calculate comprehensive metrics for all model outputs.
        
        Args:
            y_true_hotspot: True hotspot recommendations
            y_pred_hotspot: Predicted hotspot recommendations
            y_prob_hotspot: Predicted hotspot probabilities
            y_true_quality: True quality scores
            y_pred_quality: Predicted quality scores
            y_true_confidence: True confidence scores
            y_pred_confidence: Predicted confidence scores
            threshold: Decision threshold for hotspot classification
            
        Returns:
            Nested dictionary with all metrics
        """
        metrics = {}
        
        # Hotspot recommendation metrics (classification)
        metrics['hotspot_recommendation'] = self.calculate_classification_metrics(
            y_true_hotspot, y_pred_hotspot, y_prob_hotspot, threshold
        )
        
        # Quality score metrics (regression)
        metrics['quality_score'] = self.calculate_regression_metrics(
            y_true_quality, y_pred_quality
        )
        
        # Confidence metrics (regression)
        metrics['confidence'] = self.calculate_regression_metrics(
            y_true_confidence, y_pred_confidence
        )
        
        # Overall model performance
        metrics['overall'] = self._calculate_overall_metrics(metrics)
        
        return metrics
    
    def _calculate_overall_metrics(self, metrics: Dict) -> Dict[str, float]:
        """Calculate overall model performance metrics."""
        hotspot_metrics = metrics['hotspot_recommendation']
        quality_metrics = metrics['quality_score']
        confidence_metrics = metrics['confidence']
        
        # Weighted combination of metrics
        overall_score = (
            0.6 * hotspot_metrics['f1_score'] +  # Main task weight
            0.3 * (1 - quality_metrics['mae']) +  # Quality prediction weight
            0.1 * (1 - confidence_metrics['mae'])  # Confidence estimation weight
        )
        
        return {
            'overall_score': overall_score,
            'weighted_f1': hotspot_metrics['f1_score'],
            'quality_mae': quality_metrics['mae'],
            'confidence_mae': confidence_metrics['mae']
        }
    
    def calculate_feature_importance(self,
                                   model,
                                   X: np.ndarray,
                                   y: np.ndarray,
                                   method: str = 'permutation',
                                   n_repeats: int = 10) -> Dict[str, float]:
        """
        Calculate feature importance using various methods.
        
        Args:
            model: Trained model
            X: Feature matrix
            y: Target values
            method: Importance calculation method ('permutation', 'gradient')
            n_repeats: Number of repetitions for permutation importance
            
        Returns:
            Dictionary with feature importance scores
        """
        if method == 'permutation':
            return self._permutation_importance(model, X, y, n_repeats)
        elif method == 'gradient':
            return self._gradient_importance(model, X, y)
        else:
            raise ValueError(f"Unknown importance method: {method}")
    
    def _permutation_importance(self, model, X: np.ndarray, y: np.ndarray, n_repeats: int) -> Dict[str, float]:
        """Calculate permutation importance."""
        baseline_score = model.score(X, y) if hasattr(model, 'score') else 0.5
        
        importance_scores = {}
        feature_names = ['bandwidthMbps', 'avgDelayMs', 'packetLossRate']
        
        for i, feature_name in enumerate(feature_names):
            scores = []
            for _ in range(n_repeats):
                X_permuted = X.copy()
                np.random.shuffle(X_permuted[:, i])
                
                if hasattr(model, 'score'):
                    perm_score = model.score(X_permuted, y)
                else:
                    # For custom models, use prediction accuracy
                    y_pred = model.predict(X_permuted)
                    perm_score = accuracy_score(y[:, 0], (y_pred[:, 0] >= 0.5).astype(int))
                
                scores.append(perm_score)
            
            importance_scores[feature_name] = baseline_score - np.mean(scores)
        
        return importance_scores
    
    def _gradient_importance(self, model, X: np.ndarray, y: np.ndarray) -> Dict[str, float]:
        """Calculate gradient-based importance (placeholder for PyTorch models)."""
        # This would be implemented for PyTorch models using gradients
        # For now, return equal importance
        return {
            'bandwidthMbps': 0.33,
            'avgDelayMs': 0.33,
            'packetLossRate': 0.34
        }
    
    def plot_confusion_matrix(self, 
                            y_true: np.ndarray, 
                            y_pred: np.ndarray,
                            title: str = "Confusion Matrix",
                            save_path: Optional[str] = None):
        """Plot confusion matrix."""
        cm = confusion_matrix(y_true, y_pred)
        
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                   xticklabels=['No Hotspot', 'Hotspot'],
                   yticklabels=['No Hotspot', 'Hotspot'])
        plt.title(title)
        plt.xlabel('Predicted')
        plt.ylabel('Actual')
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Confusion matrix saved to {save_path}")
        
        plt.show()
    
    def plot_roc_curve(self, 
                      y_true: np.ndarray, 
                      y_prob: np.ndarray,
                      title: str = "ROC Curve",
                      save_path: Optional[str] = None):
        """Plot ROC curve."""
        from sklearn.metrics import roc_curve
        
        fpr, tpr, thresholds = roc_curve(y_true, y_prob)
        auc_score = roc_auc_score(y_true, y_prob)
        
        plt.figure(figsize=(8, 6))
        plt.plot(fpr, tpr, linewidth=2, label=f'ROC curve (AUC = {auc_score:.3f})')
        plt.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Random classifier')
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title(title)
        plt.legend(loc="lower right")
        plt.grid(True, alpha=0.3)
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"ROC curve saved to {save_path}")
        
        plt.show()
    
    def plot_prediction_distribution(self,
                                   y_true: np.ndarray,
                                   y_pred: np.ndarray,
                                   title: str = "Prediction Distribution",
                                   save_path: Optional[str] = None):
        """Plot distribution of predictions vs true values."""
        plt.figure(figsize=(10, 6))
        
        plt.subplot(1, 2, 1)
        plt.hist(y_true, alpha=0.7, label='True', bins=20)
        plt.hist(y_pred, alpha=0.7, label='Predicted', bins=20)
        plt.xlabel('Value')
        plt.ylabel('Frequency')
        plt.title('Distribution Comparison')
        plt.legend()
        
        plt.subplot(1, 2, 2)
        plt.scatter(y_true, y_pred, alpha=0.6)
        plt.plot([y_true.min(), y_true.max()], [y_true.min(), y_true.max()], 'r--', linewidth=2)
        plt.xlabel('True Values')
        plt.ylabel('Predicted Values')
        plt.title('True vs Predicted')
        
        plt.tight_layout()
        plt.suptitle(title, y=1.02)
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Prediction distribution plot saved to {save_path}")
        
        plt.show()
    
    def generate_report(self, metrics: Dict, report_path: str = 'metrics_report.json'):
        """Generate comprehensive metrics report."""
        report = {
            'timestamp': pd.Timestamp.now().isoformat(),
            'metrics': metrics,
            'summary': {
                'hotspot_f1': metrics['hotspot_recommendation']['f1_score'],
                'quality_mae': metrics['quality_score']['mae'],
                'confidence_mae': metrics['confidence']['mae'],
                'overall_score': metrics['overall']['overall_score']
            }
        }
        
        import json
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"Metrics report saved to {report_path}")
        return report


# Example usage
if __name__ == "__main__":
    # Test metrics calculation with sample data
    metrics_calc = ModelMetrics()
    
    # Generate sample data
    np.random.seed(42)
    n_samples = 1000
    
    y_true_hotspot = np.random.randint(0, 2, n_samples)
    y_prob_hotspot = np.random.uniform(0, 1, n_samples)
    y_pred_hotspot = (y_prob_hotspot >= 0.5).astype(int)
    
    y_true_quality = np.random.uniform(0, 1, n_samples)
    y_pred_quality = y_true_quality + np.random.normal(0, 0.1, n_samples)
    
    y_true_confidence = np.random.uniform(0.3, 1.0, n_samples)
    y_pred_confidence = y_true_confidence + np.random.normal(0, 0.05, n_samples)
    
    # Calculate comprehensive metrics
    all_metrics = metrics_calc.calculate_comprehensive_metrics(
        y_true_hotspot, y_pred_hotspot, y_prob_hotspot,
        y_true_quality, y_pred_quality,
        y_true_confidence, y_pred_confidence
    )
    
    print("Comprehensive Metrics:")
    for task, task_metrics in all_metrics.items():
        print(f"\n{task.upper()}:")
        for metric, value in task_metrics.items():
            print(f"  {metric}: {value:.4f}")
    
    # Generate report
    metrics_calc.generate_report(all_metrics)
    
    print("\nMetrics calculation test completed!")
