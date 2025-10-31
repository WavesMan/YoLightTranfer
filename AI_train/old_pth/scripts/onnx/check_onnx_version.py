#!/usr/bin/env python3
"""
ONNX模型版本检查工具

这个脚本用于检查ONNX模型的版本信息，包括IR版本、算子集版本等，
并检查与指定ONNX Runtime版本的兼容性。
"""

import os
import sys
import onnx
import onnxruntime as ort
from pathlib import Path

def check_onnx_model_version(model_path):
    """
    检查ONNX模型的版本信息和兼容性
    
    Args:
        model_path (str): ONNX模型文件的绝对路径
    """
    try:
        # 检查文件是否存在
        if not os.path.exists(model_path):
            print(f"❌ 错误: 文件不存在 - {model_path}")
            return False
        
        # 加载ONNX模型
        print(f"📁 加载模型: {model_path}")
        model = onnx.load(model_path)
        
        # 检查模型结构
        onnx.checker.check_model(model)
        print("✅ 模型结构验证成功")
        
        # 获取模型信息
        ir_version = model.ir_version
        opset_imports = model.opset_import
        producer_name = model.producer_name
        producer_version = model.producer_version
        
        print(f"\n📋 模型基本信息:")
        print(f"  - IR版本: {ir_version}")
        print(f"  - 生产者: {producer_name} {producer_version}")
        
        # 显示算子集信息
        print(f"\n🔧 算子集信息:")
        for opset in opset_imports:
            domain = opset.domain if opset.domain else "ai.onnx"
            version = opset.version
            print(f"  - {domain}: 版本 {version}")
        
        # 获取输入输出信息
        print(f"\n📊 模型输入输出:")
        for i, input in enumerate(model.graph.input):
            print(f"  - 输入{i}: {input.name}")
            if input.type.tensor_type.shape.dim:
                shape = [dim.dim_value if dim.dim_value > 0 else '?' 
                        for dim in input.type.tensor_type.shape.dim]
                print(f"    形状: {shape}")
        
        for i, output in enumerate(model.graph.output):
            print(f"  - 输出{i}: {output.name}")
            if output.type.tensor_type.shape.dim:
                shape = [dim.dim_value if dim.dim_value > 0 else '?' 
                        for dim in output.type.tensor_type.shape.dim]
                print(f"    形状: {shape}")
        
        # 检查ONNX Runtime兼容性
        print(f"\n🔍 ONNX Runtime兼容性检查:")
        try:
            # 获取当前ONNX Runtime版本
            ort_version = ort.__version__
            print(f"  - 当前ONNX Runtime版本: {ort_version}")
            
            # ONNX Runtime 1.4.1支持的最大IR版本
            ort_1_4_1_max_ir = 9
            
            if ir_version > ort_1_4_1_max_ir:
                print(f"  ⚠️  兼容性警告:")
                print(f"     - ONNX Runtime 1.4.1支持最大IR版本: {ort_1_4_1_max_ir}")
                print(f"     - 当前模型IR版本: {ir_version} (不兼容)")
                print(f"  💡 建议解决方案:")
                print(f"     1. 重新转换模型，使用opset_version={ort_1_4_1_max_ir}")
                print(f"     2. 升级ONNX Runtime到1.8+版本")
            else:
                print(f"  ✅ 模型与ONNX Runtime 1.4.1兼容")
                
        except Exception as e:
            print(f"  ⚠️  无法获取ONNX Runtime版本信息: {e}")
        
        # 尝试加载模型进行推理测试
        print(f"\n🧪 推理测试:")
        try:
            session = ort.InferenceSession(model_path)
            input_info = session.get_inputs()
            output_info = session.get_outputs()
            
            print(f"  ✅ 模型加载成功")
            print(f"  - 输入数量: {len(input_info)}")
            print(f"  - 输出数量: {len(output_info)}")
            
            # 显示详细的输入输出信息
            for i, input in enumerate(input_info):
                print(f"    - 输入{i}: {input.name} (形状: {input.shape}, 类型: {input.type})")
            
            for i, output in enumerate(output_info):
                print(f"    - 输出{i}: {output.name} (形状: {output.shape}, 类型: {output.type})")
                
        except Exception as e:
            print(f"  ❌ 模型加载失败: {e}")
            print(f"  💡 这可能是因为版本不兼容或模型损坏")
        
        return True
        
    except Exception as e:
        print(f"❌ 检查过程中发生错误: {e}")
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("ONNX模型版本检查工具")
    print("=" * 60)
    
    # 获取用户输入的模型路径
    while True:
        model_path = input("\n请输入ONNX模型的绝对路径: ").strip()
        
        if not model_path:
            print("❌ 路径不能为空，请重新输入")
            continue
            
        # 处理路径中的引号
        model_path = model_path.strip('"\'')
        
        # 检查文件扩展名
        if not model_path.lower().endswith('.onnx'):
            print("⚠️  警告: 文件扩展名不是.onnx，但将继续检查")
        
        # 检查模型版本
        if check_onnx_model_version(model_path):
            break
        else:
            retry = input("\n是否重新输入路径? (y/n): ").strip().lower()
            if retry not in ['y', 'yes', '是']:
                break
    
    print(f"\n🎉 检查完成!")

if __name__ == "__main__":
    main()
