"""
AI Network Quality Analysis - Main Program

This is the main entry point for the AI network quality analysis project.
It provides a complete pipeline for data generation, model training, and evaluation.
"""

import os
import sys
import argparse
import json
from typing import Dict, Any

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.models.network_model import NetworkQualityModel
from src.models.trainer import ModelTrainer
from src.utils.config import Config
from src.utils.metrics import ModelMetrics


class NetworkQualityTrainer:
    """
    Complete pipeline for network quality model training and evaluation.
    
    This class orchestrates the entire process:
    1. Data generation and preprocessing
    2. Model training and validation
    3. Model evaluation and testing
    4. Results analysis and reporting
    """
    
    def __init__(self, config: Config = None):
        """
        Initialize the trainer with configuration.
        
        Args:
            config: Configuration object (uses default if None)
        """
        self.config = config or Config()
        self.data_generator = DataGenerator()
        self.preprocessor = DataPreprocessor()
        self.metrics_calc = ModelMetrics()
        
        # Training artifacts
        self.model = None
        self.trainer = None
        self.training_data = None
        self.evaluation_results = None
        
        print("Network Quality Trainer initialized")
        self.config.print_summary()
    
    def generate_training_data(self, save_data: bool = True) -> Dict[str, Any]:
        """
        Generate training dataset.
        
        Args:
            save_data: Whether to save generated data to file
            
        Returns:
            Dictionary with generated data and metadata
        """
        print("\n" + "="*60)
        print("GENERATING TRAINING DATA")
        print("="*60)
        
        # Generate dataset
        dataset = self.data_generator.generate_dataset(
            n_samples=self.config.data.dataset_size,
            scenario_weights=self.config.data.scenario_weights
        )
        
        # Save dataset if requested
        if save_data:
            data_path = os.path.join(self.config.data.processed_data_dir, "training_dataset.csv")
            self.data_generator.save_dataset(dataset, data_path)
        
        # Dataset statistics
        stats = {
            'total_samples': len(dataset),
            'hotspot_recommendations': dataset['shouldRecommendHotspot'].value_counts().to_dict(),
            'scenario_distribution': dataset['scenario'].value_counts().to_dict(),
            'avg_bandwidth': dataset['bandwidthMbps'].mean(),
            'avg_delay': dataset['avgDelayMs'].mean(),
            'avg_loss': dataset['packetLossRate'].mean()
        }
        
        print(f"Generated {len(dataset)} samples")
        print(f"Hotspot recommendations: {stats['hotspot_recommendations']}")
        print(f"Scenario distribution: {stats['scenario_distribution']}")
        
        self.training_data = {
            'dataset': dataset,
            'stats': stats
        }
        
        return self.training_data
    
    def preprocess_data(self, dataset) -> tuple:
        """
        Preprocess the training data.
        
        Args:
            dataset: Generated dataset
            
        Returns:
            Preprocessed data splits
        """
        print("\n" + "="*60)
        print("PREPROCESSING DATA")
        print("="*60)
        
        # Preprocess data
        X_train, X_val, X_test, y_train, y_val, y_test, scaler = self.preprocessor.preprocess_data(
            dataset,
            test_size=self.config.training.test_split,
            validation_size=self.config.training.validation_split
        )
        
        print(f"Training set: {X_train.shape}")
        print(f"Validation set: {X_val.shape}")
        print(f"Test set: {X_test.shape}")
        
        return X_train, X_val, X_test, y_train, y_val, y_test, scaler
    
    def train_model(self, X_train, X_val, X_test, y_train, y_val, y_test) -> Dict[str, Any]:
        """
        Train the network quality model.
        
        Args:
            X_train, X_val, X_test: Feature arrays
            y_train, y_val, y_test: Label arrays
            
        Returns:
            Training results and history
        """
        print("\n" + "="*60)
        print("TRAINING MODEL")
        print("="*60)
        
        # Create model
        self.model = NetworkQualityModel(
            input_size=self.config.model.input_size,
            hidden_sizes=self.config.model.hidden_sizes,
            dropout_rate=self.config.model.dropout_rate,
            use_batch_norm=self.config.model.use_batch_norm
        )
        
        # Create trainer
        self.trainer = ModelTrainer(self.model)
        self.trainer.setup_training(
            learning_rate=self.config.training.learning_rate,
            weight_decay=self.config.training.weight_decay
        )
        
        # Create data loaders
        train_loader, val_loader, test_loader = self.trainer.create_dataloaders(
            X_train, X_val, X_test, y_train, y_val, y_test,
            batch_size=self.config.training.batch_size
        )
        
        # Train model
        history = self.trainer.train(
            train_loader,
            val_loader,
            epochs=self.config.training.epochs,
            early_stopping_patience=self.config.training.early_stopping_patience,
            checkpoint_dir=self.config.data.checkpoint_dir
        )
        
        # Evaluate on test set
        test_metrics = self.trainer.evaluate(test_loader)
        
        # Save training artifacts
        model_path = os.path.join(self.config.data.models_dir, "final_model.pth")
        self.model.save_model(model_path)
        
        report_path = os.path.join(self.config.data.models_dir, "training_report.json")
        self.trainer.save_training_report(test_metrics, report_path)
        
        # Plot training history
        plot_path = os.path.join(self.config.data.models_dir, "training_history.png")
        self.trainer.plot_training_history(plot_path)
        
        training_results = {
            'history': history,
            'test_metrics': test_metrics,
            'model_path': model_path,
            'report_path': report_path
        }
        
        return training_results
    
    def evaluate_model(self, X_test, y_test) -> Dict[str, Any]:
        """
        Comprehensive model evaluation.
        
        Args:
            X_test: Test features
            y_test: Test labels
            
        Returns:
            Comprehensive evaluation results
        """
        print("\n" + "="*60)
        print("COMPREHENSIVE MODEL EVALUATION")
        print("="*60)
        
        if self.model is None:
            raise ValueError("Model must be trained before evaluation")
        
        # Make predictions
        predictions = self.model.predict(X_test)
        
        # Extract true values
        y_true_hotspot = y_test[:, 0]
        y_true_quality = y_test[:, 1]
        y_true_confidence = y_test[:, 2]
        
        # Calculate comprehensive metrics
        comprehensive_metrics = self.metrics_calc.calculate_comprehensive_metrics(
            y_true_hotspot=y_true_hotspot,
            y_pred_hotspot=predictions['hotspot_recommendation'],
            y_prob_hotspot=predictions['hotspot_probability'],
            y_true_quality=y_true_quality,
            y_pred_quality=predictions['quality_score'],
            y_true_confidence=y_true_confidence,
            y_pred_confidence=predictions['confidence'],
            threshold=self.config.evaluation.confidence_threshold
        )
        
        # Generate evaluation plots
        if self.config.evaluation.plot_results:
            # Confusion matrix
            cm_path = os.path.join(self.config.data.models_dir, "confusion_matrix.png")
            self.metrics_calc.plot_confusion_matrix(
                y_true_hotspot, 
                predictions['hotspot_recommendation'],
                save_path=cm_path
            )
            
            # ROC curve
            roc_path = os.path.join(self.config.data.models_dir, "roc_curve.png")
            self.metrics_calc.plot_roc_curve(
                y_true_hotspot,
                predictions['hotspot_probability'],
                save_path=roc_path
            )
        
        # Save evaluation report
        eval_report_path = os.path.join(self.config.data.models_dir, "evaluation_report.json")
        self.metrics_calc.generate_report(comprehensive_metrics, eval_report_path)
        
        self.evaluation_results = {
            'comprehensive_metrics': comprehensive_metrics,
            'predictions': predictions,
            'report_path': eval_report_path
        }
        
        return self.evaluation_results
    
    def run_complete_pipeline(self, save_data: bool = True) -> Dict[str, Any]:
        """
        Run the complete training and evaluation pipeline.
        
        Args:
            save_data: Whether to save generated data
            
        Returns:
            Complete pipeline results
        """
        print("="*80)
        print("STARTING COMPLETE AI NETWORK QUALITY TRAINING PIPELINE")
        print("="*80)
        
        try:
            # Step 1: Generate data
            data_results = self.generate_training_data(save_data=save_data)
            
            # Step 2: Preprocess data
            X_train, X_val, X_test, y_train, y_val, y_test, scaler = self.preprocess_data(
                data_results['dataset']
            )
            
            # Step 3: Train model
            training_results = self.train_model(X_train, X_val, X_test, y_train, y_val, y_test)
            
            # Step 4: Evaluate model
            evaluation_results = self.evaluate_model(X_test, y_test)
            
            # Compile final results
            final_results = {
                'data_generation': data_results,
                'training': training_results,
                'evaluation': evaluation_results,
                'config': self.config.to_dict()
            }
            
            # Save final results
            results_path = os.path.join(self.config.data.models_dir, "pipeline_results.json")
            with open(results_path, 'w', encoding='utf-8') as f:
                json.dump(final_results, f, indent=2, ensure_ascii=False)
            
            print("\n" + "="*80)
            print("PIPELINE COMPLETED SUCCESSFULLY!")
            print("="*80)
            print(f"Final model saved to: {training_results['model_path']}")
            print(f"Training report: {training_results['report_path']}")
            print(f"Evaluation report: {evaluation_results['report_path']}")
            print(f"Pipeline results: {results_path}")
            
            # Print final metrics summary
            overall_score = evaluation_results['comprehensive_metrics']['overall']['overall_score']
            hotspot_f1 = evaluation_results['comprehensive_metrics']['hotspot_recommendation']['f1_score']
            quality_mae = evaluation_results['comprehensive_metrics']['quality_score']['mae']
            
            print(f"\nFINAL PERFORMANCE SUMMARY:")
            print(f"  Overall Score: {overall_score:.4f}")
            print(f"  Hotspot F1-Score: {hotspot_f1:.4f}")
            print(f"  Quality Score MAE: {quality_mae:.4f}")
            
            return final_results
            
        except Exception as e:
            print(f"\nERROR: Pipeline failed with exception: {e}")
            raise


