"""
ONNX模型构建器
提供模型构建、保存、加载等功能
"""

import onnx
import onnxruntime as ort
import numpy as np
from typing import Dict, List, Optional
from pathlib import Path
from .network_quality_model import NetworkQualityONNXModel


class ONNXModelBuilder:
    """ONNX模型构建和管理器"""
    
    def __init__(self, model_config: Dict = None):
        """
        初始化模型构建器
        
        Args:
            model_config: 模型配置字典
        """
        self.model_config = model_config or {}
        self.model = None
        self.session = None
        
    def create_model(self, hidden_layers: List[int] = None) -> onnx.ModelProto:
        """
        创建新的ONNX模型
        
        Args:
            hidden_layers: 隐藏层配置
            
        Returns:
            ONNX模型原型
        """
        model_builder = NetworkQualityONNXModel(hidden_layers)
        self.model = model_builder.build_model()
        return self.model
    
    def save_model(self, filepath: str, optimized: bool = True):
        """
        保存模型到文件
        
        Args:
            filepath: 模型保存路径
            optimized: 是否进行模型优化
        """
        if self.model is None:
            raise ValueError("没有可保存的模型，请先创建模型")
        
        # 确保目录存在
        Path(filepath).parent.mkdir(parents=True, exist_ok=True)
        
        if optimized:
            # 简单的模型优化
            optimized_model = self._optimize_model(self.model)
            onnx.save(optimized_model, filepath)
        else:
            onnx.save(self.model, filepath)
        
        print(f"模型已保存到: {filepath}")
    
    def load_model(self, filepath: str) -> ort.InferenceSession:
        """
        加载模型并创建推理会话
        
        Args:
            filepath: 模型文件路径
            
        Returns:
            ONNX Runtime推理会话
        """
        if not Path(filepath).exists():
            raise FileNotFoundError(f"模型文件不存在: {filepath}")
        
        # 创建推理会话
        providers = ['CPUExecutionProvider']
        if ort.get_device() == 'GPU':
            providers = ['CUDAExecutionProvider'] + providers
        
        self.session = ort.InferenceSession(filepath, providers=providers)
        return self.session
    
    def create_training_model(self, model_name: str = "network_quality_training_model") -> onnx.ModelProto:
        """
        创建用于训练的ONNX模型（包含梯度计算）
        
        Args:
            model_name: 模型名称
            
        Returns:
            训练用ONNX模型
        """
        # 这里可以扩展为包含训练操作的模型
        # 目前返回基础模型
        return self.create_model()
    
    def get_model_info(self) -> Dict:
        """
        获取模型信息
        
        Returns:
            模型信息字典
        """
        if self.model is None:
            return {}
        
        info = {
            'input_shape': None,
            'output_shape': None,
            'nodes_count': len(self.model.graph.node),
            'parameters_count': self._count_parameters()
        }
        
        # 获取输入输出形状
        for input_info in self.model.graph.input:
            if input_info.name == 'input':
                dims = [dim.dim_value for dim in input_info.type.tensor_type.shape.dim]
                info['input_shape'] = dims
        
        for output_info in self.model.graph.output:
            if output_info.name == 'output':
                dims = [dim.dim_value for dim in output_info.type.tensor_type.shape.dim]
                info['output_shape'] = dims
        
        return info
    
    def _optimize_model(self, model: onnx.ModelProto) -> onnx.ModelProto:
        """
        简单的模型优化
        
        Args:
            model: 原始模型
            
        Returns:
            优化后的模型
        """
        # 这里可以实现更复杂的优化逻辑
        # 目前返回原始模型
        return model
    
    def _count_parameters(self) -> int:
        """
        计算模型参数数量
        
        Returns:
            参数总数
        """
        if self.model is None:
            return 0
        
        total_params = 0
        for initializer in self.model.graph.initializer:
            shape = initializer.dims
            params = np.prod(shape)
            total_params += params
        
        return total_params
    
    def inference(self, input_data: np.ndarray) -> np.ndarray:
        """
        使用加载的模型进行推理
        
        Args:
            input_data: 输入数据
            
        Returns:
            推理结果
        """
        if self.session is None:
            raise ValueError("模型会话未初始化，请先加载模型")
        
        # 确保输入数据格式正确
        if input_data.ndim == 1:
            input_data = input_data.reshape(1, -1)
        
        # 执行推理
        input_name = self.session.get_inputs()[0].name
        output_name = self.session.get_outputs()[0].name
        
        result = self.session.run([output_name], {input_name: input_data.astype(np.float32)})
        return result[0]
    
    def validate_model(self, test_input: np.ndarray = None) -> bool:
        """
        验证模型功能
        
        Args:
            test_input: 测试输入数据
            
        Returns:
            验证是否成功
        """
        try:
            if test_input is None:
                # 生成随机测试数据
                test_input = np.random.randn(10, 3).astype(np.float32)
            
            # 尝试推理
            output = self.inference(test_input)
            
            # 检查输出形状
            expected_shape = (test_input.shape[0], 3)  # [batch_size, 3_outputs]
            if output.shape != expected_shape:
                print(f"输出形状错误: 期望 {expected_shape}, 实际 {output.shape}")
                return False
            
            # 检查输出范围 (应该在0-1之间)
            if np.any(output < 0) or np.any(output > 1):
                print("输出值超出预期范围 [0, 1]")
                return False
            
            print("模型验证成功!")
            return True
            
        except Exception as e:
            print(f"模型验证失败: {e}")
            return False


# 便捷函数
def create_default_model() -> ONNXModelBuilder:
    """创建默认配置的模型构建器"""
    return ONNXModelBuilder()


def load_existing_model(filepath: str) -> ONNXModelBuilder:
    """加载现有模型文件"""
    builder = ONNXModelBuilder()
    builder.load_model(filepath)
    return builder


if __name__ == "__main__":
    # 测试模型构建器
    print("测试ONNX模型构建器...")
    
    # 创建模型
    builder = ONNXModelBuilder()
    model = builder.create_model([64, 32, 16])
    
    # 获取模型信息
    info = builder.get_model_info()
    print("模型信息:")
    for key, value in info.items():
        print(f"  {key}: {value}")
    
    # 保存模型
    builder.save_model("test_model.onnx")
    
    # 加载模型
    session = builder.load_model("test_model.onnx")
    print("模型加载成功!")
    
    # 验证模型
    test_data = np.random.randn(5, 3).astype(np.float32)
    builder.validate_model(test_data)
    
    # 测试推理
    result = builder.inference(test_data)
    print(f"推理结果形状: {result.shape}")
    print(f"推理结果示例: {result[0]}")
