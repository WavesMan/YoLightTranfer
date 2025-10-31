"""
训练监控器
提供训练过程的实时监控和指标跟踪功能
"""

import time
import threading
from typing import Dict, List, Optional, Callable, Any
from datetime import datetime
import psutil
import numpy as np


class TrainingMonitor:
    """训练监控器类"""
    
    def __init__(self, update_interval: float = 1.0):
        """
        初始化训练监控器
        
        Args:
            update_interval: 监控更新间隔（秒）
        """
        self.update_interval = update_interval
        self.monitoring = False
        self.monitor_thread = None
        
        # 监控数据存储
        self.metrics_history: Dict[str, List[float]] = {}
        self.timestamps: List[datetime] = []
        self.system_metrics: Dict[str, List[float]] = {}
        
        # 回调函数
        self.callbacks: Dict[str, List[Callable]] = {
            'on_epoch_start': [],
            'on_epoch_end': [],
            'on_training_start': [],
            'on_training_end': [],
            'on_metric_update': []
        }
        
        # 当前状态
        self.current_epoch = 0
        self.current_metrics: Dict[str, float] = {}
        self.training_start_time: Optional[float] = None
        
        print("训练监控器初始化完成")
    
    def start_monitoring(self):
        """开始监控"""
        if self.monitoring:
            print("监控已经在运行中")
            return
        
        self.monitoring = True
        self.training_start_time = time.time()
        self.timestamps = []
        self.metrics_history = {}
        self.system_metrics = {
            'cpu_percent': [],
            'memory_percent': [],
            'gpu_memory_percent': []
        }
        
        # 启动监控线程
        self.monitor_thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.monitor_thread.start()
        
        self._trigger_callbacks('on_training_start')
        print("训练监控已启动")
    
    def stop_monitoring(self):
        """停止监控"""
        if not self.monitoring:
            return
        
        self.monitoring = False
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=2.0)
        
        self._trigger_callbacks('on_training_end')
        print("训练监控已停止")
    
    def _monitoring_loop(self):
        """监控循环"""
        while self.monitoring:
            try:
                # 收集系统指标
                self._collect_system_metrics()
                
                # 记录时间戳
                self.timestamps.append(datetime.now())
                
                # 等待下一个更新周期
                time.sleep(self.update_interval)
                
            except Exception as e:
                print(f"监控循环错误: {e}")
                break
    
    def _collect_system_metrics(self):
        """收集系统指标"""
        # CPU使用率
        cpu_percent = psutil.cpu_percent(interval=None)
        self.system_metrics['cpu_percent'].append(cpu_percent)
        
        # 内存使用率
        memory = psutil.virtual_memory()
        self.system_metrics['memory_percent'].append(memory.percent)
        
        # GPU使用率（如果可用）
        try:
            import GPUtil
            gpus = GPUtil.getGPUs()
            if gpus:
                gpu_memory_percent = gpus[0].memoryUtil * 100
                self.system_metrics['gpu_memory_percent'].append(gpu_memory_percent)
        except ImportError:
            # GPU监控不可用
            pass
    
    def on_epoch_start(self, epoch: int):
        """
        记录epoch开始
        
        Args:
            epoch: 当前epoch编号
        """
        self.current_epoch = epoch
        self._trigger_callbacks('on_epoch_start', epoch)
    
    def on_epoch_end(self, metrics: Dict[str, float]):
        """
        记录epoch结束和指标
        
        Args:
            metrics: epoch指标字典
        """
        self.current_metrics = metrics.copy()
        
        # 更新指标历史
        for metric_name, value in metrics.items():
            if metric_name not in self.metrics_history:
                self.metrics_history[metric_name] = []
            self.metrics_history[metric_name].append(value)
        
        self._trigger_callbacks('on_epoch_end', self.current_epoch, metrics)
    
    def update_metrics(self, metrics: Dict[str, float]):
        """
        更新训练指标
        
        Args:
            metrics: 指标字典
        """
        self.current_metrics.update(metrics)
        self._trigger_callbacks('on_metric_update', metrics)
    
    def register_callback(self, event: str, callback: Callable):
        """
        注册回调函数
        
        Args:
            event: 事件名称
            callback: 回调函数
        """
        if event in self.callbacks:
            self.callbacks[event].append(callback)
        else:
            print(f"未知事件: {event}")
    
    def _trigger_callbacks(self, event: str, *args, **kwargs):
        """触发回调函数"""
        for callback in self.callbacks.get(event, []):
            try:
                callback(*args, **kwargs)
            except Exception as e:
                print(f"回调函数执行错误 ({event}): {e}")
    
    def get_current_metrics(self) -> Dict[str, float]:
        """获取当前指标"""
        return self.current_metrics.copy()
    
    def get_metrics_history(self) -> Dict[str, List[float]]:
        """获取指标历史"""
        return self.metrics_history.copy()
    
    def get_system_metrics(self) -> Dict[str, List[float]]:
        """获取系统指标"""
        return self.system_metrics.copy()
    
    def get_training_summary(self) -> Dict[str, Any]:
        """获取训练摘要"""
        if not self.training_start_time:
            return {}
        
        training_duration = time.time() - self.training_start_time
        total_epochs = len(self.timestamps)
        
        summary = {
            'total_epochs': total_epochs,
            'training_duration_seconds': training_duration,
            'training_duration_formatted': self._format_duration(training_duration),
            'average_epoch_time': training_duration / total_epochs if total_epochs > 0 else 0,
            'final_metrics': self.current_metrics,
            'system_metrics_summary': self._get_system_metrics_summary()
        }
        
        return summary
    
    def _get_system_metrics_summary(self) -> Dict[str, float]:
        """获取系统指标摘要"""
        summary = {}
        
        for metric_name, values in self.system_metrics.items():
            if values:
                summary[f'{metric_name}_avg'] = np.mean(values)
                summary[f'{metric_name}_max'] = np.max(values)
                summary[f'{metric_name}_min'] = np.min(values)
        
        return summary
    
    def _format_duration(self, seconds: float) -> str:
        """格式化持续时间"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        seconds = int(seconds % 60)
        
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    def save_monitoring_data(self, file_path: str):
        """
        保存监控数据到文件
        
        Args:
            file_path: 文件路径
        """
        import json
        from datetime import datetime
        
        monitoring_data = {
            'timestamps': [ts.isoformat() for ts in self.timestamps],
            'metrics_history': self.metrics_history,
            'system_metrics': self.system_metrics,
            'training_summary': self.get_training_summary(),
            'export_time': datetime.now().isoformat()
        }
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(monitoring_data, f, indent=2, ensure_ascii=False)
            
            print(f"监控数据已保存到: {file_path}")
            
        except Exception as e:
            print(f"监控数据保存失败: {e}")
    
    def load_monitoring_data(self, file_path: str):
        """
        从文件加载监控数据
        
        Args:
            file_path: 文件路径
        """
        import json
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # 恢复时间戳
            self.timestamps = [datetime.fromisoformat(ts) for ts in data['timestamps']]
            
            # 恢复指标历史
            self.metrics_history = data['metrics_history']
            
            # 恢复系统指标
            self.system_metrics = data['system_metrics']
            
            print(f"监控数据已从文件加载: {file_path}")
            
        except Exception as e:
            print(f"监控数据加载失败: {e}")


class ProgressTracker:
    """进度跟踪器"""
    
    def __init__(self, total_steps: int, description: str = "进度"):
        """
        初始化进度跟踪器
        
        Args:
            total_steps: 总步数
            description: 进度描述
        """
        self.total_steps = total_steps
        self.description = description
        self.current_step = 0
        self.start_time = time.time()
        
    def update(self, step: int = None, message: str = ""):
        """
        更新进度
        
        Args:
            step: 当前步数（可选）
            message: 进度消息
        """
        if step is not None:
            self.current_step = step
        else:
            self.current_step += 1
        
        elapsed_time = time.time() - self.start_time
        progress_percent = (self.current_step / self.total_steps) * 100
        
        if self.current_step > 0:
            estimated_total_time = (elapsed_time / self.current_step) * self.total_steps
            remaining_time = estimated_total_time - elapsed_time
            eta = self._format_duration(remaining_time)
        else:
            eta = "未知"
        
        progress_bar = self._create_progress_bar(progress_percent)
        
        print(f"\r{self.description}: {progress_bar} {progress_percent:.1f}% | "
              f"步骤 {self.current_step}/{self.total_steps} | "
              f"已用时间: {self._format_duration(elapsed_time)} | "
              f"预计剩余: {eta} {message}", end="", flush=True)
        
        if self.current_step >= self.total_steps:
            print()  # 换行
    
    def _create_progress_bar(self, percent: float, length: int = 30) -> str:
        """创建进度条"""
        filled_length = int(length * percent // 100)
        bar = '█' * filled_length + '░' * (length - filled_length)
        return f"[{bar}]"
    
    def _format_duration(self, seconds: float) -> str:
        """格式化持续时间"""
        if seconds < 60:
            return f"{seconds:.1f}秒"
        elif seconds < 3600:
            minutes = seconds / 60
            return f"{minutes:.1f}分钟"
        else:
            hours = seconds / 3600
            return f"{hours:.1f}小时"
    
    def complete(self, message: str = "完成!"):
        """标记完成"""
        self.update(self.total_steps, message)


# 全局监控器实例
training_monitor = TrainingMonitor()


def get_training_monitor() -> TrainingMonitor:
    """获取全局训练监控器实例"""
    return training_monitor


if __name__ == "__main__":
    # 测试训练监控器
    print("测试训练监控器...")
    
    monitor = TrainingMonitor(update_interval=0.5)
    
    # 测试回调函数
    def on_epoch_callback(epoch, metrics):
        print(f"Epoch {epoch} 完成: {metrics}")
    
    monitor.register_callback('on_epoch_end', on_epoch_callback)
    
    # 开始监控
    monitor.start_monitoring()
    
    # 模拟训练过程
    for epoch in range(5):
        monitor.on_epoch_start(epoch)
        
        # 模拟训练
        time.sleep(1)
        
        # 记录指标
        metrics = {
            'train_loss': 1.0 / (epoch + 1),
            'val_loss': 1.2 / (epoch + 1),
            'accuracy': 0.8 + epoch * 0.05
        }
        monitor.on_epoch_end(metrics)
    
    # 停止监控
    monitor.stop_monitoring()
    
    # 获取摘要
    summary = monitor.get_training_summary()
    print(f"训练摘要: {summary}")
    
    print("训练监控器测试完成!")
