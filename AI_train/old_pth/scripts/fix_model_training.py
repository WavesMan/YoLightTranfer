# language: python
import os
import sys
import torch
import numpy as np

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.models.network_model import NetworkQualityModel
from src.utils.config import Config

def fix_model_initialization():
    """修复模型初始化问题"""
    print("🔧 修复模型初始化问题...")
    
    cfg = Config("configs/train_config.json")
    
    # 创建新模型
    model = NetworkQualityModel(
        input_size=cfg.model.input_size,
        hidden_sizes=tuple(cfg.model.hidden_sizes),
        dropout_rate=cfg.model.dropout_rate,
        use_batch_norm=cfg.model.use_batch_norm
    )
    
    # 检查当前初始化
    print("\n📊 当前参数初始化状态:")
    for name, param in model.named_parameters():
        if 'bias' in name:
            print(f"  {name}: mean={param.data.mean():.6f}, std={param.data.std():.6f}")
    
    # 重新初始化偏置参数
    print("\n🔄 重新初始化偏置参数...")
    for name, param in model.named_parameters():
        if 'bias' in name:
            # 使用小的随机值初始化偏置，而不是0
            nn.init.normal_(param, mean=0.0, std=0.01)
            print(f"  {name}: 重新初始化为 mean={param.data.mean():.6f}, std={param.data.std():.6f}")
    
    return model

def test_model_with_fixed_init():
    """测试修复后的模型"""
    print("\n🧪 测试修复后的模型...")
    
    model = fix_model_initialization()
    
    # 创建测试输入
    cfg = Config("configs/train_config.json")
    test_input = torch.randn(10, cfg.model.input_size)  # 批量大小为10
    
    # 测试前向传播
    model.eval()
    with torch.no_grad():
        output = model(test_input)
    
    print(f"📈 输出统计:")
    print(f"  输出形状: {output.shape}")
    print(f"  输出范围: [{output.min().item():.6f}, {output.max().item():.6f}]")
    print(f"  输出均值: {output.mean().item():.6f}")
    print(f"  输出标准差: {output.std().item():.6f}")
    
    # 检查参数是否非零
    print(f"\n🔍 修复后参数检查:")
    total_params = 0
    zero_params = 0
    
    for name, param in model.named_parameters():
        param_count = param.numel()
        total_params += param_count
        
        zero_count = torch.sum(param.data == 0).item()
        zero_params += zero_count
        
        print(f"  {name}: {zero_count}/{param_count} 零参数 ({zero_count/param_count*100:.2f}%)")
    
    print(f"\n📊 汇总:")
    print(f"  总参数: {total_params}")
    print(f"  零参数: {zero_params} ({zero_params/total_params*100:.2f}%)")
    
    return model

def create_improved_model_class():
    """创建改进的模型类"""
    print("\n🚀 创建改进的模型类...")
    
    class ImprovedNetworkQualityModel(NetworkQualityModel):
        def _initialize_weights(self):
            """改进的权重初始化方法"""
            for module in self.modules():
                if isinstance(module, nn.Linear):
                    # 权重使用Xavier初始化
                    nn.init.xavier_uniform_(module.weight)
                    
                    # 偏置使用小的随机值初始化，而不是0
                    if module.bias is not None:
                        nn.init.normal_(module.bias, mean=0.0, std=0.01)
        
        def forward(self, x: torch.Tensor) -> torch.Tensor:
            """改进的前向传播，确保BatchNorm在训练时正确工作"""
            # 输入层
            x = F.relu(self.input_layer(x))
            x = self.dropout(x)
            
            # 隐藏层
            for i, layer in enumerate(self.hidden_layers):
                x = F.relu(layer(x))
                if self.use_batch_norm and self.batch_norms:
                    # 确保BatchNorm在训练时使用足够大的批量
                    if self.training and x.size(0) == 1:
                        # 如果批量大小为1，暂时禁用BatchNorm
                        pass
                    else:
                        x = self.batch_norms[i](x)
                x = self.dropout(x)
            
            # 输出层
            outputs = self.output_layer(x)
            
            # 应用sigmoid
            quality_score = torch.sigmoid(outputs[:, 1:2])
            confidence = torch.sigmoid(outputs[:, 2:3])
            
            result = torch.cat([outputs[:, 0:1], quality_score, confidence], dim=1)
            
            return result
    
    # 测试改进的模型
    cfg = Config("configs/train_config.json")
    improved_model = ImprovedNetworkQualityModel(
        input_size=cfg.model.input_size,
        hidden_sizes=tuple(cfg.model.hidden_sizes),
        dropout_rate=cfg.model.dropout_rate,
        use_batch_norm=cfg.model.use_batch_norm
    )
    
    print("✅ 改进的模型类创建成功")
    
    # 检查参数
    print(f"\n📊 改进模型参数检查:")
    for name, param in improved_model.named_parameters():
        if 'bias' in name:
            print(f"  {name}: mean={param.data.mean():.6f}, std={param.data.std():.6f}")
    
    return improved_model

def main():
    """主函数"""
    print("🚀 开始修复模型训练问题...")
    
    # 测试当前模型问题
    test_model_with_fixed_init()
    
    # 创建改进的模型类
    improved_model = create_improved_model_class()
    
    print(f"\n🎉 修复完成!")
    print(f"💡 建议:")
    print(f"  1. 使用改进的模型类重新训练")
    print(f"  2. 确保训练批量大小 > 1 (避免BatchNorm问题)")
    print(f"  3. 偏置参数现在使用随机初始化而不是0")

if __name__ == "__main__":
    import torch.nn as nn
    import torch.nn.functional as F
    main()
