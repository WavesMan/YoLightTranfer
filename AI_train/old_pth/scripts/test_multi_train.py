# language: python
"""
多开管理器测试脚本
用于验证多开管理器基本功能
"""

import os
import sys
import time
import json
from datetime import datetime

# 确保项目根目录在PYTHONPATH中
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from scripts.dingtalk_notifier import DingTalkConfig, TrainingNotifier
from scripts.multi_train_manager import GPUMonitor, ProgressTracker


def test_gpu_monitor():
    """测试GPU监控功能"""
    print("🧪 测试GPU监控功能...")
    gpu_monitor = GPUMonitor()
    
    print(f"GPU可用性: {gpu_monitor.has_gpu}")
    print(f"GPU利用率: {gpu_monitor.get_gpu_utilization():.1f}%")
    
    memory_info = gpu_monitor.get_gpu_memory_usage()
    print(f"GPU内存使用: {memory_info['percent']:.1f}%")
    print(f"已用内存: {memory_info['used']:.1f}GB / {memory_info['total']:.1f}GB")
    
    print("✅ GPU监控测试完成\n")


def test_progress_tracker():
    """测试进度跟踪功能"""
    print("🧪 测试进度跟踪功能...")
    
    # 创建测试进度文件
    test_progress_file = "models/test_progress.json"
    tracker = ProgressTracker(test_progress_file)
    
    # 模拟进度数据
    progress_data = {
        "total_iterations": 50,
        "terminals": {
            "test_terminal_1": {
                "current_iteration": 50,
                "last_update": datetime.now().isoformat()
            },
            "test_terminal_2": {
                "current_iteration": 49,
                "last_update": datetime.now().isoformat()
            }
        }
    }
    
    # 写入测试数据
    os.makedirs(os.path.dirname(test_progress_file), exist_ok=True)
    with open(test_progress_file, 'w') as f:
        json.dump(progress_data, f, indent=2)
    
    # 测试读取
    current_iteration = tracker.get_current_iteration()
    active_terminals = tracker.get_active_terminals()
    
    print(f"当前迭代: {current_iteration}")
    print(f"活跃终端数量: {len(active_terminals)}")
    for terminal_id, info in active_terminals.items():
        print(f"  - {terminal_id}: 迭代{info['current_iteration']}")
    
    # 清理测试文件
    if os.path.exists(test_progress_file):
        os.remove(test_progress_file)
    
    print("✅ 进度跟踪测试完成\n")


def test_dingtalk_config():
    """测试钉钉配置功能"""
    print("🧪 测试钉钉配置功能...")
    
    # 测试基本配置
    config = DingTalkConfig(
        webhook_url="https://oapi.dingtalk.com/robot/send?access_token=test",
        secret="test_secret"
    )
    
    print(f"Webhook URL: {config.webhook_url}")
    print(f"使用加签: {config.secret is not None}")
    print(f"频率限制: {config.rate_limit}条/分钟")
    
    # 测试通知器初始化
    notifier = TrainingNotifier(config)
    print(f"通知间隔: {notifier.notification_interval}次迭代")
    
    print("✅ 钉钉配置测试完成\n")


def test_auto_train_integration():
    """测试与auto_train.py的集成"""
    print("🧪 测试与auto_train.py的集成...")
    
    # 检查auto_train.py是否存在
    auto_train_path = os.path.join(SCRIPT_DIR, "auto_train.py")
    if os.path.exists(auto_train_path):
        print(f"✅ auto_train.py 文件存在: {auto_train_path}")
        
        # 检查auto_train.py的基本结构
        with open(auto_train_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查关键函数是否存在
        required_functions = ["auto_train_iter", "MultiTerminalTrainer"]
        missing_functions = []
        
        for func in required_functions:
            if func not in content:
                missing_functions.append(func)
        
        if missing_functions:
            print(f"⚠️ 缺少必要函数: {missing_functions}")
        else:
            print("✅ auto_train.py 结构完整")
            
    else:
        print("❌ auto_train.py 文件不存在")
    
    print("✅ 集成测试完成\n")


def test_shared_progress():
    """测试共享进度文件功能"""
    print("🧪 测试共享进度文件功能...")
    
    progress_file = "models/shared_progress.json"
    
    # 确保目录存在
    os.makedirs(os.path.dirname(progress_file), exist_ok=True)
    
    # 创建初始进度数据
    initial_data = {
        "total_iterations": 0,
        "terminals": {}
    }
    
    with open(progress_file, 'w') as f:
        json.dump(initial_data, f, indent=2)
    
    print(f"✅ 创建共享进度文件: {progress_file}")
    
    # 测试读取
    tracker = ProgressTracker()
    current_iter = tracker.get_current_iteration()
    print(f"初始迭代次数: {current_iter}")
    
    print("✅ 共享进度测试完成\n")


def main():
    """主测试函数"""
    print("🚀 开始多开管理器功能测试")
    print("=" * 50)
    
    try:
        # 运行各项测试
        test_gpu_monitor()
        test_progress_tracker()
        test_dingtalk_config()
        test_auto_train_integration()
        test_shared_progress()
        
        print("🎉 所有测试完成！")
        print("\n📋 下一步:")
        print("1. 配置钉钉机器人webhook")
        print("2. 运行: uv run python scripts/multi_train_manager.py")
        print("3. 按照提示输入训练参数")
        
    except Exception as e:
        print(f"❌ 测试过程中出现错误: {e}")
        print("请检查依赖安装和配置文件")


if __name__ == "__main__":
    main()
