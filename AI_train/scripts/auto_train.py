# language: python
import os
import sys
import time
import json
import threading
from datetime import datetime

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

class MultiTerminalTrainer:
    """多终端训练管理器 - 简化版本"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.terminal_id = self._generate_simple_terminal_id()
        self.progress_file = os.path.join(self.cfg.data.models_dir, "shared_progress.json")
        self.terminal_dir = os.path.join(self.cfg.data.models_dir, self.terminal_id)
        os.makedirs(self.terminal_dir, exist_ok=True)
        
    def _generate_simple_terminal_id(self) -> str:
        """生成简化的终端标识符"""
        timestamp = int(time.time())
        return f"terminal_{timestamp}"
    
    def get_next_iteration(self) -> int:
        """获取下一个可用的迭代编号 - 简化版本"""
        try:
            # 读取现有进度
            if os.path.exists(self.progress_file):
                with open(self.progress_file, 'r') as f:
                    progress_data = json.load(f)
            else:
                progress_data = {"total_iterations": 0, "terminals": {}}
            
            # 计算下一个迭代编号
            next_iter = progress_data["total_iterations"] + 1
            
            # 更新进度数据
            progress_data["total_iterations"] = next_iter
            progress_data["terminals"][self.terminal_id] = {
                "current_iteration": next_iter,
                "last_update": datetime.now().isoformat()
            }
            
            # 保存进度
            with open(self.progress_file, 'w') as f:
                json.dump(progress_data, f, indent=2)
            
            return next_iter
            
        except (json.JSONDecodeError, KeyError):
            # 如果文件损坏，重新开始
            progress_data = {"total_iterations": 1, "terminals": {
                self.terminal_id: {
                    "current_iteration": 1,
                    "last_update": datetime.now().isoformat()
                }
            }}
            with open(self.progress_file, 'w') as f:
                json.dump(progress_data, f, indent=2)
            return 1
    
    def generate_model_path(self, iteration: int) -> str:
        """生成唯一的模型文件路径 - 简化版本"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"model_iter_{iteration}_{timestamp}.pth"
        return os.path.join(self.terminal_dir, filename)
    
    def get_progress_summary(self) -> dict:
        """获取训练进度摘要"""
        try:
            with open(self.progress_file, 'r') as f:
                progress_data = json.load(f)
                return progress_data
        except (FileNotFoundError, json.JSONDecodeError):
            return {"total_iterations": 0, "terminals": {}}

def auto_train_iter(n_iters: int = 1000, config_path: str = "configs/train_config.json"):
    """多终端多线程自动训练函数"""
    # 初始化多终端训练管理器
    mt_trainer = MultiTerminalTrainer(config_path)
    cfg = mt_trainer.cfg
    
    print(f"🚀 启动多终端训练 - 终端ID: {mt_trainer.terminal_id}")
    print(f"📁 模型保存目录: {mt_trainer.terminal_dir}")
    
    # 显示当前进度摘要
    progress_summary = mt_trainer.get_progress_summary()
    print(f"📊 当前总进度: {progress_summary['total_iterations']} 次迭代")
    print(f"💻 活跃终端: {len(progress_summary['terminals'])} 个")
    
    for _ in range(n_iters):
        # 获取下一个可用的迭代编号
        iteration = mt_trainer.get_next_iteration()
        
        print(f"\n🎯 开始训练迭代 #{iteration}")
        print(f"⏰ 开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        print(f"[{iteration}] 生成数据...")
        # Initialize generator with a fixed seed
        generator = DataGenerator(seed=cfg.training.random_seed)
        # Generate dataset (using default scenarios)
        raw_dataset = generator.generate_dataset(n_samples=cfg.data.dataset_size)

        print(f"[{iteration}] 预处理与划分数据集...")
        preprocessor = DataPreprocessor()
        X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(
            raw_dataset,
            test_size=cfg.training.test_split,
            validation_size=cfg.training.validation_split,
            random_state=cfg.training.random_seed
        )

        print(f"[{iteration}] 构建模型与训练...")
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

        # 使用多终端管理器生成唯一的模型路径
        model_path = mt_trainer.generate_model_path(iteration)
        model.save_model(model_path)
        print(f"✅ [{iteration}] 已保存模型: {model_path}")
        print(f"📈 [{iteration}] 验证集指标: {best_metrics}")
        
        # 更新进度显示
        progress_summary = mt_trainer.get_progress_summary()
        print(f"📊 当前总进度: {progress_summary['total_iterations']} 次迭代")
        print(f"⏰ 完成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    auto_train_iter()
