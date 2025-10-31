"""
可视化工具
提供训练过程和数据可视化功能
"""

import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px


class TrainingVisualizer:
    """训练可视化器 - 可视化训练过程和结果"""
    
    def __init__(self, style: str = 'seaborn'):
        """
        初始化可视化器
        
        Args:
            style: 可视化风格 ('seaborn', 'matplotlib', 'plotly')
        """
        self.style = style
        self.setup_style()
    
    def setup_style(self):
        """设置可视化风格"""
        if self.style == 'seaborn':
            sns.set_style("whitegrid")
            plt.rcParams['figure.figsize'] = (12, 8)
            plt.rcParams['font.size'] = 12
        elif self.style == 'matplotlib':
            plt.style.use('default')
            plt.rcParams['figure.figsize'] = (12, 8)
    
    def plot_training_history(self, training_history: List[Dict], 
                             save_path: Optional[str] = None) -> go.Figure:
        """
        绘制训练历史
        
        Args:
            training_history: 训练历史数据
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        if not training_history:
            print("训练历史为空")
            return None
        
        # 提取数据
        epochs = [entry['epoch'] for entry in training_history]
        train_losses = [entry['train_loss'] for entry in training_history]
        val_losses = [entry.get('val_loss', None) for entry in training_history]
        
        # 创建图形
        fig = make_subplots(rows=2, cols=2, 
                           subplot_titles=('训练损失', '验证损失', '学习曲线', '训练时间'))
        
        # 训练损失
        fig.add_trace(
            go.Scatter(x=epochs, y=train_losses, mode='lines', name='训练损失'),
            row=1, col=1
        )
        
        # 验证损失（如果有）
        if any(val_losses):
            val_epochs = [epochs[i] for i, val_loss in enumerate(val_losses) if val_loss is not None]
            val_losses_clean = [val_loss for val_loss in val_losses if val_loss is not None]
            
            fig.add_trace(
                go.Scatter(x=val_epochs, y=val_losses_clean, mode='lines', name='验证损失'),
                row=1, col=1
            )
        
        # 学习曲线（对数尺度）
        fig.add_trace(
            go.Scatter(x=epochs, y=train_losses, mode='lines', name='训练损失'),
            row=1, col=2
        )
        fig.update_yaxes(type="log", row=1, col=2)
        
        # 训练时间
        epoch_times = [entry.get('epoch_time', 0) for entry in training_history]
        fig.add_trace(
            go.Scatter(x=epochs, y=epoch_times, mode='lines', name='每轮时间'),
            row=2, col=1
        )
        
        # 累计时间
        cumulative_time = np.cumsum(epoch_times)
        fig.add_trace(
            go.Scatter(x=epochs, y=cumulative_time, mode='lines', name='累计时间'),
            row=2, col=2
        )
        
        fig.update_layout(height=800, title_text="训练历史可视化")
        
        if save_path:
            fig.write_html(save_path)
            print(f"训练历史图已保存到: {save_path}")
        
        return fig
    
    def plot_loss_comparison(self, training_results: Dict, 
                           save_path: Optional[str] = None) -> go.Figure:
        """
        绘制损失比较图
        
        Args:
            training_results: 训练结果字典
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        if 'training' not in training_results:
            print("训练结果数据不存在")
            return None
        
        training_info = training_results['training']
        
        # 提取阶段信息（如果是渐进式训练）
        if 'stage_results' in training_info:
            stages = training_info['stage_results']
            
            fig = go.Figure()
            
            for stage in stages:
                stage_name = f"阶段 {stage['stage']}"
                result = stage['result']
                
                # 添加训练损失
                fig.add_trace(go.Scatter(
                    x=[stage['stage']],
                    y=[result['final_train_loss']],
                    mode='markers+text',
                    name=f"{stage_name} - 训练",
                    text=[f"{result['final_train_loss']:.4f}"],
                    textposition="top center"
                ))
                
                # 添加验证损失
                if result['final_val_loss'] is not None:
                    fig.add_trace(go.Scatter(
                        x=[stage['stage']],
                        y=[result['final_val_loss']],
                        mode='markers+text',
                        name=f"{stage_name} - 验证",
                        text=[f"{result['final_val_loss']:.4f}"],
                        textposition="bottom center"
                    ))
            
            fig.update_layout(
                title="渐进式训练阶段损失比较",
                xaxis_title="训练阶段",
                yaxis_title="损失值",
                showlegend=True
            )
        else:
            # 单阶段训练
            fig = go.Figure()
            
            fig.add_trace(go.Indicator(
                mode="number+delta",
                value=training_info['final_train_loss'],
                title={"text": "最终训练损失"},
                domain={'row': 0, 'column': 0}
            ))
            
            if training_info['final_val_loss'] is not None:
                fig.add_trace(go.Indicator(
                    mode="number+delta",
                    value=training_info['final_val_loss'],
                    title={"text": "最终验证损失"},
                    domain={'row': 0, 'column': 1}
                ))
            
            fig.update_layout(
                grid={'rows': 1, 'columns': 2, 'pattern': "independent"},
                title="训练结果指标"
            )
        
        if save_path:
            fig.write_html(save_path)
            print(f"损失比较图已保存到: {save_path}")
        
        return fig
    
    def plot_feature_importance(self, feature_names: List[str], 
                              importance_scores: List[float],
                              save_path: Optional[str] = None) -> go.Figure:
        """
        绘制特征重要性图
        
        Args:
            feature_names: 特征名称列表
            importance_scores: 重要性分数列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        # 创建DataFrame
        importance_df = pd.DataFrame({
            'feature': feature_names,
            'importance': importance_scores
        })
        
        # 按重要性排序
        importance_df = importance_df.sort_values('importance', ascending=True)
        
        # 创建水平条形图
        fig = go.Figure(go.Bar(
            y=importance_df['feature'],
            x=importance_df['importance'],
            orientation='h',
            marker_color='lightblue'
        ))
        
        fig.update_layout(
            title="特征重要性",
            xaxis_title="重要性分数",
            yaxis_title="特征",
            height=600
        )
        
        if save_path:
            fig.write_html(save_path)
            print(f"特征重要性图已保存到: {save_path}")
        
        return fig
    
    def plot_prediction_vs_actual(self, y_true: np.ndarray, 
                                y_pred: np.ndarray,
                                target_names: Optional[List[str]] = None,
                                save_path: Optional[str] = None) -> go.Figure:
        """
        绘制预测值 vs 真实值图
        
        Args:
            y_true: 真实值
            y_pred: 预测值
            target_names: 目标名称列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        if y_true.shape[1] != y_pred.shape[1]:
            raise ValueError("真实值和预测值的维度不匹配")
        
        num_targets = y_true.shape[1]
        
        # 创建子图
        fig = make_subplots(
            rows=num_targets, cols=1,
            subplot_titles=[f"目标 {i+1}" for i in range(num_targets)]
        )
        
        for i in range(num_targets):
            target_name = target_names[i] if target_names else f"目标 {i+1}"
            
            # 添加散点图
            fig.add_trace(
                go.Scatter(
                    x=y_true[:, i],
                    y=y_pred[:, i],
                    mode='markers',
                    name=target_name,
                    showlegend=False
                ),
                row=i+1, col=1
            )
            
            # 添加对角线
            min_val = min(y_true[:, i].min(), y_pred[:, i].min())
            max_val = max(y_true[:, i].max(), y_pred[:, i].max())
            
            fig.add_trace(
                go.Scatter(
                    x=[min_val, max_val],
                    y=[min_val, max_val],
                    mode='lines',
                    name='理想线',
                    line=dict(dash='dash', color='red'),
                    showlegend=False
                ),
                row=i+1, col=1
            )
            
            # 更新坐标轴
            fig.update_xaxes(title_text="真实值", row=i+1, col=1)
            fig.update_yaxes(title_text="预测值", row=i+1, col=1)
        
        fig.update_layout(height=300 * num_targets, title_text="预测值 vs 真实值")
        
        if save_path:
            fig.write_html(save_path)
            print(f"预测值 vs 真实值图已保存到: {save_path}")
        
        return fig
    
    def plot_residuals(self, y_true: np.ndarray, y_pred: np.ndarray,
                      save_path: Optional[str] = None) -> go.Figure:
        """
        绘制残差图
        
        Args:
            y_true: 真实值
            y_pred: 预测值
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        residuals = y_pred - y_true
        
        num_targets = y_true.shape[1]
        
        fig = make_subplots(
            rows=num_targets, cols=2,
            subplot_titles=[f"目标 {i+1} - 残差分布" for i in range(num_targets)] + 
                          [f"目标 {i+1} - 残差 vs 预测值" for i in range(num_targets)]
        )
        
        for i in range(num_targets):
            # 残差分布
            fig.add_trace(
                go.Histogram(x=residuals[:, i], name=f"目标 {i+1} 残差"),
                row=i+1, col=1
            )
            
            # 残差 vs 预测值
            fig.add_trace(
                go.Scatter(x=y_pred[:, i], y=residuals[:, i], mode='markers',
                          name=f"目标 {i+1} 残差"),
                row=i+1, col=2
            )
            
            # 添加零线
            fig.add_trace(
                go.Scatter(x=[y_pred[:, i].min(), y_pred[:, i].max()], y=[0, 0],
                          mode='lines', line=dict(dash='dash', color='red'),
                          showlegend=False),
                row=i+1, col=2
            )
        
        fig.update_layout(height=300 * num_targets, title_text="残差分析")
        
        if save_path:
            fig.write_html(save_path)
            print(f"残差图已保存到: {save_path}")
        
        return fig


class DataVisualizer:
    """数据可视化器 - 可视化训练数据和特征分布"""
    
    def __init__(self):
        """初始化数据可视化器"""
        pass
    
    def plot_feature_distributions(self, X: np.ndarray, 
                                 feature_names: List[str],
                                 save_path: Optional[str] = None) -> go.Figure:
        """
        绘制特征分布图
        
        Args:
            X: 特征数据
            feature_names: 特征名称列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        num_features = X.shape[1]
        num_cols = min(3, num_features)
        num_rows = (num_features + num_cols - 1) // num_cols
        
        fig = make_subplots(rows=num_rows, cols=num_cols,
                           subplot_titles=feature_names)
        
        for i in range(num_features):
            row = i // num_cols + 1
            col = i % num_cols + 1
            
            fig.add_trace(
                go.Histogram(x=X[:, i], name=feature_names[i]),
                row=row, col=col
            )
        
        fig.update_layout(height=300 * num_rows, title_text="特征分布")
        
        if save_path:
            fig.write_html(save_path)
            print(f"特征分布图已保存到: {save_path}")
        
        return fig
    
    def plot_target_distributions(self, y: np.ndarray,
                                target_names: List[str],
                                save_path: Optional[str] = None) -> go.Figure:
        """
        绘制目标变量分布图
        
        Args:
            y: 目标变量数据
            target_names: 目标名称列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        num_targets = y.shape[1]
        
        fig = make_subplots(rows=num_targets, cols=1,
                           subplot_titles=target_names)
        
        for i in range(num_targets):
            fig.add_trace(
                go.Histogram(x=y[:, i], name=target_names[i]),
                row=i+1, col=1
            )
        
        fig.update_layout(height=300 * num_targets, title_text="目标变量分布")
        
        if save_path:
            fig.write_html(save_path)
            print(f"目标变量分布图已保存到: {save_path}")
        
        return fig
    
    def plot_correlation_matrix(self, data: np.ndarray,
                              feature_names: List[str],
                              save_path: Optional[str] = None) -> go.Figure:
        """
        绘制相关性矩阵图
        
        Args:
            data: 数据矩阵
            feature_names: 特征名称列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        # 计算相关性矩阵
        corr_matrix = np.corrcoef(data.T)
        
        # 创建热力图
        fig = go.Figure(data=go.Heatmap(
            z=corr_matrix,
            x=feature_names,
            y=feature_names,
            colorscale='RdBu_r',
            zmid=0
        ))
        
        fig.update_layout(
            title="特征相关性矩阵",
            xaxis_title="特征",
            yaxis_title="特征",
            height=600
        )
        
        if save_path:
            fig.write_html(save_path)
            print(f"相关性矩阵图已保存到: {save_path}")
        
        return fig
    
    def plot_feature_relationships(self, X: np.ndarray, y: np.ndarray,
                                 feature_names: List[str],
                                 target_names: List[str],
                                 save_path: Optional[str] = None) -> go.Figure:
        """
        绘制特征与目标变量关系图
        
        Args:
            X: 特征数据
            y: 目标变量数据
            feature_names: 特征名称列表
            target_names: 目标名称列表
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        num_features = min(4, X.shape[1])  # 限制显示的特征数量
        num_targets = y.shape[1]
        
        fig = make_subplots(rows=num_features, cols=num_targets,
                           subplot_titles=[f"{feat} vs {target}" 
                                         for feat in feature_names[:num_features]
                                         for target in target_names])
        
        for i, feat_idx in enumerate(range(num_features)):
            for j in range(num_targets):
                fig.add_trace(
                    go.Scatter(x=X[:, feat_idx], y=y[:, j], mode='markers',
                              name=f"{feature_names[feat_idx]} vs {target_names[j]}"),
                    row=i+1, col=j+1
                )
        
        fig.update_layout(height=300 * num_features, title_text="特征与目标变量关系")
        
        if save_path:
            fig.write_html(save_path)
            print(f"特征关系图已保存到: {save_path}")
        
        return fig


class PerformanceVisualizer:
    """性能可视化器 - 可视化系统性能指标"""
    
    def __init__(self):
        """初始化性能可视化器"""
        pass
    
    def plot_benchmark_results(self, benchmark_results: Dict,
                             save_path: Optional[str] = None) -> go.Figure:
        """
        绘制基准测试结果图
        
        Args:
            benchmark_results: 基准测试结果
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        if not benchmark_results:
            print("基准测试结果为空")
            return None
        
        # 创建仪表盘图
        fig = make_subplots(
            rows=2, cols=2,
            specs=[[{"type": "indicator"}, {"type": "indicator"}],
                   [{"type": "bar"}, {"type": "bar"}]],
            subplot_titles=('CPU性能', '内存性能', '矩阵运算', '推理性能')
        )
        
        # CPU性能指标
        cpu_perf = benchmark_results.get('cpu_performance', {})
        fig.add_trace(
            go.Indicator(
                mode="gauge+number+delta",
                value=cpu_perf.get('single_thread_performance', 0),
                title={'text': "单线程性能"},
                domain={'row': 1, 'column': 1}
            ),
            row=1, col=1
        )
        
        # 内存性能指标
        memory_perf = benchmark_results.get('memory_performance', {})
        fig.add_trace(
            go.Indicator(
                mode="gauge+number+delta",
                value=memory_perf.get('memory_copy_speed_mb_per_sec', 0),
                title={'text': "内存复制速度"},
                domain={'row': 1, 'column': 2}
            ),
            row=1, col=2
        )
        
        # 矩阵运算性能
        matrix_perf = benchmark_results.get('matrix_operations', {})
        matrix_scores = []
        matrix_names = []
        
        for key, value in matrix_perf.items():
            if 'matmul_operations_per_second' in value:
                matrix_scores.append(value['matmul_operations_per_second'])
                matrix_names.append(key)
        
        if matrix_scores:
            fig.add_trace(
                go.Bar(x=matrix_names, y=matrix_scores, name='矩阵运算性能'),
                row=2, col=1
            )
        
        # 推理性能
        inference_perf = benchmark_results.get('inference_performance', {})
        inference_scores = []
        inference_names = []
        
        for key, value in inference_perf.items():
            if 'inferences_per_second' in value:
                inference_scores.append(value['inferences_per_second'])
                inference_names.append(key)
        
        if inference_scores:
            fig.add_trace(
                go.Bar(x=inference_names, y=inference_scores, name='推理性能'),
                row=2, col=2
            )
        
        fig.update_layout(height=600, title_text="系统性能基准测试结果")
        
        if save_path:
            fig.write_html(save_path)
            print(f"性能基准测试图已保存到: {save_path}")
        
        return fig
    
    def plot_hardware_info(self, hardware_info: Dict,
                          save_path: Optional[str] = None) -> go.Figure:
        """
        绘制硬件信息图
        
        Args:
            hardware_info: 硬件信息字典
            save_path: 保存路径
            
        Returns:
            Plotly图形对象
        """
        if not hardware_info:
            print("硬件信息为空")
            return None
        
        # 创建硬件信息展示
        fig = make_subplots(
            rows=2, cols=2,
            specs=[[{"type": "indicator"}, {"type": "indicator"}],
                   [{"type": "table"}, {"type": "table"}]],
            subplot_titles=('CPU信息', 'GPU信息', '内存信息', '系统信息')
        )
        
        # CPU信息
        cpu_info = hardware_info.get('cpu', {})
        fig.add_trace(
            go.Indicator(
                mode="number",
                value=cpu_info.get('logical_cores', 0),
                title={'text': "CPU核心数"},
                domain={'row': 1, 'column': 1}
            ),
            row=1, col=1
        )
        
        # GPU信息
        gpu_info = hardware_info.get('gpu', {})
        if gpu_info.get('available', False):
            fig.add_trace(
                go.Indicator(
                    mode="number",
                    value=gpu_info.get('memory_gb', 0),
                    title={'text': "GPU显存(GB)"},
                    domain={'row': 1, 'column': 2}
                ),
                row=1, col=2
            )
        else:
            fig.add_trace(
                go.Indicator(
                    mode="number",
                    value=0,
                    title={'text': "GPU不可用"},
                    domain={'row': 1, 'column': 2}
                ),
                row=1, col=2
            )
        
        # 内存信息表
        memory_info = hardware_info.get('memory', {})
        memory_table = go.Table(
            header=dict(values=['指标', '值']),
            cells=dict(values=[
                ['总内存(GB)', '可用内存(GB)', '内存使用率(%)'],
                [memory_info.get('total_gb', 0), 
                 memory_info.get('available_gb', 0),
                 memory_info.get('usage_percent', 0)]
            ])
        )
        fig.add_trace(memory_table, row=2, col=1)
        
        # 系统信息表
        system_info = {
            '操作系统': hardware_info.get('os', '未知'),
            'Python版本': hardware_info.get('python_version', '未知'),
            'ONNX Runtime版本': hardware_info.get('onnx_runtime_version', '未知')
        }
        
        system_table = go.Table(
            header=dict(values=['组件', '版本']),
            cells=dict(values=[
                list(system_info.keys()),
                list(system_info.values())
            ])
        )
        fig.add_trace(system_table, row=2, col=2)
        
        fig.update_layout(height=600, title_text="硬件配置信息")
        
        if save_path:
            fig.write_html(save_path)
            print(f"硬件信息图已保存到: {save_path}")
        
        return fig


