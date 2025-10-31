# language: python
"""
实时预测测试工具

用于测试模型在不同网络场景下的实时预测表现
验证模型在实际应用中的决策能力
"""

import os
import sys
import json
import numpy as np
import pandas as pd
from datetime import datetime

# Ensure project root is on PYTHONPATH so that imports from src/ work
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, os.pardir, os.pardir))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.models.network_model import NetworkQualityModel
from src.utils.config import Config

class PredictionTester:
    """实时预测测试器"""
    
    def __init__(self, config_path: str = "configs/train_config.json"):
        self.cfg = Config(config_path)
        self.output_dir = "prediction_results"
        os.makedirs(self.output_dir, exist_ok=True)
        
    def load_model(self, model_path: str):
        """加载模型"""
        print(f"📥 加载模型: {model_path}")
        self.model = NetworkQualityModel.load_model(model_path)
        return self.model
    
    def create_test_scenarios(self):
        """创建测试场景"""
        scenarios = {
            "强网络场景": [
                [100.0, 20.0, 0.5],    # 高带宽, 低延迟, 低丢包
                [80.0, 30.0, 1.0],
                [120.0, 15.0, 0.2]
            ],
            "弱网络场景": [
                [5.0, 200.0, 15.0],    # 低带宽, 高延迟, 高丢包
                [8.0, 180.0, 12.0],
                [3.0, 250.0, 20.0]
            ],
            "临界网络场景": [
                [25.0, 80.0, 5.0],     # 中等网络条件
                [30.0, 60.0, 3.0],
                [20.0, 100.0, 8.0]
            ],
            "边界测试场景": [
                [0.1, 500.0, 50.0],    # 极端弱网络
                [200.0, 1.0, 0.1],     # 极端强网络
                [50.0, 50.0, 10.0]     # 典型临界网络
            ]
        }
        return scenarios
    
    def test_single_scenario(self, scenario_name: str, network_data: list):
        """测试单个场景"""
        print(f"\n🎯 测试场景: {scenario_name}")
        print(f"   网络参数: 带宽={network_data[0]}Mbps, 延迟={network_data[1]}ms, 丢包={network_data[2]}%")
        
        # 进行预测
        predictions = self.model.predict(np.array([network_data]))
        
        # 输出结果
        hotspot_prob = predictions['hotspot_probability'][0]
        hotspot_rec = predictions['hotspot_recommendation'][0]
        quality_score = predictions['quality_score'][0]
        confidence = predictions['confidence'][0]
        
        print(f"   预测结果:")
        print(f"     热点推荐概率: {hotspot_prob:.4f}")
        print(f"     热点推荐决策: {'✅ 推荐' if hotspot_rec == 1 else '❌ 不推荐'}")
        print(f"     网络质量评分: {quality_score:.4f}")
        print(f"     模型置信度: {confidence:.4f}")
        
        # 决策分析
        decision_analysis = self._analyze_decision(network_data, predictions)
        print(f"   决策分析: {decision_analysis}")
        
        return {
            "scenario": scenario_name,
            "network_parameters": {
                "bandwidth": network_data[0],
                "delay": network_data[1],
                "packet_loss": network_data[2]
            },
            "predictions": {
                "hotspot_probability": float(hotspot_prob),
                "hotspot_recommendation": int(hotspot_rec),
                "quality_score": float(quality_score),
                "confidence": float(confidence)
            },
            "decision_analysis": decision_analysis
        }
    
    def _analyze_decision(self, network_data: list, predictions: dict) -> str:
        """分析决策合理性"""
        bandwidth, delay, packet_loss = network_data
        hotspot_prob = predictions['hotspot_probability'][0]
        quality_score = predictions['quality_score'][0]
        confidence = predictions['confidence'][0]
        
        # 基于网络参数的决策逻辑
        if bandwidth < 10 and delay > 100 and packet_loss > 10:
            expected_decision = "推荐热点"  # 弱网络应该推荐热点
            if hotspot_prob > 0.5:
                return "✅ 决策合理: 弱网络正确推荐热点"
            else:
                return "❌ 决策不合理: 弱网络未推荐热点"
        
        elif bandwidth > 50 and delay < 50 and packet_loss < 5:
            expected_decision = "不推荐热点"  # 强网络不应该推荐热点
            if hotspot_prob <= 0.5:
                return "✅ 决策合理: 强网络正确不推荐热点"
            else:
                return "❌ 决策不合理: 强网络错误推荐热点"
        
        else:
            return "⚠️ 临界情况: 需要人工判断"
    
    def comprehensive_prediction_test(self, model_path: str):
        """全面预测测试"""
        print("🚀 开始全面预测测试")
        print("=" * 60)
        
        # 加载模型
        self.load_model(model_path)
        
        # 创建测试场景
        scenarios = self.create_test_scenarios()
        
        # 执行测试
        all_results = []
        
        for scenario_name, scenario_data in scenarios.items():
            print(f"\n{'='*40}")
            print(f"📋 测试场景组: {scenario_name}")
            print(f"{'='*40}")
            
            for i, network_data in enumerate(scenario_data, 1):
                result = self.test_single_scenario(f"{scenario_name}-{i}", network_data)
                all_results.append(result)
        
        # 生成测试报告
        self._generate_prediction_report(all_results, model_path)
        
        # 决策一致性分析
        self._analyze_decision_consistency(all_results)
        
        return all_results
    
    def _generate_prediction_report(self, results: list, model_path: str):
        """生成预测测试报告"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(self.output_dir, f"prediction_report_{timestamp}.json")
        
        report = {
            "test_time": datetime.now().isoformat(),
            "model_path": model_path,
            "total_test_cases": len(results),
            "test_results": results,
            "summary_statistics": self._calculate_summary_statistics(results)
        }
        
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 预测测试报告已保存: {report_file}")
        
        # 打印摘要
        self._print_prediction_summary(report["summary_statistics"])
    
    def _calculate_summary_statistics(self, results: list) -> dict:
        """计算摘要统计"""
        hotspot_probs = [r["predictions"]["hotspot_probability"] for r in results]
        quality_scores = [r["predictions"]["quality_score"] for r in results]
        confidences = [r["predictions"]["confidence"] for r in results]
        
        # 决策统计
        hotspot_recommendations = [r["predictions"]["hotspot_recommendation"] for r in results]
        recommend_count = sum(hotspot_recommendations)
        not_recommend_count = len(hotspot_recommendations) - recommend_count
        
        return {
            "hotspot_probability": {
                "mean": float(np.mean(hotspot_probs)),
                "std": float(np.std(hotspot_probs)),
                "min": float(np.min(hotspot_probs)),
                "max": float(np.max(hotspot_probs))
            },
            "quality_score": {
                "mean": float(np.mean(quality_scores)),
                "std": float(np.std(quality_scores)),
                "min": float(np.min(quality_scores)),
                "max": float(np.max(quality_scores))
            },
            "confidence": {
                "mean": float(np.mean(confidences)),
                "std": float(np.std(confidences)),
                "min": float(np.min(confidences)),
                "max": float(np.max(confidences))
            },
            "decision_distribution": {
                "recommend_hotspot": recommend_count,
                "not_recommend_hotspot": not_recommend_count,
                "recommend_ratio": recommend_count / len(results)
            }
        }
    
    def _print_prediction_summary(self, summary: dict):
        """打印预测摘要"""
        print("\n" + "="*60)
        print("📊 预测测试摘要")
        print("="*60)
        
        print(f"\n🎯 热点推荐概率统计:")
        print(f"  平均值: {summary['hotspot_probability']['mean']:.4f}")
        print(f"  标准差: {summary['hotspot_probability']['std']:.4f}")
        print(f"  范围: [{summary['hotspot_probability']['min']:.4f}, {summary['hotspot_probability']['max']:.4f}]")
        
        print(f"\n📈 网络质量评分统计:")
        print(f"  平均值: {summary['quality_score']['mean']:.4f}")
        print(f"  标准差: {summary['quality_score']['std']:.4f}")
        print(f"  范围: [{summary['quality_score']['min']:.4f}, {summary['quality_score']['max']:.4f}]")
        
        print(f"\n🎯 模型置信度统计:")
        print(f"  平均值: {summary['confidence']['mean']:.4f}")
        print(f"  标准差: {summary['confidence']['std']:.4f}")
        print(f"  范围: [{summary['confidence']['min']:.4f}, {summary['confidence']['max']:.4f}]")
        
        print(f"\n📋 决策分布:")
        dist = summary['decision_distribution']
        print(f"  推荐热点: {dist['recommend_hotspot']} 次")
        print(f"  不推荐热点: {dist['not_recommend_hotspot']} 次")
        print(f"  推荐比例: {dist['recommend_ratio']:.2%}")
    
    def _analyze_decision_consistency(self, results: list):
        """分析决策一致性"""
        print(f"\n🔍 决策一致性分析:")
        
        # 按场景分组分析
        scenario_groups = {}
        for result in results:
            scenario = result["scenario"].split("-")[0]  # 获取场景组名
            if scenario not in scenario_groups:
                scenario_groups[scenario] = []
            scenario_groups[scenario].append(result)
        
        for scenario, group_results in scenario_groups.items():
            hotspot_probs = [r["predictions"]["hotspot_probability"] for r in group_results]
            prob_std = np.std(hotspot_probs)
            
            print(f"  {scenario}:")
            print(f"    测试案例数: {len(group_results)}")
            print(f"    推荐概率标准差: {prob_std:.4f}")
            
            if prob_std < 0.2:
                print(f"    ✅ 决策一致性: 高")
            elif prob_std < 0.4:
                print(f"    ⚠️ 决策一致性: 中等")
            else:
                print(f"    ❌ 决策一致性: 低")
    
    def interactive_test(self, model_path: str):
        """交互式测试模式"""
        print("🎮 启动交互式预测测试")
        print("=" * 40)
        
        self.load_model(model_path)
        
        while True:
            try:
                print(f"\n请输入网络参数:")
                bandwidth = float(input("  带宽 (Mbps): "))
                delay = float(input("  延迟 (ms): "))
                packet_loss = float(input("  丢包率 (%): "))
                
                network_data = [bandwidth, delay, packet_loss]
                self.test_single_scenario("用户输入", network_data)
                
                continue_test = input("\n继续测试? (y/n): ").lower().strip()
                if continue_test != 'y':
                    break
                    
            except (ValueError, KeyboardInterrupt):
                print("\n退出交互测试")
                break

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="实时预测测试工具")
    parser.add_argument("--model", type=str, default="checkpoints/best_model.pth", 
                       help="模型文件路径")
    parser.add_argument("--mode", choices=["comprehensive", "interactive"], default="comprehensive",
                       help="测试模式: comprehensive(全面) 或 interactive(交互式)")
    parser.add_argument("--config", type=str, default="configs/train_config.json",
                       help="配置文件路径")
    
    args = parser.parse_args()
    
    # 创建测试器
    tester = PredictionTester(args.config)
    
    if args.mode == "interactive":
        tester.interactive_test(args.model)
    else:
        results = tester.comprehensive_prediction_test(args.model)
        print(f"\n🎉 预测测试完成!")
        print(f"📁 结果保存在: {tester.output_dir}")

if __name__ == "__main__":
    main()
