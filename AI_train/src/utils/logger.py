"""
训练日志器
提供训练过程的日志记录和管理功能
"""

import logging
import sys
import os
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime
import json


class TrainingLogger:
    """训练日志器类"""
    
    def __init__(self, 
                 log_dir: str = "logs",
                 log_level: int = logging.INFO,
                 console_output: bool = True,
                 file_output: bool = True):
        """
        初始化训练日志器
        
        Args:
            log_dir: 日志目录
            log_level: 日志级别
            console_output: 是否输出到控制台
            file_output: 是否输出到文件
        """
        self.log_dir = Path(log_dir)
        self.log_level = log_level
        self.console_output = console_output
        self.file_output = file_output
        
        # 创建日志目录
        self.log_dir.mkdir(exist_ok=True)
        
        # 配置日志器
        self.logger = logging.getLogger("YoLightTrainer")
        self.logger.setLevel(log_level)
        
        # 清除现有处理器
        self.logger.handlers.clear()
        
        # 创建格式化器
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # 控制台处理器
        if console_output:
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setLevel(log_level)
            console_handler.setFormatter(formatter)
            self.logger.addHandler(console_handler)
        
        # 文件处理器
        if file_output:
            log_file = self.log_dir / f"training_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
            file_handler = logging.FileHandler(log_file, encoding='utf-8')
            file_handler.setLevel(log_level)
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)
            
            self.current_log_file = log_file
        
        # 训练统计信息
        self.training_stats: Dict[str, Any] = {
            'start_time': None,
            'end_time': None,
            'total_epochs': 0,
            'best_epoch': 0,
            'best_loss': float('inf'),
            'metrics_history': {}
        }
        
        self.logger.info("训练日志器初始化完成")
    
    def info(self, message: str, **kwargs):
        """记录信息日志"""
        if kwargs:
            message = f"{message} | {self._format_kwargs(kwargs)}"
        self.logger.info(message)
    
    def debug(self, message: str, **kwargs):
        """记录调试日志"""
        if kwargs:
            message = f"{message} | {self._format_kwargs(kwargs)}"
        self.logger.debug(message)
    
    def warning(self, message: str, **kwargs):
        """记录警告日志"""
        if kwargs:
            message = f"{message} | {self._format_kwargs(kwargs)}"
        self.logger.warning(message)
    
    def error(self, message: str, **kwargs):
        """记录错误日志"""
        if kwargs:
            message = f"{message} | {self._format_kwargs(kwargs)}"
        self.logger.error(message)
    
    def critical(self, message: str, **kwargs):
        """记录严重错误日志"""
        if kwargs:
            message = f"{message} | {self._format_kwargs(kwargs)}"
        self.logger.critical(message)
    
    def _format_kwargs(self, kwargs: Dict[str, Any]) -> str:
        """格式化关键字参数"""
        return " | ".join([f"{k}={v}" for k, v in kwargs.items()])
    
    def log_training_start(self, config: Dict[str, Any]):
        """记录训练开始"""
        self.training_stats['start_time'] = datetime.now().isoformat()
        self.training_stats['config'] = config
        
        self.info("训练开始", 
                  config_file=config.get('config_file', 'default'),
                  total_epochs=config.get('training', {}).get('epochs', 'unknown'))
    
    def log_training_end(self, results: Dict[str, Any]):
        """记录训练结束"""
        self.training_stats['end_time'] = datetime.now().isoformat()
        self.training_stats['results'] = results
        
        training_duration = self._calculate_duration()
        
        self.info("训练完成", 
                  duration=training_duration,
                  total_epochs=self.training_stats['total_epochs'],
                  best_loss=self.training_stats['best_loss'])
    
    def log_epoch_start(self, epoch: int, total_epochs: int):
        """记录epoch开始"""
        self.training_stats['total_epochs'] = total_epochs
        self.info(f"Epoch {epoch}/{total_epochs} 开始")
    
    def log_epoch_end(self, epoch: int, metrics: Dict[str, float]):
        """记录epoch结束"""
        # 更新指标历史
        for metric_name, value in metrics.items():
            if metric_name not in self.training_stats['metrics_history']:
                self.training_stats['metrics_history'][metric_name] = []
            self.training_stats['metrics_history'][metric_name].append(value)
        
        # 更新最佳结果
        if 'loss' in metrics and metrics['loss'] < self.training_stats['best_loss']:
            self.training_stats['best_loss'] = metrics['loss']
            self.training_stats['best_epoch'] = epoch
        
        self.info(f"Epoch {epoch} 完成", **metrics)
    
    def log_metrics(self, metrics: Dict[str, float], prefix: str = ""):
        """记录指标"""
        if prefix:
            metrics = {f"{prefix}_{k}": v for k, v in metrics.items()}
        
        self.info("指标更新", **metrics)
    
    def log_checkpoint(self, epoch: int, file_path: str, metrics: Dict[str, float]):
        """记录检查点保存"""
        self.info(f"检查点保存: Epoch {epoch}", 
                  checkpoint_file=file_path,
                  **metrics)
    
    def log_evaluation(self, evaluation_results: Dict[str, float]):
        """记录评估结果"""
        self.info("模型评估完成", **evaluation_results)
    
    def log_hardware_info(self, hardware_info: Dict[str, Any]):
        """记录硬件信息"""
        cpu_info = hardware_info.get('cpu', {})
        gpu_info = hardware_info.get('gpu', {})
        memory_info = hardware_info.get('memory', {})
        
        self.info("硬件配置信息",
                  cpu_cores=cpu_info.get('logical_cores', 'unknown'),
                  gpu_available=gpu_info.get('available', False),
                  gpu_memory_gb=gpu_info.get('memory_gb', 0),
                  total_memory_gb=memory_info.get('total_gb', 0))
    
    def log_benchmark_results(self, benchmark_results: Dict[str, Any]):
        """记录基准测试结果"""
        cpu_perf = benchmark_results.get('cpu_performance', {})
        memory_perf = benchmark_results.get('memory_performance', {})
        
        self.info("基准测试结果",
                  cpu_single_thread=cpu_perf.get('single_thread_performance', 0),
                  memory_speed_mbps=memory_perf.get('memory_copy_speed_mb_per_sec', 0))
    
    def _calculate_duration(self) -> str:
        """计算训练持续时间"""
        if not self.training_stats['start_time'] or not self.training_stats['end_time']:
            return "未知"
        
        start = datetime.fromisoformat(self.training_stats['start_time'])
        end = datetime.fromisoformat(self.training_stats['end_time'])
        duration = end - start
        
        hours, remainder = divmod(duration.total_seconds(), 3600)
        minutes, seconds = divmod(remainder, 60)
        
        return f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d}"
    
    def save_training_summary(self, file_path: Optional[str] = None):
        """保存训练摘要"""
        if file_path is None:
            file_path = self.log_dir / f"training_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        summary = {
            'training_stats': self.training_stats,
            'log_file': str(self.current_log_file) if hasattr(self, 'current_log_file') else None,
            'export_time': datetime.now().isoformat()
        }
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
            
            self.info(f"训练摘要已保存到: {file_path}")
            return file_path
            
        except Exception as e:
            self.error(f"训练摘要保存失败: {e}")
            return None
    
    def get_log_file_path(self) -> Optional[str]:
        """获取当前日志文件路径"""
        return str(self.current_log_file) if hasattr(self, 'current_log_file') else None
    
    def set_log_level(self, level: int):
        """设置日志级别"""
        self.log_level = level
        self.logger.setLevel(level)
        for handler in self.logger.handlers:
            handler.setLevel(level)
    
    def close(self):
        """关闭日志器"""
        for handler in self.logger.handlers:
            handler.close()
        self.logger.handlers.clear()


