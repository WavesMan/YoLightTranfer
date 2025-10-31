# verify_onnx.py
import onnx
import onnxruntime as ort
import numpy as np

def verify_onnx_model():
    """
    验证转换后的ONNX模型
    
    验证内容包括：
    - 模型结构检查
    - 输入输出格式验证
    - 推理功能测试
    - 输出范围验证
    """
    # 加载 ONNX 模型
    onnx_path = 'checkpoints/network_quality_model.onnx'
    model = onnx.load(onnx_path)
    
    # 检查模型结构
    onnx.checker.check_model(model)
    print(f"✅ ONNX 模型结构验证成功")
    
    # 创建 ONNX Runtime 会话
    session = ort.InferenceSession(onnx_path)
    
    # 获取输入输出信息
    input_info = session.get_inputs()
    output_info = session.get_outputs()
    
    print(f"📊 输入信息:")
    for i, input in enumerate(input_info):
        print(f"  - {input.name}: 形状 {input.shape}, 类型 {input.type}")
    
    print(f"📈 输出信息:")
    for i, output in enumerate(output_info):
        print(f"  - {output.name}: 形状 {output.shape}, 类型 {output.type}")
    
    # 使用真实数据范围的测试输入
    # [带宽, 延迟, 丢包率]
    test_inputs = [
        [91.12, 49.92, 0.22],    # 强网络
        [6.68, 360.65, 17.12],   # 弱网络
        [19.11, 136.91, 1.72]    # 临界网络
    ]
    
    print(f"\n🧪 测试推理:")
    for i, input_data in enumerate(test_inputs):
        input_array = np.array([input_data], dtype=np.float32)
        
        # 执行推理 - 只有一个输出张量包含三个值
        outputs = session.run(
            ['hotspot_probability'], 
            {'network_features': input_array}
        )
        
        # 输出形状为 [1, 3]，包含三个值：[hotspot_logits, quality_score, confidence]
        output_tensor = outputs[0]
        hotspot_logits = output_tensor[0][0]  # 热点推荐logits（需要sigmoid）
        quality_score = output_tensor[0][1]   # 网络质量评分（已sigmoid）
        confidence = output_tensor[0][2]      # 模型置信度（已sigmoid）
        
        # 对热点概率应用sigmoid
        import math
        hotspot_prob = 1 / (1 + math.exp(-hotspot_logits))
        
        print(f"\n测试样本 {i+1}:")
        print(f"  输入: bandwidth={input_data[0]:.2f}Mbps, delay={input_data[1]:.2f}ms, loss={input_data[2]:.2f}%")
        print(f"  输出:")
        print(f"    - hotspot_logits: {hotspot_logits:.4f}")
        print(f"    - hotspot_probability: {hotspot_prob:.4f}")
        print(f"    - quality_score: {quality_score:.4f}")
        print(f"    - confidence: {confidence:.4f}")
        
        # 验证输出范围（热点概率需要sigmoid后验证）
        assert 0 <= hotspot_prob <= 1, f"热点概率超出范围: {hotspot_prob}"
        assert 0 <= quality_score <= 1, f"质量评分超出范围: {quality_score}"
        assert 0 <= confidence <= 1, f"置信度超出范围: {confidence}"
    
    print(f"\n✅ ONNX 模型验证完成 - 所有测试通过!")
    print(f"🎯 输出范围验证: 所有输出均在 [0, 1] 范围内")

if __name__ == "__main__":
    verify_onnx_model()
