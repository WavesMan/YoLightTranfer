"""
网络质量ONNX原生模型
输入: [bandwidthMbps, avgDelayMs, packetLossRate]
输出: [hotspot_probability, quality_score, confidence]
"""

import onnx
import onnx.helper as helper
import onnx.numpy_helper as numpy_helper
import numpy as np
from typing import List, Dict, Any


class NetworkQualityONNXModel:
    """网络质量分析ONNX原生模型"""
    
    def __init__(self, hidden_layers: List[int] = None):
        """
        初始化模型
        
        Args:
            hidden_layers: 隐藏层大小列表，默认为[64, 32, 16]
        """
        self.input_size = 3  # 输入特征数
        self.output_size = 3  # 输出目标数
        self.hidden_layers = hidden_layers or [64, 32, 16]
        
        # 模型参数
        self.weights = {}
        self.biases = {}
        
    def build_model(self, model_name: str = "network_quality_model") -> onnx.ModelProto:
        """
        构建ONNX模型图
        
        Args:
            model_name: 模型名称
            
        Returns:
            ONNX模型原型
        """
        # 创建输入节点
        input_tensor = helper.make_tensor_value_info(
            'input', 
            onnx.TensorProto.FLOAT, 
            [None, self.input_size]
        )
        
        # 创建输出节点
        output_tensor = helper.make_tensor_value_info(
            'output',
            onnx.TensorProto.FLOAT,
            [None, self.output_size]
        )
        
        # 构建网络层
        nodes = []
        current_input = 'input'
        
        # 构建隐藏层
        for i, hidden_size in enumerate(self.hidden_layers):
            # 线性层
            weight_name = f'weight_{i}'
            bias_name = f'bias_{i}'
            linear_output = f'linear_{i}'
            
            # 创建权重和偏置
            weight_value = np.random.randn(self.input_size if i == 0 else self.hidden_layers[i-1], 
                                         hidden_size).astype(np.float32)
            bias_value = np.zeros(hidden_size).astype(np.float32)
            
            # 添加权重和偏置节点
            weight_initializer = numpy_helper.from_array(weight_value, weight_name)
            bias_initializer = numpy_helper.from_array(bias_value, bias_name)
            
            # 线性变换节点
            linear_node = helper.make_node(
                'Gemm',
                inputs=[current_input, weight_name, bias_name],
                outputs=[linear_output],
                name=f'linear_{i}'
            )
            nodes.append(linear_node)
            
            # ReLU激活函数
            if i < len(self.hidden_layers) - 1:  # 最后一层不加激活函数
                relu_output = f'relu_{i}'
                relu_node = helper.make_node(
                    'Relu',
                    inputs=[linear_output],
                    outputs=[relu_output],
                    name=f'relu_{i}'
                )
                nodes.append(relu_node)
                current_input = relu_output
            else:
                current_input = linear_output
        
        # 输出层 - 三个独立的分支
        output_nodes = []
        
        # 热点推荐概率输出 (sigmoid)
        hotspot_weight = np.random.randn(self.hidden_layers[-1], 1).astype(np.float32)
        hotspot_bias = np.zeros(1).astype(np.float32)
        
        hotspot_weight_initializer = numpy_helper.from_array(hotspot_weight, 'hotspot_weight')
        hotspot_bias_initializer = numpy_helper.from_array(hotspot_bias, 'hotspot_bias')
        
        hotspot_linear = helper.make_node(
            'Gemm',
            inputs=[current_input, 'hotspot_weight', 'hotspot_bias'],
            outputs=['hotspot_linear'],
            name='hotspot_linear'
        )
        nodes.append(hotspot_linear)
        
        hotspot_sigmoid = helper.make_node(
            'Sigmoid',
            inputs=['hotspot_linear'],
            outputs=['hotspot_probability'],
            name='hotspot_sigmoid'
        )
        nodes.append(hotspot_sigmoid)
        
        # 质量评分输出 (sigmoid)
        quality_weight = np.random.randn(self.hidden_layers[-1], 1).astype(np.float32)
        quality_bias = np.zeros(1).astype(np.float32)
        
        quality_weight_initializer = numpy_helper.from_array(quality_weight, 'quality_weight')
        quality_bias_initializer = numpy_helper.from_array(quality_bias, 'quality_bias')
        
        quality_linear = helper.make_node(
            'Gemm',
            inputs=[current_input, 'quality_weight', 'quality_bias'],
            outputs=['quality_linear'],
            name='quality_linear'
        )
        nodes.append(quality_linear)
        
        quality_sigmoid = helper.make_node(
            'Sigmoid',
            inputs=['quality_linear'],
            outputs=['quality_score'],
            name='quality_sigmoid'
        )
        nodes.append(quality_sigmoid)
        
        # 置信度输出 (sigmoid)
        confidence_weight = np.random.randn(self.hidden_layers[-1], 1).astype(np.float32)
        confidence_bias = np.zeros(1).astype(np.float32)
        
        confidence_weight_initializer = numpy_helper.from_array(confidence_weight, 'confidence_weight')
        confidence_bias_initializer = numpy_helper.from_array(confidence_bias, 'confidence_bias')
        
        confidence_linear = helper.make_node(
            'Gemm',
            inputs=[current_input, 'confidence_weight', 'confidence_bias'],
            outputs=['confidence_linear'],
            name='confidence_linear'
        )
        nodes.append(confidence_linear)
        
        confidence_sigmoid = helper.make_node(
            'Sigmoid',
            inputs=['confidence_linear'],
            outputs=['confidence'],
            name='confidence_sigmoid'
        )
        nodes.append(confidence_sigmoid)
        
        # 合并输出
        concat_node = helper.make_node(
            'Concat',
            inputs=['hotspot_probability', 'quality_score', 'confidence'],
            outputs=['output'],
            name='output_concat',
            axis=1
        )
        nodes.append(concat_node)
        
        # 收集所有初始器
        initializers = []
        for i, hidden_size in enumerate(self.hidden_layers):
            weight_name = f'weight_{i}'
            bias_name = f'bias_{i}'
            weight_value = np.random.randn(self.input_size if i == 0 else self.hidden_layers[i-1], 
                                         hidden_size).astype(np.float32)
            bias_value = np.zeros(hidden_size).astype(np.float32)
            
            initializers.append(numpy_helper.from_array(weight_value, weight_name))
            initializers.append(numpy_helper.from_array(bias_value, bias_name))
        
        # 添加输出层初始器
        initializers.extend([
            hotspot_weight_initializer, hotspot_bias_initializer,
            quality_weight_initializer, quality_bias_initializer,
            confidence_weight_initializer, confidence_bias_initializer
        ])
        
        # 创建模型
        graph = helper.make_graph(
            nodes=nodes,
            name=model_name,
            inputs=[input_tensor],
            outputs=[output_tensor],
            initializer=initializers
        )
        
        model = helper.make_model(
            graph,
            producer_name='network-quality-trainer',
            opset_imports=[helper.make_opsetid("", 13)]
        )
        
        return model
    
    def get_model_parameters(self) -> Dict[str, np.ndarray]:
        """获取模型参数"""
        return {**self.weights, **self.biases}
    
    def set_model_parameters(self, parameters: Dict[str, np.ndarray]):
        """设置模型参数"""
        self.weights = {k: v for k, v in parameters.items() if k.startswith('weight')}
        self.biases = {k: v for k, v in parameters.items() if k.startswith('bias')}


if __name__ == "__main__":
    # 测试模型构建
    model_builder = NetworkQualityONNXModel()
    onnx_model = model_builder.build_model()
    
    print("ONNX模型构建成功!")
    print(f"输入维度: {model_builder.input_size}")
    print(f"输出维度: {model_builder.output_size}")
    print(f"隐藏层: {model_builder.hidden_layers}")
    
    # 保存测试模型
    onnx.save(onnx_model, "test_network_quality_model.onnx")
    print("测试模型已保存为 'test_network_quality_model.onnx'")