class StructuredLogger:
    """结构化日志器 - 用于记录结构化数据"""
    
    def __init__(self, log_dir: str = "logs/structured"):
        """
        初始化结构化日志器
        
        Args:
            log_dir: 日志目录
        """
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # 当前会话ID
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        
    def log_structured_data(self, 
                           data_type: str, 
                           data: Dict[str, Any],
                           timestamp: Optional[datetime] = None):
        """
        记录结构化数据
        
        Args:
            data_type: 数据类型
            data: 数据字典
            timestamp: 时间戳（可选）
        """
        if timestamp is None:
            timestamp = datetime.now()
        
        log_entry = {
            'timestamp': timestamp.isoformat(),
            'session_id': self.session_id,
            'data_type': data_type,
            'data': data
        }
        
        # 按数据类型创建不同的日志文件
        log_file = self.log_dir / f"{data_type}_{self.session_id}.jsonl"
        
        try:
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
                
        except Exception as e:
            print(f"结构化数据记录失败: {e}")
    
    def log_metrics_batch(self, metrics_batch: Dict[str, list[float]]):
        """记录批量指标数据"""
        self.log_structured_data('metrics_batch', metrics_batch)
    
    def log_system_metrics(self, system_metrics: Dict[str, float]):
        """记录系统指标"""
        self.log_structured_data('system_metrics', system_metrics)
    
    def log_training_progress(self, progress_data: Dict[str, Any]):
        """记录训练进度"""
        self.log_structured_data('training_progress', progress_data)


