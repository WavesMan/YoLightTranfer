# language: python
import os
import sys
import subprocess
import time
import json
import threading
import signal
import psutil
import logging
from datetime import datetime
from typing import List, Dict, Optional
import platform

# 确保项目根目录在PYTHONPATH中
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from scripts.dingtalk_notifier import TrainingNotifier, DingTalkConfig


class WindowManager:
    """窗口管理器 - 实现窗口置顶功能"""
    
    def __init__(self):
        self.is_windows = platform.system() == "Windows"
        self.window_handle = None
        
    def set_window_always_on_top(self):
        """设置窗口置顶"""
        if not self.is_windows:
            print("⚠️ 窗口置顶功能仅支持Windows平台")
            return False
            
        try:
            import win32gui
            import win32con
            
            # 获取当前控制台窗口句柄
            def enum_windows_proc(hwnd, _):
                if win32gui.IsWindowVisible(hwnd):
                    window_text = win32gui.GetWindowText(hwnd)
                    if "multi_train_manager" in window_text.lower() or "python" in window_text.lower():
                        self.window_handle = hwnd
                        return False
                return True
            
            win32gui.EnumWindows(enum_windows_proc, None)
            
            if self.window_handle:
                # 设置窗口置顶
                win32gui.SetWindowPos(
                    self.window_handle,
                    win32con.HWND_TOPMOST,
                    0, 0, 0, 0,
                    win32con.SWP_NOMOVE | win32con.SWP_NOSIZE
                )
                print("✅ 窗口已置顶")
                return True
            else:
                print("⚠️ 无法找到当前窗口")
                return False
                
        except ImportError:
            print("⚠️ 请安装pywin32: pip install pywin32")
            return False
        except Exception as e:
            print(f"⚠️ 窗口置顶失败: {e}")
            return False


class GPUMonitor:
    """GPU监控器"""
    
    def __init__(self):
        self.has_gpu = self._check_gpu_availability()
        
    def _check_gpu_availability(self) -> bool:
        """检查GPU可用性"""
        try:
            import torch
            return torch.cuda.is_available()
        except ImportError:
            return False
            
    def get_gpu_utilization(self) -> float:
        """获取GPU利用率"""
        if not self.has_gpu:
            return 0.0
            
        try:
            import torch
            import pynvml
            
            pynvml.nvmlInit()
            handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            utilization = pynvml.nvmlDeviceGetUtilizationRates(handle)
            pynvml.nvmlShutdown()
            
            return utilization.gpu
        except ImportError:
            # 如果没有pynvml，使用torch的简单监控
            try:
                import torch
                if torch.cuda.is_available():
                    # 简单的GPU使用率估算
                    return 50.0  # 默认值
                return 0.0
            except:
                return 0.0
        except Exception:
            return 0.0
            
    def get_gpu_memory_usage(self) -> Dict[str, float]:
        """获取GPU内存使用情况"""
        if not self.has_gpu:
            return {"used": 0, "total": 0, "percent": 0}
            
        try:
            # 首先尝试使用pynvml获取准确的GPU内存信息
            import pynvml
            pynvml.nvmlInit()
            handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            
            # 获取内存信息
            memory_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
            used = memory_info.used / 1024**3  # GB
            total = memory_info.total / 1024**3  # GB
            percent = (used / total) * 100 if total > 0 else 0
            
            pynvml.nvmlShutdown()
            
            return {
                "used": used,
                "total": total,
                "percent": percent
            }
        except ImportError:
            # 如果没有pynvml，尝试使用torch
            try:
                import torch
                if torch.cuda.is_available():
                    allocated = torch.cuda.memory_allocated() / 1024**3  # GB
                    reserved = torch.cuda.memory_reserved() / 1024**3   # GB
                    total = torch.cuda.get_device_properties(0).total_memory / 1024**3
                    
                    # 使用已分配内存作为使用量
                    return {
                        "used": allocated,
                        "reserved": reserved,
                        "total": total,
                        "percent": (allocated / total) * 100 if total > 0 else 0
                    }
            except:
                pass
        except Exception:
            pass
            
        return {"used": 0, "total": 0, "percent": 0}


