"""
Model Trainer for Network Quality Analysis

This module handles the training, validation, and evaluation of the
network quality prediction model.
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
import time
import json
import os
from tqdm import tqdm
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.metrics import roc_auc_score, confusion_matrix, classification_report

from .network_model import NetworkQualityModel


class ModelTrainer:
    """
    Handles training, validation, and evaluation of the network quality model.
    
    This class provides:
    - Training loop with progress tracking
    - Validation and testing
    - Model checkpointing
    - Performance metrics calculation
    - Visualization tools
    - FP16 mixed precision training for RTX 4070 optimization
    """
    
    def __init__(self, 
                 model: NetworkQualityModel,
                 device: str = 'cuda' if torch.cuda.is_available() else 'cpu',
                 use_fp16: bool = True):
        """
        Initialize the model trainer.
        
        Args:
            model: NetworkQualityModel instance
            device: Device to train on ('cuda' or 'cpu')
            use_fp16: Whether to use FP16 mixed precision training (recommended for RTX 4070)
        """
        self.model = model
        self.device = device
        self.use_fp16 = use_fp16 and device == 'cuda'
        self.model.to(device)
        
        # FP16 mixed precision setup
        if self.use_fp16:
            self.scaler = torch.cuda.amp.GradScaler()
            print("[OK] FP16 Mixed Precision Training Enabled")
        
        # Training history
        self.history = {
            'train_loss': [],
            'val_loss': [],
            'train_accuracy': [],
            'val_accuracy': [],
            'train_f1': [],
            'val_f1': [],
            'learning_rates': []
        }
        
        # Best model tracking
        self.best_val_loss = float('inf')
        self.best_model_state = None
        
        print(f"Training on device: {device}")
        if device == 'cuda':
            print(f"GPU: {torch.cuda.get_device_name()}")
            print(f"GPU Memory: {torch.cuda.get_device_properties(device).total_memory / 1024**3:.1f} GB")
    
    def setup_training(self,
                      learning_rate: float = 0.001,
                      weight_decay: float = 1e-4,
                      optimizer_class: type = optim.AdamW):
        """
        Setup optimizer and loss functions for training.
        
        Args:
            learning_rate: Learning rate for optimizer
            weight_decay: Weight decay for regularization
            optimizer_class: Optimizer class (AdamW, Adam, SGD)
        """
        # Combined loss function
        self.criterion = self._create_loss_function()
        
        # Optimizer
        self.optimizer = optimizer_class(
            self.model.parameters(),
            lr=learning_rate,
            weight_decay=weight_decay
        )
        
        # Learning rate scheduler
        self.scheduler = optim.lr_scheduler.ReduceLROnPlateau(
            self.optimizer, 
            mode='min', 
            factor=0.5, 
            patience=5
        )
    
    def _create_loss_function(self) -> nn.Module:
        """Create combined loss function for multi-output model."""
        class CombinedLoss(nn.Module):
            def __init__(self):
                super(CombinedLoss, self).__init__()
                self.bce_loss = nn.BCEWithLogitsLoss()  # For hotspot probability (logits)
                self.mse_loss = nn.MSELoss()  # For quality score and confidence
            
            def forward(self, outputs, targets):
                # Split outputs and targets
                hotspot_out = outputs[:, 0]
                quality_out = outputs[:, 1]
                confidence_out = outputs[:, 2]
                
                hotspot_target = targets[:, 0]
                quality_target = targets[:, 1]
                confidence_target = targets[:, 2]
                
                # Calculate individual losses
                hotspot_loss = self.bce_loss(hotspot_out, hotspot_target)
                quality_loss = self.mse_loss(quality_out, quality_target)
                confidence_loss = self.mse_loss(confidence_out, confidence_target)
                
                # Weighted combination
                total_loss = (
                    0.6 * hotspot_loss +  # Main task: hotspot recommendation
                    0.3 * quality_loss +  # Secondary: quality prediction
                    0.1 * confidence_loss # Tertiary: confidence estimation
                )
                
                return total_loss
        
        return CombinedLoss()
    
    def create_dataloaders(self,
                          X_train: np.ndarray,
                          X_val: np.ndarray,
                          X_test: np.ndarray,
                          y_train: np.ndarray,
                          y_val: np.ndarray,
                          y_test: np.ndarray,
                          batch_size: int = 32,
                          shuffle: bool = True) -> Tuple[DataLoader, DataLoader, DataLoader]:
        """
        Create PyTorch DataLoaders for training, validation, and testing.
        
        Args:
            X_train, X_val, X_test: Feature arrays
            y_train, y_val, y_test: Label arrays
            batch_size: Batch size for training
            shuffle: Whether to shuffle training data
            
        Returns:
            Tuple of (train_loader, val_loader, test_loader)
        """
        # Convert to PyTorch tensors
        train_dataset = TensorDataset(
            torch.FloatTensor(X_train),
            torch.FloatTensor(y_train)
        )
        val_dataset = TensorDataset(
            torch.FloatTensor(X_val),
            torch.FloatTensor(y_val)
        )
        test_dataset = TensorDataset(
            torch.FloatTensor(X_test),
            torch.FloatTensor(y_test)
        )
        
        # Create DataLoaders
        train_loader = DataLoader(
            train_dataset, 
            batch_size=batch_size, 
            shuffle=shuffle,
            num_workers=0  # Set to 0 for Windows compatibility
        )
        val_loader = DataLoader(
            val_dataset, 
            batch_size=batch_size, 
            shuffle=False,
            num_workers=0
        )
        test_loader = DataLoader(
            test_dataset, 
            batch_size=batch_size, 
            shuffle=False,
            num_workers=0
        )
        
        return train_loader, val_loader, test_loader
    
    def train_epoch(self, train_loader: DataLoader) -> Dict[str, float]:
        """
        Train for one epoch with optional FP16 mixed precision.
        
        Args:
            train_loader: Training DataLoader
            
        Returns:
            Dictionary with training metrics
        """
        self.model.train()
        total_loss = 0
        all_predictions = []
        all_targets = []
        
        progress_bar = tqdm(train_loader, desc="Training")
        
        for batch_idx, (data, target) in enumerate(progress_bar):
            data, target = data.to(self.device), target.to(self.device)
            
            # Forward pass with FP16 mixed precision if enabled
            self.optimizer.zero_grad()
            
            if self.use_fp16:
                # Use autocast for FP16 training
                with torch.cuda.amp.autocast():
                    output = self.model(data)
                    loss = self.criterion(output, target)
                
                # Backward pass with gradient scaling
                self.scaler.scale(loss).backward()
                self.scaler.step(self.optimizer)
                self.scaler.update()
            else:
                # Standard FP32 training
                output = self.model(data)
                loss = self.criterion(output, target)
                
                # Backward pass
                loss.backward()
                self.optimizer.step()
            
            # Accumulate metrics
            total_loss += loss.item()
            
            # Store predictions and targets for metrics
            all_predictions.extend(output[:, 0].detach().cpu().numpy())
            all_targets.extend(target[:, 0].detach().cpu().numpy())
            
            # Update progress bar
            progress_bar.set_postfix({
                'loss': f'{loss.item():.4f}',
                'avg_loss': f'{total_loss/(batch_idx+1):.4f}',
                'fp16': '[OK]' if self.use_fp16 else '[OFF]'
            })
        
        # Calculate metrics
        predictions_binary = (np.array(all_predictions) >= 0.5).astype(int)
        accuracy = accuracy_score(all_targets, predictions_binary)
        f1 = f1_score(all_targets, predictions_binary)
        
        return {
            'loss': total_loss / len(train_loader),
            'accuracy': accuracy,
            'f1_score': f1
        }
    
    def validate_epoch(self, val_loader: DataLoader) -> Dict[str, float]:
        """
        Validate for one epoch.
        
        Args:
            val_loader: Validation DataLoader
            
        Returns:
            Dictionary with validation metrics
        """
        self.model.eval()
        total_loss = 0
        all_predictions = []
        all_targets = []
        
        with torch.no_grad():
            for data, target in val_loader:
                data, target = data.to(self.device), target.to(self.device)
                output = self.model(data)
                loss = self.criterion(output, target)
                
                total_loss += loss.item()
                all_predictions.extend(output[:, 0].detach().cpu().numpy())
                all_targets.extend(target[:, 0].detach().cpu().numpy())
        
        # Calculate metrics
        predictions_binary = (np.array(all_predictions) >= 0.5).astype(int)
        accuracy = accuracy_score(all_targets, predictions_binary)
        f1 = f1_score(all_targets, predictions_binary)
        
        return {
            'loss': total_loss / len(val_loader),
            'accuracy': accuracy,
            'f1_score': f1
        }
    
    def train(self,
              train_loader: DataLoader,
              val_loader: DataLoader,
              epochs: int = 100,
              early_stopping_patience: int = 10,
              checkpoint_dir: str = 'checkpoints') -> Dict[str, List]:
        """
        Train the model with early stopping and checkpointing.
        
        Args:
            train_loader: Training DataLoader
            val_loader: Validation DataLoader
            epochs: Maximum number of epochs
            early_stopping_patience: Patience for early stopping
            checkpoint_dir: Directory to save checkpoints
            
        Returns:
            Training history
        """
        os.makedirs(checkpoint_dir, exist_ok=True)
        
        no_improvement_count = 0
        best_epoch = 0
        
        print(f"Starting training for {epochs} epochs...")
        
        for epoch in range(epochs):
            print(f"\nEpoch {epoch + 1}/{epochs}")
            print("-" * 50)
            
            # Training phase
            train_metrics = self.train_epoch(train_loader)
            
            # Validation phase
            val_metrics = self.validate_epoch(val_loader)
            
            # Update learning rate
            current_lr = self.optimizer.param_groups[0]['lr']
            self.scheduler.step(val_metrics['loss'])
            
            # Store history
            self.history['train_loss'].append(train_metrics['loss'])
            self.history['val_loss'].append(val_metrics['loss'])
            self.history['train_accuracy'].append(train_metrics['accuracy'])
            self.history['val_accuracy'].append(val_metrics['accuracy'])
            self.history['train_f1'].append(train_metrics['f1_score'])
            self.history['val_f1'].append(val_metrics['f1_score'])
            self.history['learning_rates'].append(current_lr)
            
            # Print metrics
            print(f"Train Loss: {train_metrics['loss']:.4f}, "
                  f"Train Acc: {train_metrics['accuracy']:.4f}, "
                  f"Train F1: {train_metrics['f1_score']:.4f}")
            print(f"Val Loss: {val_metrics['loss']:.4f}, "
                  f"Val Acc: {val_metrics['accuracy']:.4f}, "
                  f"Val F1: {val_metrics['f1_score']:.4f}")
            print(f"Learning Rate: {current_lr:.6f}")
            
            # Check for improvement
            if val_metrics['loss'] < self.best_val_loss:
                self.best_val_loss = val_metrics['loss']
                self.best_model_state = self.model.state_dict().copy()
                best_epoch = epoch + 1
                no_improvement_count = 0
                
                # Save best model
                checkpoint_path = os.path.join(checkpoint_dir, 'best_model.pth')
                self.model.save_model(checkpoint_path)
                print(f"New best model saved with val_loss: {val_metrics['loss']:.4f}")
            else:
                no_improvement_count += 1
            
            # Early stopping
            if no_improvement_count >= early_stopping_patience:
                print(f"\nEarly stopping triggered after {epoch + 1} epochs")
                print(f"Best validation loss: {self.best_val_loss:.4f} at epoch {best_epoch}")
                break
        
        # Load best model
        if self.best_model_state is not None:
            self.model.load_state_dict(self.best_model_state)
            print(f"\nTraining completed. Best model loaded from epoch {best_epoch}")
        
        return self.history
    
    def evaluate(self, test_loader: DataLoader) -> Dict[str, float]:
        """
        Evaluate the model on test data.
        
        Args:
            test_loader: Test DataLoader
            
        Returns:
            Dictionary with comprehensive evaluation metrics
        """
        self.model.eval()
        all_outputs = []
        all_targets = []
        
        with torch.no_grad():
            for data, target in test_loader:
                data, target = data.to(self.device), target.to(self.device)
                output = self.model(data)
                
                all_outputs.append(output.cpu().numpy())
                all_targets.append(target.cpu().numpy())
        
        # Concatenate all batches
        all_outputs = np.vstack(all_outputs)
        all_targets = np.vstack(all_targets)
        
        # Extract predictions
        hotspot_probs = all_outputs[:, 0]
        quality_pred = all_outputs[:, 1]
        confidence_pred = all_outputs[:, 2]
        
        hotspot_target = all_targets[:, 0]
        quality_target = all_targets[:, 1]
        confidence_target = all_targets[:, 2]
        
        # Calculate binary predictions
        hotspot_pred_binary = (hotspot_probs >= 0.5).astype(int)
        
        # Classification metrics
        accuracy = accuracy_score(hotspot_target, hotspot_pred_binary)
        precision = precision_score(hotspot_target, hotspot_pred_binary)
        recall = recall_score(hotspot_target, hotspot_pred_binary)
        f1 = f1_score(hotspot_target, hotspot_pred_binary)
        auc = roc_auc_score(hotspot_target, hotspot_probs)
        
        # Regression metrics for quality score
        quality_mse = mean_squared_error(quality_target, quality_pred)
        quality_mae = mean_absolute_error(quality_target, quality_pred)
        quality_r2 = r2_score(quality_target, quality_pred)
        
        # Regression metrics for confidence
        confidence_mse = mean_squared_error(confidence_target, confidence_pred)
        confidence_mae = mean_absolute_error(confidence_target, confidence_pred)
        confidence_r2 = r2_score(confidence_target, confidence_pred)
        
        # Confusion matrix
        cm = confusion_matrix(hotspot_target, hotspot_pred_binary)
        
        metrics = {
            'accuracy': accuracy,
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'auc_roc': auc,
            'quality_mse': quality_mse,
            'quality_mae': quality_mae,
            'quality_r2': quality_r2,
            'confidence_mse': confidence_mse,
            'confidence_mae': confidence_mae,
            'confidence_r2': confidence_r2,
            'confusion_matrix': cm.tolist()
        }
        
        # Print results
        print("\n" + "="*60)
        print("MODEL EVALUATION RESULTS")
        print("="*60)
        print(f"Hotspot Recommendation:")
        print(f"  Accuracy:  {accuracy:.4f}")
        print(f"  Precision: {precision:.4f}")
        print(f"  Recall:    {recall:.4f}")
        print(f"  F1-Score:  {f1:.4f}")
        print(f"  AUC-ROC:   {auc:.4f}")
        print(f"\nQuality Score Prediction:")
        print(f"  MSE: {quality_mse:.4f}")
        print(f"  MAE: {quality_mae:.4f}")
        print(f"  R²:  {quality_r2:.4f}")
        print(f"\nConfidence Prediction:")
        print(f"  MSE: {confidence_mse:.4f}")
        print(f"  MAE: {confidence_mae:.4f}")
        print(f"  R²:  {confidence_r2:.4f}")
        
        return metrics
    
    def plot_training_history(self, save_path: str = None):
        """Plot training history metrics."""
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        
        # Loss plot
        ax1.plot(self.history['train_loss'], label='Train Loss')
        ax1.plot(self.history['val_loss'], label='Val Loss')
        ax1.set_title('Training and Validation Loss')
        ax1.set_xlabel('Epoch')
        ax1.set_ylabel('Loss')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Accuracy plot
        ax2.plot(self.history['train_accuracy'], label='Train Accuracy')
        ax2.plot(self.history['val_accuracy'], label='Val Accuracy')
        ax2.set_title('Training and Validation Accuracy')
        ax2.set_xlabel('Epoch')
        ax2.set_ylabel('Accuracy')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # F1-Score plot
        ax3.plot(self.history['train_f1'], label='Train F1-Score')
        ax3.plot(self.history['val_f1'], label='Val F1-Score')
        ax3.set_title('Training and Validation F1-Score')
        ax3.set_xlabel('Epoch')
        ax3.set_ylabel('F1-Score')
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        
        # Learning rate plot
        ax4.plot(self.history['learning_rates'], label='Learning Rate', color='purple')
        ax4.set_title('Learning Rate Schedule')
        ax4.set_xlabel('Epoch')
        ax4.set_ylabel('Learning Rate')
        ax4.legend()
        ax4.grid(True, alpha=0.3)
        ax4.set_yscale('log')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Training history plot saved to {save_path}")
        
        plt.show()
    
    def save_training_report(self, metrics: Dict, report_path: str = 'training_report.json'):
        """Save comprehensive training report."""
        report = {
            'training_history': self.history,
            'evaluation_metrics': metrics,
            'model_config': {
                'input_size': self.model.input_size,
                'hidden_sizes': self.model.hidden_sizes,
                'dropout_rate': self.model.dropout_rate,
                'use_batch_norm': self.model.use_batch_norm
            },
            'training_config': {
                'device': self.device,
                'best_val_loss': self.best_val_loss
            },
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
        }
        
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"Training report saved to {report_path}")


# Example usage and testing
if __name__ == "__main__":
    # Test the trainer with sample data
    from ...data.generator import DataGenerator
    from ...data.preprocessor import DataPreprocessor
    
    # Generate sample data
    generator = DataGenerator()
    sample_df = generator.generate_dataset(n_samples=1000)
    
    # Preprocess data
    preprocessor = DataPreprocessor()
    X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(sample_df)
    
    # Create model
    model = NetworkQualityModel()
    
    # Create trainer
    trainer = ModelTrainer(model)
    trainer.setup_training(learning_rate=0.001)
    
    # Create dataloaders
    train_loader, val_loader, test_loader = trainer.create_dataloaders(
        X_train, X_val, X_test, y_train, y_val, y_test, batch_size=32
    )
    
    # Test training for a few epochs
    print("Testing trainer with 5 epochs...")
    history = trainer.train(train_loader, val_loader, epochs=5)
    
    # Evaluate model
    metrics = trainer.evaluate(test_loader)
    
    # Save report
    trainer.save_training_report(metrics, 'test_training_report.json')
    
    print("\nTrainer test completed successfully!")