# 全局日志器实例
training_logger = TrainingLogger()


def get_training_logger() -> TrainingLogger:
    """获取全局训练日志器实例"""
    return training_logger


def setup_logging(log_dir: str = "logs", 
                 log_level: int = logging.INFO,
                 console_output: bool = True,
                 file_output: bool = True) -> TrainingLogger:
    """
    设置日志配置
    
    Args:
        log_dir: 日志目录
        log_level: 日志级别
        console_output: 是否输出到控制台
        file_output: 是否输出到文件
        
    Returns:
        训练日志器实例
    """
    global training_logger
    
    # 关闭现有日志器
    training_logger.close()
    
    # 创建新的日志器
    training_logger = TrainingLogger(
        log_dir=log_dir,
        log_level=log_level,
        console_output=console_output,
        file_output=file_output
    )
    
    return training_logger


if __name__ == "__main__":
    # 测试训练日志器
    print("测试训练日志器...")
    
    logger = TrainingLogger(log_dir="test_logs", log_level=logging.DEBUG)
    
    # 测试各种日志级别
    logger.debug("调试信息", extra_data="test")
    logger.info("一般信息", epoch=1, loss=0.5)
    logger.warning("警告信息", issue="test_issue")
    logger.error("错误信息", error_code=500)
    
    # 测试训练流程日志
    config = {
        'training': {'epochs': 100},
        'config_file': 'test_config.json'
    }
    
    logger.log_training_start(config)
    
    for epoch in range(3):
        logger.log_epoch_start(epoch, 100)
        
        # 模拟训练
        metrics = {
            'loss': 1.0 / (epoch + 1),
            'accuracy': 0.7 + epoch * 0.1,
            'val_loss': 1.2 / (epoch + 1)
        }
        
        logger.log_epoch_end(epoch, metrics)
    
    results = {
        'final_loss': 0.1,
        'final_accuracy': 0.95
    }
    
    logger.log_training_end(results)
    
    # 保存训练摘要
    summary_file = logger.save_training_summary()
    print(f"训练摘要保存到: {summary_file}")
    
    # 测试结构化日志器
    structured_logger = StructuredLogger()
    structured_logger.log_system_metrics({
        'cpu_percent': 45.6,
        'memory_percent': 67.8
    })
    
    logger.close()
    print("训练日志器测试完成!")
