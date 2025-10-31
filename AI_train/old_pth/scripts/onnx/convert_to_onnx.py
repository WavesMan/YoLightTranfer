# convert_to_onnx.py
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import torch
import torch.onnx
import numpy as np
from src.models.network_model import NetworkQualityModel
from src.utils.config import Config

def convert_pth_to_onnx():
    """
    将训练好的PyTorch模型转换为ONNX格式
    
    模型输入 (3个特征):
    - bandwidthMbps: 网络带宽 (Mbps), 范围: 0-200
    - avgDelayMs: 平均延迟 (毫秒), 范围: 0-500  
    - packetLossRate: 丢包率 (百分比), 范围: 0-20
    
    模型输出 (3个输出):
    - hotspot_probability: 热点推荐概率 (0.0-1.0)
    - quality_score: 网络质量评分 (0.0-1.0)
    - confidence: 模型置信度 (0.0-1.0)
    """
    # 加载配置
    config = Config()
    
    # 使用模型的load_model方法加载权重（处理包含model_state_dict和model_config的格式）
    model = NetworkQualityModel.load_model('checkpoints/best_model.pth')
    model.eval()
    
    # 创建真实数据范围的示例输入
    # 基于数据样本的真实范围创建示例输入
    # [带宽, 延迟, 丢包率]
    dummy_input = torch.tensor([[91.12, 49.92, 0.22]], dtype=torch.float32)  # batch_size=1, features=3
    
    # 转换为 ONNX 格式
    onnx_path = 'checkpoints/network_quality_model.onnx'
    
    torch.onnx.export(
        model,
        dummy_input,
        onnx_path,
        export_params=True,
        opset_version=9,  # 降低到版本9以兼容ONNX Runtime 1.4.1
        do_constant_folding=True,
        input_names=['network_features'],
        output_names=['hotspot_probability'],  # ONNX只支持单个输出名称
        dynamic_axes={
            'network_features': {0: 'batch_size'},
            'hotspot_probability': {0: 'batch_size'}
        },
        verbose=True
    )
    
    print(f"✅ 模型已成功转换为 ONNX 格式: {onnx_path}")
    print(f"📊 输入特征: bandwidthMbps, avgDelayMs, packetLossRate")
    print(f"📈 输出结果: hotspot_probability, quality_score, confidence")
    print(f"🔧 支持动态批次大小")

if __name__ == "__main__":
    convert_pth_to_onnx()