class ProcessManager:
    """进程管理器"""
    
    def __init__(self, max_processes: int = 4):
        self.max_processes = max_processes
        self.processes = []
        self.lock = threading.Lock()
        self._setup_logging()
        
    def _setup_logging(self):
        """设置日志系统 - 生产环境优化"""
        # 创建logs目录
        logs_dir = os.path.join(PROJECT_ROOT, "logs")
        os.makedirs(logs_dir, exist_ok=True)
        
        # 配置日志 - 生产环境使用 INFO 级别，减少调试信息
        log_file = os.path.join(logs_dir, f"multi_train_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
        
        logging.basicConfig(
            level=logging.INFO,  # 生产环境使用 INFO 级别
            format='%(asctime)s - %(levelname)s - [PID:%(process)d] - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        self.logger.info(f"进程管理器初始化完成，日志文件: {log_file}")
        
    def start_training_process(self, config_path: str = "configs/train_config.json") -> Optional[subprocess.Popen]:
        """启动一个训练进程 - 使用uv虚拟环境"""
        process_id = len(self.processes) + 1
        self.logger.info(f"🚀 开始启动训练进程 #{process_id}")
        
        try:
            # 检测虚拟环境路径
            venv_python = self._get_venv_python_path()
            if not venv_python:
                self.logger.error("❌ 无法找到虚拟环境Python解释器")
                return None
            
            # 构建命令 - 使用虚拟环境的Python解释器
            cmd = [
                venv_python,
                os.path.join(SCRIPT_DIR, "auto_train.py"),
                "--config", config_path
            ]
            
            self.logger.info(f"🔧 进程 #{process_id} 启动命令: {' '.join(cmd)}")
            self.logger.info(f"📁 工作目录: {PROJECT_ROOT}")
            self.logger.info(f"🐍 Python路径: {venv_python}")
            
            # 在Windows上使用新窗口启动进程
            if platform.system() == "Windows":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = 1  # SW_SHOWNORMAL - 正常显示窗口
                
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    universal_newlines=True,
                    startupinfo=startupinfo,
                    cwd=PROJECT_ROOT  # 设置工作目录
                )
            else:
                # Linux/macOS平台
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    universal_newlines=True,
                    cwd=PROJECT_ROOT  # 设置工作目录
                )
            
            self.logger.info(f"✅ 进程 #{process_id} 启动成功，PID: {process.pid}")
            
            # 启动输出监控线程
            output_thread = threading.Thread(
                target=self._monitor_process_output,
                args=(process, process_id),
                daemon=True
            )
            output_thread.start()
            
            # 验证进程是否成功启动
            time.sleep(2)  # 等待进程启动
            if process.poll() is not None:
                # 进程立即退出，读取错误信息
                stdout, stderr = process.communicate(timeout=5)
                self.logger.error(f"❌ 进程 #{process_id} 启动失败，退出码: {process.returncode}")
                self.logger.error(f"📄 标准输出: {stdout}")
                self.logger.error(f"❌ 错误输出: {stderr}")
                return None
            
            with self.lock:
                self.processes.append(process)
                
            self.logger.info(f"✅ 训练进程 #{process_id} 已添加到进程列表，PID: {process.pid}")
            return process
            
        except Exception as e:
            self.logger.error(f"❌ 启动训练进程 #{process_id} 失败: {e}")
            import traceback
            self.logger.error(f"📋 详细错误: {traceback.format_exc()}")
            return None
            
    def _monitor_process_output(self, process: subprocess.Popen, process_id: int):
        """监控进程输出 - 生产环境优化"""
        self.logger.info(f"开始监控进程 #{process_id} 的输出")
        
        try:
            while process.poll() is None:
                # 非阻塞读取标准输出 - 生产环境减少详细日志
                stdout_line = process.stdout.readline()
                if stdout_line:
                    stdout_line = stdout_line.strip()
                    # 只记录关键信息，减少详细输出
                    if stdout_line and any(keyword in stdout_line.lower() for keyword in 
                                          ['error', 'failed', 'exception', 'traceback', '模型保存', '训练完成']):
                        self.logger.info(f"进程 #{process_id} 关键输出: {stdout_line}")
                
                # 非阻塞读取错误输出 - 只记录真正的错误
                stderr_line = process.stderr.readline()
                if stderr_line:
                    stderr_line = stderr_line.strip()
                    if stderr_line and not any(ignore in stderr_line.lower() for ignore in 
                                             ['futurewarning', 'deprecationwarning']):
                        self.logger.warning(f"进程 #{process_id} 错误: {stderr_line}")
                
                time.sleep(0.1)  # 短暂休眠避免CPU占用过高
                
        except Exception as e:
            self.logger.error(f"监控进程 #{process_id} 输出时出错: {e}")
            
        # 进程结束时读取剩余输出
        try:
            stdout, stderr = process.communicate(timeout=1)
            if stdout:
                self.logger.info(f"进程 #{process_id} 最终输出: {stdout.strip()}")
            if stderr:
                self.logger.warning(f"进程 #{process_id} 最终错误: {stderr.strip()}")
        except:
            pass
            
        self.logger.info(f"进程 #{process_id} 输出监控结束，退出码: {process.returncode}")
            
    def _get_venv_python_path(self) -> Optional[str]:
        """获取虚拟环境Python解释器路径"""
        # 检查常见的虚拟环境路径
        venv_paths = [
            os.path.join(PROJECT_ROOT, ".venv", "Scripts", "python.exe"),  # Windows
            os.path.join(PROJECT_ROOT, ".venv", "bin", "python"),         # Linux/macOS
            os.path.join(PROJECT_ROOT, "venv", "Scripts", "python.exe"),  # Windows备用
            os.path.join(PROJECT_ROOT, "venv", "bin", "python"),          # Linux/macOS备用
        ]
        
        for venv_path in venv_paths:
            if os.path.exists(venv_path):
                print(f"✅ 找到虚拟环境Python: {venv_path}")
                return venv_path
        
        # 如果找不到虚拟环境，使用当前Python解释器
        print("⚠️ 未找到虚拟环境，使用当前Python解释器")
        return sys.executable
            
    def get_active_process_count(self) -> int:
        """获取活跃进程数量"""
        with self.lock:
            active_count = 0
            for process in self.processes[:]:  # 复制列表避免修改
                if process.poll() is None:  # 进程仍在运行
                    active_count += 1
                else:
                    # 移除已结束的进程
                    self.logger.warning(f"🛑 进程 PID:{process.pid} 已结束，退出码: {process.returncode}")
                    self.processes.remove(process)
            return active_count
            
    def check_process_health(self) -> Dict:
        """检查进程健康状态"""
        health_status = {
            "total_processes": len(self.processes),
            "active_processes": 0,
            "failed_processes": 0,
            "process_details": []
        }
        
        with self.lock:
            for i, process in enumerate(self.processes[:], 1):
                process_info = {
                    "process_id": i,
                    "pid": process.pid,
                    "status": "unknown"
                }
                
                try:
                    # 检查进程状态
                    if process.poll() is None:
                        process_info["status"] = "running"
                        health_status["active_processes"] += 1
                        
                        # 检查进程是否真的在运行（通过psutil）
                        try:
                            psutil_process = psutil.Process(process.pid)
                            process_info["cpu_percent"] = psutil_process.cpu_percent()
                            process_info["memory_mb"] = psutil_process.memory_info().rss / 1024 / 1024
                            process_info["create_time"] = datetime.fromtimestamp(psutil_process.create_time()).strftime('%H:%M:%S')
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            process_info["status"] = "zombie"
                            health_status["failed_processes"] += 1
                    else:
                        process_info["status"] = "exited"
                        process_info["exit_code"] = process.returncode
                        health_status["failed_processes"] += 1
                        self.logger.warning(f"❌ 进程 #{i} (PID:{process.pid}) 已退出，退出码: {process.returncode}")
                        
                except Exception as e:
                    process_info["status"] = "error"
                    process_info["error"] = str(e)
                    health_status["failed_processes"] += 1
                    self.logger.error(f"❌ 检查进程 #{i} 健康状态时出错: {e}")
                
                health_status["process_details"].append(process_info)
        
        # 记录健康状态
        if health_status["failed_processes"] > 0:
            self.logger.warning(f"⚠️ 进程健康检查: {health_status['active_processes']}活跃, {health_status['failed_processes']}失败")
        else:
            self.logger.info(f"✅ 进程健康检查: {health_status['active_processes']}活跃, 0失败")
            
        return health_status
            
    def get_process_details(self) -> List[Dict]:
        """获取进程详细信息"""
        process_details = []
        with self.lock:
            for process in self.processes:
                try:
                    pid = process.pid
                    status = "运行中" if process.poll() is None else "已结束"
                    
                    # 获取进程内存使用（如果可用）
                    memory_usage = 0
                    try:
                        proc = psutil.Process(pid)
                        memory_usage = proc.memory_info().rss / 1024 / 1024  # MB
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        memory_usage = 0
                    
                    process_details.append({
                        "pid": pid,
                        "status": status,
                        "memory_mb": memory_usage
                    })
                except:
                    continue
        return process_details
            
    def stop_all_processes(self):
        """停止所有进程"""
        with self.lock:
            for process in self.processes:
                try:
                    # 先尝试优雅终止
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        # 强制终止
                        process.kill()
                except:
                    pass
            self.processes.clear()


