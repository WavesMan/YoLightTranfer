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

def debug_single_model(model_path: str):
    """调试单个模型的参数状态"""
    print(f"\n🔍 调试模型: {model_path}")
    
    try:
        # 加载模型
        cfg = Config("configs/train_config.json")
        model = NetworkQualityModel(
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
            use_batch_norm=cfg.model.use_batch_norm
        )
        
        # 检查模型文件大小
        file_size = os.path.getsize(model_path)
        print(f"📁 文件大小: {file_size} bytes")
        
        # 加载模型
        model.load_model(model_path)
        
        # 检查状态字典
        state_dict = torch.load(model_path)
        print(f"📋 状态字典键: {list(state_dict.keys())}")
        
        # 详细检查每个参数
        total_params = 0
        zero_params = 0
        nan_params = 0
        inf_params = 0
        
        print("\n📊 参数详细分析:")
        for name, param in model.named_parameters():
            param_data = param.data.cpu().numpy()
            param_count = param.numel()
            total_params += param_count
            
            # 统计各种参数
            zero_count = np.sum(param_data == 0)
            nan_count = np.sum(np.isnan(param_data))
            inf_count = np.sum(np.isinf(param_data))
            
            zero_params += zero_count
            nan_params += nan_count
            inf_params += inf_count
            
            print(f"  {name}:")
            print(f"    形状: {param.data.shape}")
            print(f"    参数数量: {param_count:,}")
            print(f"    均值: {param_data.mean():.6f}")
            print(f"    标准差: {param_data.std():.6f}")
            print(f"    范围: [{param_data.min():.6f}, {param_data.max():.6f}]")
            print(f"    零参数: {zero_count} ({zero_count/param_count*100:.2f}%)")
            print(f"    NaN参数: {nan_count}")
            print(f"    Inf参数: {inf_count}")
        
        # 汇总统计
        print(f"\n📈 汇总统计:")
        print(f"  总参数数量: {total_params:,}")
        print(f"  零参数比例: {zero_params/total_params*100:.2f}%")
        print(f"  NaN参数比例: {nan_params/total_params*100:.2f}%")
        print(f"  Inf参数比例: {inf_params/total_params*100:.2f}%")
        
        # 检查模型是否能进行预测
        print(f"\n🧪 测试模型预测:")
        try:
            # 创建测试输入
            test_input = torch.randn(1, cfg.model.input_size)
            output = model(test_input)
            print(f"  ✅ 预测成功!")
            print(f"  输出形状: {output.shape}")
            print(f"  输出范围: [{output.min().item():.6f}, {output.max().item():.6f}]")
        except Exception as e:
            print(f"  ❌ 预测失败: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ 调试失败: {e}")
        return False

def debug_multiple_models(model_paths: list, sample_count: int = 5):
    """调试多个模型样本"""
    print(f"🔍 调试 {sample_count} 个模型样本...")
    
    # 随机选择样本
    import random
    sample_paths = random.sample(model_paths, min(sample_count, len(model_paths)))
    
    for i, model_path in enumerate(sample_paths, 1):
        print(f"\n{'='*60}")
        print(f"样本 {i}/{len(sample_paths)}")
        debug_single_model(model_path)

def debug_federated_average(models_dir: str = "models"):
    """调试联邦平均计算过程"""
    print("🧠 调试联邦平均计算过程...")
    
    # 扫描模型文件
    import glob
    pattern = os.path.join(models_dir, "terminal_*", "model_iter_*.pth")
    model_files = glob.glob(pattern)
    
    if not model_files:
        print("❌ 没有找到模型文件")
        return
    
    print(f"📁 找到 {len(model_files)} 个模型文件")
    
    # 选择前3个模型进行调试
    sample_models = model_files[:3]
    
    cfg = Config("configs/train_config.json")
    models = []
    
    for i, model_path in enumerate(sample_models, 1):
        print(f"\n📥 加载模型 {i}: {os.path.basename(model_path)}")
        
        model = NetworkQualityModel(
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
            use_batch_norm=cfg.model.use_batch_norm
        )
        model.load_model(model_path)
        models.append(model)
        
        # 检查第一个层的参数
        for name, param in model.named_parameters():
            if 'input_layer' in name:
                param_data = param.data.cpu().numpy()
                print(f"  {name}: mean={param_data.mean():.6f}, std={param_data.std():.6f}")
                break
    
    # 模拟联邦平均计算
    print(f"\n🧮 模拟联邦平均计算...")
    all_params = []
    for model in models:
        all_params.append(dict(model.named_parameters()))
    
    # 检查第一个参数的平均计算
    first_param_name = list(all_params[0].keys())[0]
    print(f"  计算参数: {first_param_name}")
    
    param_sum = torch.zeros_like(all_params[0][first_param_name].data)
    for i, params in enumerate(all_params):
        param_data = params[first_param_name].data.cpu().numpy()
        print(f"    模型 {i+1}: mean={param_data.mean():.6f}, std={param_data.std():.6f}")
        param_sum += params[first_param_name].data
    
    avg_param = param_sum / len(models)
    avg_data = avg_param.cpu().numpy()
    print(f"  平均结果: mean={avg_data.mean():.6f}, std={avg_data.std():.6f}")

def main():
    """主函数"""
    print("🚀 开始调试模型参数...")
    
    # 扫描所有模型文件
    import glob
    model_files = glob.glob("models/terminal_*/model_iter_*.pth")
    
    if not model_files:
        print("❌ 没有找到模型文件")
        return
    
    print(f"📁 找到 {len(model_files)} 个模型文件")
    
    # 调试多个模型样本
    debug_multiple_models(model_files, sample_count=3)
    
    # 调试联邦平均计算
    debug_federated_average()

if __name__ == "__main__":
    main()
