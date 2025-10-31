"""
性能基准测试模块
测试硬件性能并生成基准数据
"""

import time
import numpy as np
from typing import Dict, Any, List
import psutil
from .detector import HardwareDetector


class PerformanceBenchmark:
    """性能基准测试器"""
    
    def __init__(self, hardware_detector: HardwareDetector = None):
        """
        初始化性能基准测试器
        
        Args:
            hardware_detector: 硬件探测器实例
        """
        self.hardware_detector = hardware_detector or HardwareDetector()
        self.benchmark_results = {}
        
    def run_comprehensive_benchmark(self, warmup_iterations: int = 10, test_iterations: int = 100) -> Dict[str, Any]:
        """
        运行全面的性能基准测试
        
        Args:
            warmup_iterations: 预热迭代次数
            test_iterations: 测试迭代次数
            
        Returns:
            基准测试结果字典
        """
        print("开始性能基准测试...")
        
        benchmark_results = {
            'cpu_performance': self._benchmark_cpu(warmup_iterations, test_iterations),
            'memory_performance': self._benchmark_memory(warmup_iterations, test_iterations),
            'matrix_operations': self._benchmark_matrix_operations(warmup_iterations, test_iterations),
            'inference_performance': self._benchmark_inference(warmup_iterations, test_iterations),
            'hardware_info': self.hardware_detector.detect_hardware()
        }
        
        # 计算综合性能评分
        benchmark_results['overall_score'] = self._calculate_overall_score(benchmark_results)
        
        self.benchmark_results = benchmark_results
        return benchmark_results
    
    def _benchmark_cpu(self, warmup_iterations: int, test_iterations: int) -> Dict[str, Any]:
        """CPU性能基准测试"""
        print("运行CPU基准测试...")
        
        # 单线程性能测试
        def fibonacci(n):
            if n <= 1:
                return n
            return fibonacci(n-1) + fibonacci(n-2)
        
        # 预热
        for _ in range(warmup_iterations):
            fibonacci(20)
        
        # 测试
        start_time = time.time()
        for _ in range(test_iterations):
            fibonacci(20)
        single_thread_time = time.time() - start_time
        
        # 多线程性能测试 (使用numpy)
        matrix_size = 1000
        a = np.random.rand(matrix_size, matrix_size)
        b = np.random.rand(matrix_size, matrix_size)
        
        start_time = time.time()
        for _ in range(test_iterations // 10):  # 减少迭代次数
            np.dot(a, b)
        multi_thread_time = time.time() - start_time
        
        return {
            'single_thread_performance': 1.0 / single_thread_time,  # 性能评分 (越高越好)
            'multi_thread_performance': 1.0 / multi_thread_time,
            'single_thread_time_seconds': single_thread_time,
            'multi_thread_time_seconds': multi_thread_time,
            'cpu_utilization': psutil.cpu_percent(interval=1)
        }
    
    def _benchmark_memory(self, warmup_iterations: int, test_iterations: int) -> Dict[str, Any]:
        """内存性能基准测试"""
        print("运行内存基准测试...")
        
        # 内存读写速度测试
        data_size = 1000000  # 1百万个浮点数
        data = np.random.rand(data_size).astype(np.float32)
        
        # 预热
        for _ in range(warmup_iterations):
            _ = data.copy()
        
        # 内存复制测试
        start_time = time.time()
        for _ in range(test_iterations):
            copied_data = data.copy()
        copy_time = time.time() - start_time
        
        # 内存访问测试
        start_time = time.time()
        for _ in range(test_iterations):
            _ = np.sum(data)
        access_time = time.time() - start_time
        
        return {
            'memory_copy_speed_mb_per_sec': (data_size * 4 * test_iterations) / (copy_time * 1024 * 1024),  # MB/s
            'memory_access_speed_mb_per_sec': (data_size * 4 * test_iterations) / (access_time * 1024 * 1024),
            'copy_time_seconds': copy_time,
            'access_time_seconds': access_time,
            'available_memory_gb': psutil.virtual_memory().available / (1024**3)
        }
    
    def _benchmark_matrix_operations(self, warmup_iterations: int, test_iterations: int) -> Dict[str, Any]:
        """矩阵运算性能基准测试"""
        print("运行矩阵运算基准测试...")
        
        # 不同大小的矩阵运算测试
        sizes = [100, 500, 1000]
        results = {}
        
        for size in sizes:
            a = np.random.rand(size, size).astype(np.float32)
            b = np.random.rand(size, size).astype(np.float32)
            
            # 预热
            for _ in range(warmup_iterations):
                np.dot(a, b)
            
            # 测试矩阵乘法
            start_time = time.time()
            for _ in range(test_iterations // (size // 100 + 1)):  # 根据矩阵大小调整迭代次数
                np.dot(a, b)
            matmul_time = time.time() - start_time
            
            # 测试矩阵转置
            start_time = time.time()
            for _ in range(test_iterations * 2):
                a.T
            transpose_time = time.time() - start_time
            
            results[f'matrix_{size}x{size}'] = {
                'matmul_operations_per_second': (test_iterations // (size // 100 + 1)) / matmul_time,
                'transpose_operations_per_second': (test_iterations * 2) / transpose_time,
                'matmul_time_seconds': matmul_time,
                'transpose_time_seconds': transpose_time
            }
        
        return results
    
    def _benchmark_inference(self, warmup_iterations: int, test_iterations: int) -> Dict[str, Any]:
        """推理性能基准测试"""
        print("运行推理性能基准测试...")
        
        try:
            import onnxruntime as ort
            
            # 创建一个简单的ONNX模型进行测试
            input_size = 10
            hidden_size = 64
            output_size = 3
            
            # 模拟推理过程
            def simulate_inference(batch_size):
                # 模拟输入数据
                inputs = np.random.randn(batch_size, input_size).astype(np.float32)
                
                # 模拟神经网络前向传播
                hidden = np.tanh(np.dot(inputs, np.random.randn(input_size, hidden_size)))
                outputs = np.dot(hidden, np.random.randn(hidden_size, output_size))
                
                return outputs
            
            # 测试不同批次大小的推理性能
            batch_sizes = [1, 16, 64, 256]
            results = {}
            
            for batch_size in batch_sizes:
                # 预热
                for _ in range(warmup_iterations):
                    simulate_inference(batch_size)
                
                # 测试
                start_time = time.time()
                for _ in range(test_iterations):
                    simulate_inference(batch_size)
                inference_time = time.time() - start_time
                
                results[f'batch_size_{batch_size}'] = {
                    'inferences_per_second': test_iterations / inference_time,
                    'inference_time_seconds': inference_time,
                    'throughput_samples_per_second': (batch_size * test_iterations) / inference_time
                }
            
            return results
            
        except ImportError:
            print("ONNX Runtime未安装，跳过推理基准测试")
            return {'status': 'onnx_runtime_not_available'}
    
    def _calculate_overall_score(self, benchmark_results: Dict[str, Any]) -> float:
        """计算综合性能评分"""
        scores = []
        
        # CPU性能评分
        cpu_perf = benchmark_results['cpu_performance']
        scores.append(cpu_perf['single_thread_performance'] * 0.3)
        scores.append(cpu_perf['multi_thread_performance'] * 0.4)
        
        # 内存性能评分
        memory_perf = benchmark_results['memory_performance']
        scores.append(memory_perf['memory_copy_speed_mb_per_sec'] * 0.1)
        scores.append(memory_perf['memory_access_speed_mb_per_sec'] * 0.1)
        
        # 矩阵运算评分
        matrix_perf = benchmark_results['matrix_operations']
        for size_key in matrix_perf:
            if '100x100' in size_key:
                scores.append(matrix_perf[size_key]['matmul_operations_per_second'] * 0.05)
                scores.append(matrix_perf[size_key]['transpose_operations_per_second'] * 0.05)
        
        # 归一化评分 (0-100分)
        max_possible_score = 100.0
        overall_score = sum(scores) / len(scores) if scores else 0
        normalized_score = min(overall_score * 10, max_possible_score)  # 缩放因子
        
        return normalized_score
    
    def get_performance_recommendations(self) -> List[str]:
        """根据基准测试结果生成性能优化建议"""
        recommendations = []
        
        if not self.benchmark_results:
            return ["请先运行基准测试"]
        
        hardware_info = self.benchmark_results['hardware_info']
        overall_score = self.benchmark_results['overall_score']
        
        # 根据综合评分给出建议
        if overall_score < 30:
            recommendations.append("系统性能较低，建议升级硬件或优化软件配置")
        elif overall_score < 60:
            recommendations.append("系统性能中等，可考虑优化训练参数")
        else:
            recommendations.append("系统性能良好，适合进行大规模训练")
        
        # CPU相关建议
        cpu_info = hardware_info['cpu']
        if cpu_info['logical_cores'] <= 4:
            recommendations.append("CPU核心数较少，建议使用较小的批次大小")
        
        # 内存相关建议
        memory_info = hardware_info['memory']
        if memory_info['available_gb'] < 4:
            recommendations.append("可用内存较少，建议使用内存优化的训练策略")
        
        # GPU相关建议
        gpu_info = hardware_info['gpu']
        if gpu_info['available']:
            if gpu_info['memory_gb'] < 4:
                recommendations.append("GPU显存较小，建议使用混合精度训练和梯度累积")
            if gpu_info['compute_capability'] < (6, 0):
                recommendations.append("GPU计算能力较低，建议使用float32精度")
        else:
            recommendations.append("未检测到GPU，训练将在CPU上进行，性能可能受限")
        
        return recommendations
    
    def generate_benchmark_report(self) -> str:
        """生成基准测试报告"""
        if not self.benchmark_results:
            return "请先运行基准测试"
        
        report = []
        report.append("=== 性能基准测试报告 ===")
        report.append("")
        
        # 硬件信息
        hardware_info = self.benchmark_results['hardware_info']
        report.append("硬件配置:")
        report.append(f"  CPU: {hardware_info['cpu']['vendor']} ({hardware_info['cpu']['logical_cores']}核心)")
        if hardware_info['gpu']['available']:
            report.append(f"  GPU: {hardware_info['gpu']['name']} ({hardware_info['gpu']['memory_gb']:.1f}GB)")
        else:
            report.append("  GPU: 不可用")
        report.append(f"  内存: {hardware_info['memory']['total_gb']:.1f}GB")
        report.append("")
        
        # 性能评分
        report.append(f"综合性能评分: {self.benchmark_results['overall_score']:.1f}/100")
        report.append("")
        
        # 详细性能数据
        cpu_perf = self.benchmark_results['cpu_performance']
        report.append("CPU性能:")
        report.append(f"  单线程性能: {cpu_perf['single_thread_performance']:.2f} ops/sec")
        report.append(f"  多线程性能: {cpu_perf['multi_thread_performance']:.2f} ops/sec")
        report.append("")
        
        memory_perf = self.benchmark_results['memory_performance']
        report.append("内存性能:")
        report.append(f"  复制速度: {memory_perf['memory_copy_speed_mb_per_sec']:.2f} MB/s")
        report.append(f"  访问速度: {memory_perf['memory_access_speed_mb_per_sec']:.2f} MB/s")
        report.append("")
        
        # 优化建议
        recommendations = self.get_performance_recommendations()
        report.append("优化建议:")
        for i, rec in enumerate(recommendations, 1):
            report.append(f"  {i}. {rec}")
        
        return "\n".join(report)


if __name__ == "__main__":
    # 测试性能基准测试
    print("开始性能基准测试...")
    
    benchmark = PerformanceBenchmark()
    results = benchmark.run_comprehensive_benchmark(warmup_iterations=5, test_iterations=50)
    
    print("\n基准测试完成!")
    print(benchmark.generate_benchmark_report())