def main():
    """Main function for command-line execution."""
    parser = argparse.ArgumentParser(description='AI Network Quality Analysis Training')
    parser.add_argument('--config', type=str, help='Path to configuration file')
    parser.add_argument('--dataset-size', type=int, help='Size of training dataset')
    parser.add_argument('--epochs', type=int, help='Number of training epochs')
    parser.add_argument('--batch-size', type=int, help='Training batch size')
    parser.add_argument('--learning-rate', type=float, help='Learning rate')
    parser.add_argument('--no-save-data', action='store_true', help='Skip saving generated data')
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config(args.config) if args.config else Config()
    
    # Update configuration from command line arguments
    updates = {}
    if args.dataset_size:
        updates['dataset_size'] = args.dataset_size
    if args.epochs:
        updates['epochs'] = args.epochs
    if args.batch_size:
        updates['batch_size'] = args.batch_size
    if args.learning_rate:
        updates['learning_rate'] = args.learning_rate
    
    if updates:
        config.update(**updates)
    
    # Create and run trainer
    trainer = NetworkQualityTrainer(config)
    
    try:
        results = trainer.run_complete_pipeline(save_data=not args.no_save_data)
        print("\nTraining completed successfully!")
        
    except KeyboardInterrupt:
        print("\nTraining interrupted by user")
    except Exception as e:
        print(f"\nTraining failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
