# language: python
import os
import sys
import torch
import numpy as np
import torch.nn as nn

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.models.network_model import NetworkQualityModel
from src.utils.config import Config

def progressive_bias_fix(model):
    """渐进式偏置修复 - 基于权重尺度智能初始化偏置"""
    print("🔧 渐进式偏置修复...")
    
    # 获取所有参数
    all_params = dict(model.named_parameters())
    
    fixed_count = 0
    for name, param in model.named_parameters():
        if 'bias' in name:
            # 检查偏置是否全为零
            if torch.all(param == 0):
                # 找到对应的权重层
                weight_name = name.replace('bias', 'weight')
                if weight_name in all_params:
                    # 获取对应权重的标准差
                    weight_param = all_params[weight_name]
                    weight_std = weight_param.data.std().item()
                    
                    # 基于权重尺度初始化偏置
                    bias_std = weight_std * 0.1  # 偏置标准差为权重的10%
                    nn.init.normal_(param, mean=0.0, std=bias_std)
                    
                    print(f"  ✅ {name}: 基于权重尺度初始化 (std={bias_std:.6f})")
                    fixed_count += 1
                else:
                    # 如果没有对应的权重，使用默认的小随机值
                    nn.init.normal_(param, mean=0.0, std=0.01)
                    print(f"  ✅ {name}: 使用默认初始化 (std=0.01)")
                    fixed_count += 1
    
    print(f"📊 修复完成: 共修复了 {fixed_count} 个偏置参数")
    return fixed_count

def analyze_model_bias_status(model):
    """分析模型偏置参数状态"""
    print("\n📊 偏置参数状态分析:")
    
    total_biases = 0
    zero_biases = 0
    
    for name, param in model.named_parameters():
        if 'bias' in name:
            param_count = param.numel()
            total_biases += param_count
            
            zero_count = torch.sum(param == 0).item()
            zero_biases += zero_count
            
            print(f"  {name}: {zero_count}/{param_count} 零参数 ({zero_count/param_count*100:.2f}%)")
    
    print(f"\n📈 汇总统计:")
    print(f"  总偏置参数: {total_biases}")
    print(f"  零偏置参数: {zero_biases} ({zero_biases/total_biases*100:.2f}%)")
    
    return zero_biases, total_biases

def fix_single_model(model_path: str, save_fixed: bool = True):
    """修复单个模型的偏置参数"""
    print(f"\n🔍 修复模型: {model_path}")
    
    try:
        # 加载配置和模型
        cfg = Config("configs/train_config.json")
        model = NetworkQualityModel(
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
            use_batch_norm=cfg.model.use_batch_norm
        )
        model.load_model(model_path)
        
        # 分析修复前状态
        zero_before, total_before = analyze_model_bias_status(model)
        
        # 执行渐进式修复
        fixed_count = progressive_bias_fix(model)
        
        # 分析修复后状态
        zero_after, total_after = analyze_model_bias_status(model)
        
        # 保存修复后的模型
        if save_fixed and fixed_count > 0:
            fixed_path = model_path.replace('.pth', '_fixed.pth')
            model.save_model(fixed_path)
            print(f"💾 修复后的模型已保存: {fixed_path}")
        
        print(f"\n🎯 修复效果:")
        print(f"  修复前零偏置: {zero_before}/{total_before} ({zero_before/total_before*100:.2f}%)")
        print(f"  修复后零偏置: {zero_after}/{total_after} ({zero_after/total_after*100:.2f}%)")
        print(f"  修复参数数量: {fixed_count}")
        
        return True
        
    except Exception as e:
        print(f"❌ 修复失败: {e}")
        return False

def fix_all_models(models_dir: str = "models"):
    """修复所有模型的偏置参数"""
    import glob
    
    print("🚀 开始批量修复所有模型...")
    
    # 扫描所有模型文件
    pattern = os.path.join(models_dir, "terminal_*", "model_iter_*.pth")
    model_files = glob.glob(pattern)
    
    if not model_files:
        print("❌ 没有找到模型文件")
        return
    
    print(f"📁 找到 {len(model_files)} 个模型文件")
    
    # 修复每个模型
    success_count = 0
    for i, model_path in enumerate(model_files, 1):
        print(f"\n{'='*60}")
        print(f"处理进度: {i}/{len(model_files)}")
        
        if fix_single_model(model_path, save_fixed=True):
            success_count += 1
    
    print(f"\n🎉 批量修复完成!")
    print(f"✅ 成功修复: {success_count}/{len(model_files)} 个模型")
    print(f"📊 成功率: {success_count/len(model_files)*100:.1f}%")

def test_progressive_fix():
    """测试渐进式修复功能"""
    print("🧪 测试渐进式修复功能...")
    
    # 创建测试模型
    cfg = Config("configs/train_config.json")
    model = NetworkQualityModel(
        input_size=cfg.model.input_size,
        hidden_sizes=tuple(cfg.model.hidden_sizes),
        dropout_rate=cfg.model.dropout_rate,
        use_batch_norm=cfg.model.use_batch_norm
    )
    
    # 分析初始状态
    print("📊 初始模型状态:")
    analyze_model_bias_status(model)
    
    # 执行修复
    fixed_count = progressive_bias_fix(model)
    
    # 分析修复后状态
    print("\n📊 修复后模型状态:")
    analyze_model_bias_status(model)
    
    # 测试前向传播
    print("\n🧪 测试前向传播...")
    test_input = torch.randn(10, cfg.model.input_size)
    model.eval()
    with torch.no_grad():
        output = model(test_input)
    
    print(f"📈 输出统计:")
    print(f"  输出形状: {output.shape}")
    print(f"  输出范围: [{output.min().item():.6f}, {output.max().item():.6f}]")
    print(f"  输出均值: {output.mean().item():.6f}")
    print(f"  输出标准差: {output.std().item():.6f}")
    
    return model

def main():
    """主函数"""
    print("🚀 渐进式偏置修复工具")
    print("=" * 50)
    
    import argparse
    
    parser = argparse.ArgumentParser(description="渐进式偏置修复工具")
    parser.add_argument("--mode", choices=["test", "single", "batch"], default="test",
                       help="运行模式: test(测试), single(单个模型), batch(批量修复)")
    parser.add_argument("--model_path", type=str, help="单个模型文件路径")
    parser.add_argument("--models_dir", type=str, default="models", help="模型目录")
    
    args = parser.parse_args()
    
    if args.mode == "test":
        test_progressive_fix()
    elif args.mode == "single":
        if args.model_path:
            fix_single_model(args.model_path, save_fixed=True)
        else:
            print("❌ 请提供模型文件路径: --model_path <path>")
    elif args.mode == "batch":
        fix_all_models(args.models_dir)
    else:
        print("❌ 未知的运行模式")

if __name__ == "__main__":
    main()
