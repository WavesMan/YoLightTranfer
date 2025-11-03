#!/usr/bin/env python3
"""
Training Script for AI Network Quality Model

This script provides a convenient way to train the network quality model
with various configuration options and command-line arguments.
"""

import os
import sys
import argparse

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.main import NetworkQualityTrainer
from src.utils.config import Config


def main():
    """Main training script with command-line arguments."""
    parser = argparse.ArgumentParser(
        description='Train AI Network Quality Model',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Data configuration
    parser.add_argument('--dataset-size', type=int, default=10000,
                       help='Number of samples in training dataset')
    parser.add_argument('--scenario-weights', type=str, default='0.4,0.3,0.3',
                       help='Weights for network scenarios (strong,weak,critical)')
    
    # Model configuration
    parser.add_argument('--hidden-sizes', type=str, default='64,32,16',
                       help='Hidden layer sizes (comma-separated)')
    parser.add_argument('--dropout-rate', type=float, default=0.2,
                       help='Dropout rate for regularization')
    parser.add_argument('--use-batch-norm', action='store_true', default=True,
                       help='Use batch normalization')
    
    # Training configuration
    parser.add_argument('--epochs', type=int, default=100,
                       help='Maximum number of training epochs')
    parser.add_argument('--batch-size', type=int, default=32,
                       help='Training batch size')
    parser.add_argument('--learning-rate', type=float, default=0.001,
                       help='Learning rate')
    parser.add_argument('--weight-decay', type=float, default=1e-4,
                       help='Weight decay for regularization')
    parser.add_argument('--early-stopping', type=int, default=10,
                       help='Early stopping patience')
    
    # Data splitting
    parser.add_argument('--test-split', type=float, default=0.2,
                       help='Proportion of data for testing')
    parser.add_argument('--val-split', type=float, default=0.1,
                       help='Proportion of training data for validation')
    
    # Output options
    parser.add_argument('--output-dir', type=str, default='models',
                       help='Directory to save trained models and results')
    parser.add_argument('--no-save-data', action='store_true',
                       help='Do not save generated training data')
    parser.add_argument('--config-file', type=str,
                       help='Load configuration from JSON file')
    parser.add_argument('--save-config', type=str,
                       help='Save configuration to JSON file')
    
    args = parser.parse_args()
    
    # Parse scenario weights
    try:
        scenario_weights = [float(x) for x in args.scenario_weights.split(',')]
        if len(scenario_weights) != 3:
            raise ValueError("Must provide exactly 3 scenario weights")
        if abs(sum(scenario_weights) - 1.0) > 0.01:
            print("Warning: Scenario weights do not sum to 1.0")
        
        scenario_weights_dict = {
            "strong_network": scenario_weights[0],
            "weak_network": scenario_weights[1],
            "critical_network": scenario_weights[2]
        }
    except ValueError as e:
        print(f"Error parsing scenario weights: {e}")
        return 1
    
    # Parse hidden sizes
    try:
        hidden_sizes = tuple(int(x) for x in args.hidden_sizes.split(','))
    except ValueError as e:
        print(f"Error parsing hidden sizes: {e}")
        return 1
    
    # Load or create configuration
    if args.config_file:
        config = Config(args.config_file)
        print(f"Loaded configuration from {args.config_file}")
    else:
        config = Config()
    
    # Update configuration with command-line arguments
    config.update(
        dataset_size=args.dataset_size,
        hidden_sizes=hidden_sizes,
        dropout_rate=args.dropout_rate,
        use_batch_norm=args.use_batch_norm,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        weight_decay=args.weight_decay,
        early_stopping_patience=args.early_stopping,
        test_split=args.test_split,
        validation_split=args.val_split
    )
    
    # Update scenario weights
    config.data.scenario_weights = scenario_weights_dict
    
    # Update output directory
    config.data.models_dir = args.output_dir
    config.data.checkpoint_dir = os.path.join(args.output_dir, 'checkpoints')
    
    # Save configuration if requested
    if args.save_config:
        config.save(args.save_config)
    
    # Print configuration summary
    print("\n" + "="*60)
    print("TRAINING CONFIGURATION")
    print("="*60)
    config.print_summary()
    
    # Create and run trainer
    trainer = NetworkQualityTrainer(config)
    
    try:
        print("\nStarting training pipeline...")
        results = trainer.run_complete_pipeline(save_data=not args.no_save_data)
        
        print("\n" + "="*60)
        print("TRAINING COMPLETED SUCCESSFULLY!")
        print("="*60)
        
        # Print key results
        eval_metrics = results['evaluation']['comprehensive_metrics']
        print(f"Hotspot F1-Score: {eval_metrics['hotspot_recommendation']['f1_score']:.4f}")
        print(f"Quality Score MAE: {eval_metrics['quality_score']['mae']:.4f}")
        print(f"Overall Score: {eval_metrics['overall']['overall_score']:.4f}")
        
        return 0
        
    except KeyboardInterrupt:
        print("\nTraining interrupted by user")
        return 1
    except Exception as e:
        print(f"\nTraining failed: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