class ReportGenerator:
    """报告生成器 - 生成完整的训练报告"""
    
    def __init__(self):
        """初始化报告生成器"""
        self.visualizer = TrainingVisualizer()
    
    def generate_comprehensive_report(self, training_results: Dict,
                                    save_dir: str = "reports") -> str:
        """
        生成综合训练报告
        
        Args:
            training_results: 训练结果字典
            save_dir: 保存目录
            
        Returns:
            报告文件路径
        """
        import os
        from datetime import datetime
        
        # 创建报告目录
        os.makedirs(save_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_dir = os.path.join(save_dir, f"training_report_{timestamp}")
        os.makedirs(report_dir, exist_ok=True)
        
        print(f"生成综合训练报告到: {report_dir}")
        
        # 生成各种图表
        charts_created = []
        
        # 1. 训练历史图
        if 'training' in training_results and hasattr(training_results['training'], 'training_history'):
            history_path = os.path.join(report_dir, "training_history.html")
            self.visualizer.plot_training_history(
                training_results['training'].training_history,
                history_path
            )
            charts_created.append("训练历史图")
        
        # 2. 损失比较图
        if 'training' in training_results:
            loss_path = os.path.join(report_dir, "loss_comparison.html")
            self.visualizer.plot_loss_comparison(training_results, loss_path)
            charts_created.append("损失比较图")
        
        # 3. 基准测试结果图
        if 'benchmark' in training_results:
            benchmark_path = os.path.join(report_dir, "benchmark_results.html")
            performance_viz = PerformanceVisualizer()
            performance_viz.plot_benchmark_results(
                training_results['benchmark'],
                benchmark_path
            )
            charts_created.append("基准测试结果图")
        
        # 4. 硬件信息图
        if 'benchmark' in training_results and 'hardware_info' in training_results['benchmark']:
            hardware_path = os.path.join(report_dir, "hardware_info.html")
            performance_viz = PerformanceVisualizer()
            performance_viz.plot_hardware_info(
                training_results['benchmark']['hardware_info'],
                hardware_path
            )
            charts_created.append("硬件信息图")
        
        # 生成文本报告
        report_path = os.path.join(report_dir, "training_report.md")
        self._generate_markdown_report(training_results, report_path, charts_created)
        
        print(f"训练报告生成完成! 共创建 {len(charts_created)} 个图表")
        return report_dir
    
    def _generate_markdown_report(self, training_results: Dict, 
                                report_path: str, charts_created: List[str]):
        """生成Markdown格式的报告"""
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("# 渐进式训练报告\n\n")
            f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            # 训练摘要
            f.write("## 训练摘要\n\n")
            if 'training' in training_results:
                training_info = training_results['training']
                f.write(f"- 总训练轮次: {training_info.get('total_epochs', 'N/A')}\n")
                f.write(f"- 最佳轮次: {training_info.get('best_epoch', 'N/A')}\n")
                f.write(f"- 最终训练损失: {training_info.get('final_train_loss', 'N/A'):.6f}\n")
                f.write(f"- 最终验证损失: {training_info.get('final_val_loss', 'N/A'):.6f}\n")
                f.write(f"- 总训练时间: {training_info.get('total_training_time', 'N/A'):.2f}秒\n\n")
            
            # 评估结果
            f.write("## 评估结果\n\n")
            if 'evaluation' in training_results:
                eval_info = training_results['evaluation']
                for metric, value in eval_info.items():
                    if isinstance(value, (int, float)):
                        f.write(f"- {metric}: {value:.6f}\n")
                f.write("\n")
            
            # 硬件信息
            f.write("## 硬件配置\n\n")
            if 'benchmark' in training_results and 'hardware_info' in training_results['benchmark']:
                hardware_info = training_results['benchmark']['hardware_info']
                cpu_info = hardware_info.get('cpu', {})
                gpu_info = hardware_info.get('gpu', {})
                memory_info = hardware_info.get('memory', {})
                
                f.write(f"- CPU: {cpu_info.get('vendor', '未知')} ({cpu_info.get('logical_cores', 0)}核心)\n")
                if gpu_info.get('available', False):
                    f.write(f"- GPU: {gpu_info.get('name', '未知')} ({gpu_info.get('memory_gb', 0)}GB)\n")
                else:
                    f.write("- GPU: 不可用\n")
                f.write(f"- 内存: {memory_info.get('total_gb', 0):.1f}GB\n\n")
            
            # 图表列表
            f.write("## 生成图表\n\n")
            for chart in charts_created:
                f.write(f"- {chart}\n")
            f.write("\n")
            
            # 优化建议
            f.write("## 优化建议\n\n")
            recommendations = self._generate_recommendations(training_results)
            
            if recommendations:
                for i, rec in enumerate(recommendations, 1):
                    f.write(f"{i}. {rec}\n")
            else:
                f.write("暂无优化建议\n")
            
            f.write("\n## 详细数据\n\n")
            f.write("详细训练数据和配置请参考同目录下的JSON文件。\n")
    
    def _generate_recommendations(self, training_results: Dict) -> List[str]:
        """生成优化建议"""
        recommendations = []
        
        if 'training' in training_results:
            training_info = training_results['training']
            
            # 检查训练损失
            final_train_loss = training_info.get('final_train_loss')
            final_val_loss = training_info.get('final_val_loss')
            
            if final_train_loss is not None and final_val_loss is not None:
                # 检查过拟合
                if final_val_loss > final_train_loss * 1.2:
                    recommendations.append("检测到可能过拟合，建议增加正则化或早停")
                
                # 检查训练轮次
                total_epochs = training_info.get('total_epochs', 0)
                if total_epochs < 50:
                    recommendations.append("训练轮次较少，建议增加训练轮次")
                elif total_epochs > 500:
                    recommendations.append("训练轮次较多，建议检查收敛情况")
            
            # 检查学习率
            if training_info.get('learning_rate', 0) > 0.01:
                recommendations.append("学习率较高，建议降低学习率")
            elif training_info.get('learning_rate', 0) < 0.0001:
                recommendations.append("学习率较低，建议增加学习率")
        
        # 硬件相关建议
        if 'benchmark' in training_results and 'hardware_info' in training_results['benchmark']:
            hardware_info = training_results['benchmark']['hardware_info']
            gpu_info = hardware_info.get('gpu', {})
            
            if not gpu_info.get('available', False):
                recommendations.append("未检测到GPU，建议使用GPU加速训练")
            else:
                gpu_memory = gpu_info.get('memory_gb', 0)
                if gpu_memory < 4:
                    recommendations.append("GPU显存较小，建议减小批次大小")
        
        return recommendations

if __name__ == "__main__":
    # 测试可视化工具
    print("测试可视化工具...")
    
    # 创建示例数据
    sample_training_history = [
        {'epoch': 1, 'train_loss': 0.8, 'val_loss': 0.9, 'epoch_time': 2.1},
        {'epoch': 2, 'train_loss': 0.6, 'val_loss': 0.7, 'epoch_time': 2.0},
        {'epoch': 3, 'train_loss': 0.4, 'val_loss': 0.5, 'epoch_time': 1.9},
        {'epoch': 4, 'train_loss': 0.3, 'val_loss': 0.4, 'epoch_time': 1.8},
        {'epoch': 5, 'train_loss': 0.2, 'val_loss': 0.3, 'epoch_time': 1.7}
    ]
    
    # 测试训练可视化器
    viz = TrainingVisualizer()
    fig = viz.plot_training_history(sample_training_history)
    print("训练历史图生成完成!")
    
    # 测试数据可视化器
    data_viz = DataVisualizer()
    X_sample = np.random.randn(100, 5)
    y_sample = np.random.rand(100, 3)
    feature_names = ['特征1', '特征2', '特征3', '特征4', '特征5']
    target_names = ['目标1', '目标2', '目标3']
    
    fig2 = data_viz.plot_feature_distributions(X_sample, feature_names)
    print("特征分布图生成完成!")
    
    print("可视化工具测试完成!")
