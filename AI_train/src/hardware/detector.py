"""
硬件探测器
自动检测系统硬件配置
"""

import platform
import psutil
import os
from typing import Dict, Any
import subprocess
import sys


class HardwareDetector:
    """硬件配置探测器"""
    
    def __init__(self):
        self.cached_hardware_info = None
    
    def detect_hardware(self, use_cache: bool = True) -> Dict[str, Any]:
        """
        检测系统硬件配置
        
        Args:
            use_cache: 是否使用缓存结果
            
        Returns:
            硬件信息字典
        """
        if use_cache and self.cached_hardware_info is not None:
            return self.cached_hardware_info
        
        hardware_info = {
            'gpu': self._detect_gpu(),
            'cpu': self._detect_cpu(),
            'memory': self._detect_memory(),
            'system': self._detect_system(),
            'python': self._detect_python()
        }
        
        self.cached_hardware_info = hardware_info
        return hardware_info
    
    def _detect_gpu(self) -> Dict[str, Any]:
        """检测GPU信息"""
        gpu_info = {
            'available': False,
            'name': 'Unknown',
            'memory_gb': 0,
            'compute_capability': (0, 0),
            'cuda_cores': 0,
            'driver_version': 'Unknown'
        }
        
        try:
            # 尝试检测NVIDIA GPU
            import torch
            if torch.cuda.is_available():
                gpu_info['available'] = True
                gpu_info['name'] = torch.cuda.get_device_name(0)
                gpu_info['memory_gb'] = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                gpu_info['compute_capability'] = torch.cuda.get_device_capability(0)
                gpu_info['cuda_cores'] = self._estimate_cuda_cores(gpu_info['compute_capability'])
                gpu_info['driver_version'] = torch.version.cuda or 'Unknown'
                
        except ImportError:
            # 如果没有安装PyTorch，尝试其他方法
            pass
        
        except Exception as e:
            print(f"GPU检测失败: {e}")
        
        return gpu_info
    
    def _detect_cpu(self) -> Dict[str, Any]:
        """检测CPU信息"""
        cpu_info = {
            'physical_cores': psutil.cpu_count(logical=False),
            'logical_cores': psutil.cpu_count(logical=True),
            'max_frequency': psutil.cpu_freq().max if psutil.cpu_freq() else 0,
            'architecture': platform.machine(),
            'vendor': self._get_cpu_vendor()
        }
        return cpu_info
    
    def _detect_memory(self) -> Dict[str, Any]:
        """检测内存信息"""
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        memory_info = {
            'total_gb': memory.total / (1024**3),
            'available_gb': memory.available / (1024**3),
            'swap_total_gb': swap.total / (1024**3),
            'swap_used_gb': swap.used / (1024**3)
        }
        return memory_info
    
    def _detect_system(self) -> Dict[str, Any]:
        """检测系统信息"""
        system_info = {
            'platform': platform.system(),
            'platform_release': platform.release(),
            'platform_version': platform.version(),
            'architecture': platform.architecture()[0],
            'hostname': platform.node()
        }
        return system_info
    
    def _detect_python(self) -> Dict[str, Any]:
        """检测Python环境信息"""
        python_info = {
            'version': platform.python_version(),
            'implementation': platform.python_implementation(),
            'compiler': platform.python_compiler(),
            'executable': sys.executable
        }
        return python_info
    
    def _estimate_cuda_cores(self, compute_capability: tuple) -> int:
        """根据计算能力估算CUDA核心数"""
        # 简化的估算方法
        capability_map = {
            (2, 0): 32,   # Fermi
            (2, 1): 48,
            (3, 0): 192,  # Kepler
            (3, 5): 192,
            (3, 7): 192,
            (5, 0): 128,  # Maxwell
            (5, 2): 128,
            (6, 0): 64,   # Pascal
            (6, 1): 128,
            (7, 0): 64,   # Volta
            (7, 5): 64,
            (8, 0): 64,   # Ampere
            (8, 6): 128,
            (8, 9): 128,  # Ada Lovelace
            (9, 0): 128   # Hopper
        }
        
        return capability_map.get(compute_capability, 128)
    
    def _get_cpu_vendor(self) -> str:
        """获取CPU厂商信息"""
        try:
            if platform.system() == "Windows":
                return self._get_windows_cpu_vendor()
            elif platform.system() == "Linux":
                return self._get_linux_cpu_vendor()
            elif platform.system() == "Darwin":
                return self._get_macos_cpu_vendor()
            else:
                return "Unknown"
        except:
            return "Unknown"
    
    def _get_windows_cpu_vendor(self) -> str:
        """Windows系统获取CPU厂商"""
        try:
            output = subprocess.check_output(
                "wmic cpu get name", 
                shell=True, 
                text=True
            )
            if "Intel" in output:
                return "Intel"
            elif "AMD" in output:
                return "AMD"
        except:
            pass
        return "Unknown"
    
    def _get_linux_cpu_vendor(self) -> str:
        """Linux系统获取CPU厂商"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                if "GenuineIntel" in cpuinfo:
                    return "Intel"
                elif "AuthenticAMD" in cpuinfo:
                    return "AMD"
        except:
            pass
        return "Unknown"
    
    def _get_macos_cpu_vendor(self) -> str:
        """macOS系统获取CPU厂商"""
        try:
            output = subprocess.check_output(
                "sysctl -n machdep.cpu.brand_string", 
                shell=True, 
                text=True
            )
            if "Intel" in output:
                return "Intel"
            elif "Apple" in output:
                return "Apple Silicon"
        except:
            pass
        return "Unknown"
    
    def get_hardware_summary(self) -> str:
        """获取硬件配置摘要"""
        hardware = self.detect_hardware()
        
        summary = []
        summary.append("=== 硬件配置摘要 ===")
        
        # GPU信息
        gpu = hardware['gpu']
        if gpu['available']:
            summary.append(f"GPU: {gpu['name']}")
            summary.append(f"  显存: {gpu['memory_gb']:.1f} GB")
            summary.append(f"  计算能力: {gpu['compute_capability']}")
            summary.append(f"  驱动版本: {gpu['driver_version']}")
        else:
            summary.append("GPU: 不可用")
        
        # CPU信息
        cpu = hardware['cpu']
        summary.append(f"CPU: {cpu['vendor']} ({cpu['physical_cores']}物理核心/{cpu['logical_cores']}逻辑核心)")
        if cpu['max_frequency'] > 0:
            summary.append(f"  最大频率: {cpu['max_frequency']:.1f} MHz")
        
        # 内存信息
        memory = hardware['memory']
        summary.append(f"内存: {memory['total_gb']:.1f} GB (可用: {memory['available_gb']:.1f} GB)")
        
        # 系统信息
        system = hardware['system']
        summary.append(f"系统: {system['platform']} {system['platform_release']} ({system['architecture']})")
        
        # Python信息
        python_info = hardware['python']
        summary.append(f"Python: {python_info['version']} ({python_info['implementation']})")
        
        return "\n".join(summary)
    
    def is_gpu_available(self) -> bool:
        """检查GPU是否可用"""
        hardware = self.detect_hardware()
        return hardware['gpu']['available']
    
    def get_available_memory_gb(self) -> float:
        """获取可用内存(GB)"""
        hardware = self.detect_hardware()
        return hardware['memory']['available_gb']
    
    def get_gpu_memory_gb(self) -> float:
        """获取GPU显存(GB)"""
        hardware = self.detect_hardware()
        return hardware['gpu']['memory_gb']


if __name__ == "__main__":
    # 测试硬件探测器
    detector = HardwareDetector()
    hardware_info = detector.detect_hardware()
    
    print("硬件检测结果:")
    print(detector.get_hardware_summary())
    
    print("\n详细硬件信息:")
    import json
    print(json.dumps(hardware_info, indent=2, default=str))
