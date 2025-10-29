# language: python
import os
import sys

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.models.network_model import NetworkQualityModel
from src.models.trainer import ModelTrainer
from src.utils.config import Config

def auto_train_iter(n_iters: int = 50, config_path: str = "configs/train_config.json"):
    cfg = Config(config_path)
    os.makedirs(cfg.data.models_dir, exist_ok=True)

    for i in range(1, n_iters + 1):
        print(f"[{i}/{n_iters}] 生成数据...")
        # Initialize generator with a fixed seed
        generator = DataGenerator(seed=cfg.training.random_seed)
        # Generate dataset (using default scenarios)
        raw_dataset = generator.generate_dataset(n_samples=cfg.data.dataset_size)

        print(f"[{i}/{n_iters}] 预处理与划分数据集...")
        preprocessor = DataPreprocessor()
        X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(
            raw_dataset,
            test_size=cfg.training.test_split,
            validation_size=cfg.training.validation_split,
            random_state=cfg.training.random_seed
        )

        print(f"[{i}/{n_iters}] 构建模型与训练...")
        model = NetworkQualityModel(
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
            use_batch_norm=cfg.model.use_batch_norm
        )

        trainer = ModelTrainer(model=model)
        trainer.setup_training(
            learning_rate=cfg.training.learning_rate,
            weight_decay=cfg.training.weight_decay
        )
        
        # Create dataloaders using trainer's method
        train_loader, val_loader, test_loader = trainer.create_dataloaders(
            X_train, X_val, X_test, y_train, y_val, y_test,
            batch_size=cfg.training.batch_size,
            shuffle=True
        )
        
        best_metrics = trainer.train(
            train_loader, 
            val_loader,
            epochs=cfg.training.epochs,
            early_stopping_patience=cfg.training.early_stopping_patience,
            checkpoint_dir=cfg.data.checkpoint_dir
        )

        model_path = os.path.join(cfg.data.models_dir, f"model_iter_{i}.pth")
        model.save_model(model_path)
        print(f"[{i}/{n_iters}] 已保存模型: {model_path}")
        print(f"[{i}/{n_iters}] 验证集指标: {best_metrics}\n")

if __name__ == "__main__":
    auto_train_iter()