class ProgressTracker:
    """进度跟踪器"""
    
    def __init__(self, progress_file: str = "models/shared_progress.json"):
        self.progress_file = progress_file
        os.makedirs(os.path.dirname(progress_file), exist_ok=True)
        
    def get_current_iteration(self) -> int:
        """获取当前总迭代次数"""
        try:
            if os.path.exists(self.progress_file):
                with open(self.progress_file, 'r') as f:
                    progress_data = json.load(f)
                    return progress_data.get("total_iterations", 0)
        except (json.JSONDecodeError, KeyError):
            pass
        return 0
        
    def get_active_terminals(self) -> Dict:
        """获取活跃终端信息"""
        try:
            if os.path.exists(self.progress_file):
                with open(self.progress_file, 'r') as f:
                    progress_data = json.load(f)
                    return progress_data.get("terminals", {})
        except (json.JSONDecodeError, KeyError):
            pass
        return {}


class MultiTrainManager:
    """多开训练管理器"""
    
    def __init__(self, dingtalk_config: DingTalkConfig = None):
        self.window_manager = WindowManager()
        self.gpu_monitor = GPUMonitor()
        self.process_manager = ProcessManager()
        self.progress_tracker = ProgressTracker()
        
        # 钉钉通知器
        if dingtalk_config:
            self.notifier = TrainingNotifier(dingtalk_config)
        else:
            self.notifier = None
            
        # 训练状态
        self.target_iterations = 0
        self.start_time = 0
        self.is_running = False
        self.shutdown_requested = False
        
        # 设置信号处理
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
    def _signal_handler(self, signum, frame):
        """信号处理函数"""
        print(f"\n⚠️ 收到终止信号，正在优雅关闭...")
        self.shutdown_requested = True
        self.is_running = False
        
    def _get_user_input(self) -> bool:
        """获取用户输入"""
        print("\n" + "="*60)
        print("🚀 AI训练多开加速管理器")
        print("="*60)
        
        try:
            # 获取目标迭代次数
            while True:
                try:
                    iterations = input("🎯 请输入期望的迭代总数: ").strip()
                    if not iterations:
                        print("⚠️ 输入不能为空，请重新输入")
                        continue
                    
                    self.target_iterations = int(iterations)
                    if self.target_iterations <= 0:
                        print("⚠️ 迭代次数必须大于0，请重新输入")
                        continue
                    break
                except ValueError:
                    print("⚠️ 请输入有效的数字")
                    
            # 获取进程数量
            while True:
                try:
                    processes = input(f"💻 请输入并行进程数 (1-8, 推荐4): ").strip()
                    if not processes:
                        self.process_manager.max_processes = 4
                        break
                    
                    process_count = int(processes)
                    if 1 <= process_count <= 8:
                        self.process_manager.max_processes = process_count
                        break
                    else:
                        print("⚠️ 进程数必须在1-8之间")
                except ValueError:
                    print("⚠️ 请输入有效的数字")
                    
            # 确认开始
            confirm = input(f"✅ 确认开始训练？目标: {self.target_iterations}次迭代, 进程: {self.process_manager.max_processes}个 (y/N): ")
            return confirm.lower() in ['y', 'yes', '是']
            
        except KeyboardInterrupt:
            print("\n❌ 用户取消操作")
            return False
            
    def _display_status(self, current_iteration: int, active_processes: int):
        """显示状态信息"""
        elapsed_time = time.time() - self.start_time
        progress_percent = (current_iteration / self.target_iterations) * 100 if self.target_iterations > 0 else 0
        
        # 获取GPU信息
        gpu_utilization = self.gpu_monitor.get_gpu_utilization()
        gpu_memory = self.gpu_monitor.get_gpu_memory_usage()
        
        # 获取进程详细信息
        process_details = self.process_manager.get_process_details()
        
        # 清屏并显示状态
        os.system('cls' if platform.system() == 'Windows' else 'clear')
        
        print("="*80)
        print("🚀 AI训练多开加速管理器 - 实时监控")
        print("="*80)
        print(f"🎯 目标迭代: {self.target_iterations} | 📊 当前进度: {current_iteration} ({progress_percent:.1f}%)")
        print(f"💻 活跃进程: {active_processes}/{self.process_manager.max_processes} | ⏱️ 运行时间: {elapsed_time/60:.1f}分钟")
        print(f"🎮 GPU利用率: {gpu_utilization:.1f}% | 💾 GPU内存: {gpu_memory['percent']:.1f}% ({gpu_memory['used']:.1f}GB/{gpu_memory['total']:.1f}GB)")
        print("-"*80)
        
        # 显示进程详细信息
        if process_details:
            print("🔍 进程详细信息:")
            for proc in process_details:
                status_icon = "🟢" if proc["status"] == "运行中" else "🔴"
                print(f"  {status_icon} PID: {proc['pid']} | 状态: {proc['status']} | 内存: {proc['memory_mb']:.1f}MB")
        
        print("-"*80)
        
        # 显示活跃终端（改进状态检测）
        active_terminals = self.progress_tracker.get_active_terminals()
        if active_terminals:
            print("📡 训练终端状态:")
            for terminal_id, info in list(active_terminals.items())[:8]:  # 显示前8个
                last_update = datetime.fromisoformat(info['last_update'])
                age = (datetime.now() - last_update).total_seconds()
                
                # 改进状态判断逻辑
                if age < 30:
                    status = "🟢 活跃"
                elif age < 120:
                    status = "🟡 可能卡顿"
                else:
                    status = "🔴 离线"
                
                print(f"  - {terminal_id}: 迭代{info['current_iteration']} ({status}, {age:.0f}秒前更新)")
        
        print("-"*80)
        
        # 显示性能统计
        if current_iteration > 0 and elapsed_time > 0:
            speed = current_iteration / elapsed_time * 60  # 迭代/分钟
            estimated_total_time = (self.target_iterations / current_iteration) * elapsed_time if current_iteration > 0 else 0
            estimated_remaining = estimated_total_time - elapsed_time if estimated_total_time > elapsed_time else 0
            
            print(f"📈 性能统计: 速度 {speed:.1f} 迭代/分钟 | 预计剩余 {estimated_remaining/60:.1f} 分钟")
        
        print("-"*80)
        print("📋 操作提示: Ctrl+C 停止训练 | 窗口保持置顶显示 | 所有训练进程窗口可见")
        print("="*80)
        
    def run(self):
        """运行多开管理器"""
        # 设置窗口置顶
        self.window_manager.set_window_always_on_top()
        
        # 获取用户输入
        if not self._get_user_input():
            return
            
        # 发送开始通知
        if self.notifier:
            self.notifier.send_training_start_notification(
                self.target_iterations, 
                self.process_manager.max_processes
            )
            
        # 开始训练
        self.start_time = time.time()
        self.is_running = True
        
        print(f"\n🚀 开始多开训练...")
        print(f"🎯 目标: {self.target_iterations}次迭代")
        print(f"💻 进程: {self.process_manager.max_processes}个并行")
        print(f"⏰ 开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📊 监控频率: 每5秒更新")
        print(f"🔔 通知频率: 每10次迭代")
        
        # 启动初始进程
        for _ in range(self.process_manager.max_processes):
            self.process_manager.start_training_process()
            
        # 主监控循环
        last_notification_time = 0
        notification_interval = 300  # 5分钟
        
        try:
            health_check_counter = 0
            while self.is_running and not self.shutdown_requested:
                # 获取当前状态
                current_iteration = self.progress_tracker.get_current_iteration()
                active_processes = self.process_manager.get_active_process_count()
                elapsed_time = time.time() - self.start_time
                
                # 每30次循环执行一次健康检查（减少频率）
                health_check_counter += 1
                if health_check_counter >= 30:
                    health_status = self.process_manager.check_process_health()
                    health_check_counter = 0
                    
                    # 如果有失败的进程，记录详细信息
                    if health_status["failed_processes"] > 0:
                        print(f"⚠️ 检测到 {health_status['failed_processes']} 个进程失败，正在重新启动...")
                        # 重新启动失败的进程
                        needed = self.process_manager.max_processes - health_status["active_processes"]
                        for _ in range(needed):
                            self.process_manager.start_training_process()
                
                # 显示状态
                self._display_status(current_iteration, active_processes)
                
                # 检查是否完成
                if current_iteration >= self.target_iterations:
                    print(f"\n🎉 训练完成！达到目标迭代次数: {current_iteration}")
                    break
                    
                # 补充进程（如果有进程结束）
                if active_processes < self.process_manager.max_processes:
                    needed = self.process_manager.max_processes - active_processes
                    print(f"🔄 检测到 {needed} 个进程需要补充，正在启动...")
                    for _ in range(needed):
                        self.process_manager.start_training_process()
                        
                # 发送进度通知
                if self.notifier and time.time() - last_notification_time > notification_interval:
                    gpu_utilization = self.gpu_monitor.get_gpu_utilization()
                    self.notifier.send_progress_notification(
                        current_iteration, self.target_iterations,
                        active_processes, gpu_utilization, elapsed_time
                    )
                    last_notification_time = time.time()
                    
                # 等待下一次更新
                time.sleep(5)
                
        except KeyboardInterrupt:
            print(f"\n⚠️ 用户中断训练")
            
        finally:
            # 清理资源
            self.is_running = False
            print(f"\n🛑 正在停止所有训练进程...")
            self.process_manager.stop_all_processes()
            
            # 发送完成通知
            if self.notifier:
                final_iteration = self.progress_tracker.get_current_iteration()
                total_time = time.time() - self.start_time
                average_speed = final_iteration / total_time * 60 if total_time > 0 else 0
                
                self.notifier.send_completion_notification(
                    self.target_iterations, final_iteration, total_time, average_speed
                )
                
            print(f"✅ 多开训练管理器已停止")
            print(f"📊 最终统计:")
            print(f"  - 目标迭代: {self.target_iterations}")
            print(f"  - 完成迭代: {final_iteration}")
            print(f"  - 总用时: {total_time/60:.1f}分钟")
            print(f"  - 平均速度: {average_speed:.1f} 迭代/分钟")


def main():
    """主函数"""
    # 配置钉钉机器人（需要用户配置）
    dingtalk_config = DingTalkConfig(
        webhook_url="https://oapi.dingtalk.com/robot/send?access_token=63c4833051d2610078632691e60fb62b5200b46aa2408876f68afc413b1e0a49",  # 请配置您的钉钉机器人webhook
        # secret="",     # 如果需要加签，配置secret
        # access_token="" # 或者配置access_token
    )
    
    # 创建管理器
    manager = MultiTrainManager(dingtalk_config)
    
    # 运行管理器
    manager.run()


if __name__ == "__main__":
    main()
