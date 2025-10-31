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
from src.models.trainer import ModelTrainer
from src.data.generator import DataGenerator
from src.data.preprocessor import DataPreprocessor
from src.utils.config import Config

def check_optimizer_parameters(trainer):
    """检查优化器是否包含所有参数"""
    print("🔍 检查优化器参数覆盖...")
    
    # 计算模型参数总数
    model_params = dict(trainer.model.named_parameters())
    model_param_count = sum(p.numel() for p in model_params.values())
    
    # 计算优化器参数总数
    optimizer_param_count = 0
    for group in trainer.optimizer.param_groups:
        for param in group['params']:
            optimizer_param_count += param.numel()
    
    print(f"📊 模型参数总数: {model_param_count}")
    print(f"📊 优化器参数总数: {optimizer_param_count}")
    print(f"📊 参数覆盖率: {optimizer_param_count/model_param_count*100:.1f}%")
    
    # 检查偏置参数是否在优化器中
    bias_in_optimizer = 0
    total_biases = 0
    
    for name, param in model_params.items():
        if 'bias' in name:
            total_biases += param.numel()
            # 检查这个参数是否在优化器中
            for group in trainer.optimizer.param_groups:
                for opt_param in group['params']:
                    if param.data_ptr() == opt_param.data_ptr():
                        bias_in_optimizer += param.numel()
                        break
                else:
                    continue
                break
    
    print(f"📊 偏置参数覆盖率: {bias_in_optimizer/total_biases*100:.1f}%")
    
    return optimizer_param_count == model_param_count

def monitor_bias_changes(model, epoch):
    """监控偏置参数的变化"""
    print(f"\n📈 第 {epoch} 轮偏置参数监控:")
    
    bias_stats = {}
    for name, param in model.named_parameters():
        if 'bias' in name:
            bias_stats[name] = {
                'mean': param.data.mean().item(),
                'std': param.data.std().item(),
                'grad_mean': param.grad.mean().item() if param.grad is not None else 0,
                'grad_std': param.grad.std().item() if param.grad is not None else 0
            }
            print(f"  {name}:")
            print(f"    参数均值: {bias_stats[name]['mean']:.6f}")
            print(f"    参数标准差: {bias_stats[name]['std']:.6f}")
            print(f"    梯度均值: {bias_stats[name]['grad_mean']:.6f}")
            print(f"    梯度标准差: {bias_stats[name]['grad_std']:.6f}")
    
    return bias_stats

def verify_gradient_flow(model, loss):
    """验证梯度是否传播到偏置参数"""
    print("\n🔍 验证梯度传播...")
    
    # 清空梯度
    model.zero_grad()
    
    # 反向传播
    loss.backward()
    
    has_bias_gradients = False
    bias_gradient_stats = {}
    
    for name, param in model.named_parameters():
        if 'bias' in name and param.grad is not None:
            grad_norm = param.grad.norm().item()
            grad_mean = param.grad.mean().item()
            grad_std = param.grad.std().item()
            
            bias_gradient_stats[name] = {
                'grad_norm': grad_norm,
                'grad_mean': grad_mean,
                'grad_std': grad_std
            }
            
            if grad_norm > 1e-8:  # 有显著的梯度
                has_bias_gradients = True
                print(f"  ✅ {name}: 接收到梯度 (norm={grad_norm:.6f})")
            else:
                print(f"  ⚠️ {name}: 梯度很小 (norm={grad_norm:.6f})")
    
    return has_bias_gradients, bias_gradient_stats

def compare_parameters_before_after(model_before, model_after):
    """比较训练前后参数的变化"""
    print("\n🔄 比较训练前后参数变化:")
    
    params_before = dict(model_before.named_parameters())
    params_after = dict(model_after.named_parameters())
    
    total_changes = 0
    bias_changes = 0
    
    for name, param_before in params_before.items():
        param_after = params_after[name]
        
        # 计算参数变化
        change = torch.norm(param_after.data - param_before.data).item()
        
        if 'bias' in name:
            bias_changes += change
            print(f"  {name}: 变化量 = {change:.6f}")
        else:
            total_changes += change
    
    print(f"📊 偏置参数总变化: {bias_changes:.6f}")
    print(f"📊 所有参数总变化: {total_changes:.6f}")
    
    return bias_changes > 0  # 偏置参数应该有变化

def test_training_with_monitoring():
    """测试训练过程并监控参数更新"""
    print("🚀 开始训练过程验证...")
    
    # 加载配置
    cfg = Config("configs/train_config.json")
    
    # 生成测试数据
    print("📊 生成测试数据...")
    generator = DataGenerator()
    raw_dataset = generator.generate_dataset(n_samples=100)
    
    # 预处理数据
    print("🔧 预处理数据...")
    preprocessor = DataPreprocessor()
    X_train, X_val, X_test, y_train, y_val, y_test, scaler = preprocessor.preprocess_data(
        raw_dataset,
        test_size=0.2,
        validation_size=0.1,
        random_state=42
    )
    
    # 创建模型（训练前）
    print("🤖 创建模型...")
    model_before = NetworkQualityModel(
        input_size=cfg.model.input_size,
        hidden_sizes=tuple(cfg.model.hidden_sizes),
        dropout_rate=cfg.model.dropout_rate,
        use_batch_norm=cfg.model.use_batch_norm
    )
    
    # 创建数据加载器
    trainer_temp = ModelTrainer(model_before, device='cpu')
    train_loader, val_loader, test_loader = trainer_temp.create_dataloaders(
        X_train, X_val, X_test, y_train, y_val, y_test, batch_size=16, shuffle=True
    )
    
    # 记录初始参数
    initial_biases = {}
    for name, param in model_before.named_parameters():
        if 'bias' in name:
            initial_biases[name] = param.data.clone()
    
    # 创建训练器
    trainer = ModelTrainer(model_before, device='cpu')  # 使用CPU进行测试
    trainer.setup_training(
        learning_rate=0.01,  # 使用较大的学习率以便观察变化
        weight_decay=1e-4
    )
    
    # 检查优化器
    print("\n" + "="*50)
    optimizer_ok = check_optimizer_parameters(trainer)
    if not optimizer_ok:
        print("❌ 优化器参数覆盖不完整!")
        return False
    
    # 执行一个训练步骤
    print("\n" + "="*50)
    print("🎯 执行一个训练步骤...")
    
    model_before.train()
    for batch_idx, (data, target) in enumerate(train_loader):
        if batch_idx >= 1:  # 只处理一个批次
            break
            
        # 前向传播
        output = model_before(data)
        loss = trainer.criterion(output, target)
        
        # 验证梯度传播
        has_gradients, grad_stats = verify_gradient_flow(model_before, loss)
        
        if not has_gradients:
            print("❌ 偏置参数没有接收到梯度!")
            return False
        
        # 执行优化步骤
        trainer.optimizer.step()
        
        # 监控参数变化
        monitor_bias_changes(model_before, 1)
        
        print(f"✅ 训练步骤完成，损失: {loss.item():.4f}")
        break
    
    # 比较训练前后参数
    print("\n" + "="*50)
    print("🔄 比较训练前后参数...")
    
    params_changed = compare_parameters_before_after(
        NetworkQualityModel(  # 创建新模型作为参考
            input_size=cfg.model.input_size,
            hidden_sizes=tuple(cfg.model.hidden_sizes),
            dropout_rate=cfg.model.dropout_rate,
            use_batch_norm=cfg.model.use_batch_norm
        ),
        model_before
    )
    
    if params_changed:
        print("✅ 偏置参数成功被更新!")
    else:
        print("❌ 偏置参数没有被更新!")
        return False
    
    return True

def analyze_model_parameters(model):
    """分析模型参数状态"""
    print("\n📊 模型参数分析:")
    
    total_params = 0
    bias_params = 0
    zero_bias_params = 0
    
    for name, param in model.named_parameters():
        param_count = param.numel()
        total_params += param_count
        
        if 'bias' in name:
            bias_params += param_count
            zero_count = torch.sum(param.data == 0).item()
            zero_bias_params += zero_count
            
            print(f"  {name}: {param_count} 参数, {zero_count} 零参数 ({zero_count/param_count*100:.1f}%)")
    
    print(f"\n📈 汇总统计:")
    print(f"  总参数: {total_params}")
    print(f"  偏置参数: {bias_params}")
    print(f"  零偏置参数: {zero_bias_params} ({zero_bias_params/bias_params*100:.1f}%)")
    
    return zero_bias_params == 0  # 应该没有零偏置参数

def main():
    """主函数"""
    print("🚀 训练过程验证工具")
    print("=" * 60)
    
    # 测试模型初始化
    print("\n1. 测试模型初始化...")
    cfg = Config("configs/train_config.json")
    test_model = NetworkQualityModel(
        input_size=cfg.model.input_size,
        hidden_sizes=tuple(cfg.model.hidden_sizes),
        dropout_rate=cfg.model.dropout_rate,
        use_batch_norm=cfg.model.use_batch_norm
    )
    
    init_ok = analyze_model_parameters(test_model)
    if not init_ok:
        print("❌ 模型初始化有问题!")
        return
    
    print("✅ 模型初始化正常")
    
    # 测试训练过程
    print("\n2. 测试训练过程...")
    training_ok = test_training_with_monitoring()
    
    if training_ok:
        print("\n🎉 训练过程验证成功!")
        print("✅ 偏置参数初始化正常")
        print("✅ 优化器包含所有参数")
        print("✅ 梯度能够传播到偏置参数")
        print("✅ 训练能够更新偏置参数")
    else:
        print("\n❌ 训练过程验证失败!")
        print("请检查训练配置和模型实现")

if __name__ == "__main__":
    main()
