# language: python
import requests
import json
import time
import hashlib
import hmac
import base64
from datetime import datetime
from typing import Dict, Optional, List
import threading
from dataclasses import dataclass


@dataclass
class DingTalkConfig:
    """钉钉机器人配置"""
    webhook_url: str
    secret: Optional[str] = None
    access_token: Optional[str] = None
    rate_limit: int = 20  # 每分钟最多发送消息数
    rate_window: int = 60  # 时间窗口（秒）


class DingTalkNotifier:
    """钉钉机器人通知器"""
    
    def __init__(self, config: DingTalkConfig):
        self.config = config
        self.message_queue = []
        self.last_sent_time = 0
        self.sent_count = 0
        self.lock = threading.Lock()
        
    def _generate_signature(self, timestamp: int) -> str:
        """生成签名（如果需要加签）"""
        if not self.config.secret:
            return ""
        
        string_to_sign = f"{timestamp}\n{self.config.secret}"
        hmac_code = hmac.new(
            self.config.secret.encode('utf-8'),
            string_to_sign.encode('utf-8'),
            digestmod=hashlib.sha256
        ).digest()
        
        return base64.b64encode(hmac_code).decode('utf-8')
    
    def _build_webhook_url(self) -> str:
        """构建完整的webhook URL"""
        if self.config.access_token:
            base_url = f"https://oapi.dingtalk.com/robot/send?access_token={self.config.access_token}"
        else:
            base_url = self.config.webhook_url
        
        # 如果需要加签
        if self.config.secret:
            timestamp = int(time.time() * 1000)
            sign = self._generate_signature(timestamp)
            return f"{base_url}&timestamp={timestamp}&sign={sign}"
        
        return base_url
    
    def _check_rate_limit(self) -> bool:
        """检查是否超过频率限制"""
        current_time = time.time()
        
        with self.lock:
            # 如果超过时间窗口，重置计数器
            if current_time - self.last_sent_time > self.config.rate_window:
                self.sent_count = 0
                self.last_sent_time = current_time
            
            # 检查是否超过限制
            if self.sent_count >= self.config.rate_limit:
                return False
            
            self.sent_count += 1
            return True
    
    def send_text_message(self, content: str, at_all: bool = False, at_users: List[str] = None) -> bool:
        """发送文本消息"""
        if not self._check_rate_limit():
            print("⚠️ 钉钉消息发送频率限制，跳过本次发送")
            return False
        
        payload = {
            "msgtype": "text",
            "text": {
                "content": content
            }
        }
        
        if at_all or at_users:
            payload["at"] = {}
            if at_all:
                payload["at"]["isAtAll"] = True
            if at_users:
                payload["at"]["atUserIds"] = at_users
        
        return self._send_payload(payload)
    
    def send_markdown_message(self, title: str, text: str, at_all: bool = False, at_users: List[str] = None) -> bool:
        """发送markdown格式消息"""
        if not self._check_rate_limit():
            print("⚠️ 钉钉消息发送频率限制，跳过本次发送")
            return False
        
        payload = {
            "msgtype": "markdown",
            "markdown": {
                "title": title,
                "text": text
            }
        }
        
        if at_all or at_users:
            payload["at"] = {}
            if at_all:
                payload["at"]["isAtAll"] = True
            if at_users:
                payload["at"]["atUserIds"] = at_users
        
        return self._send_payload(payload)
    
    def _send_payload(self, payload: Dict) -> bool:
        """发送HTTP请求"""
        try:
            webhook_url = self._build_webhook_url()
            headers = {
                'Content-Type': 'application/json',
                'User-Agent': 'MultiTrainManager/1.0'
            }
            
            response = requests.post(
                webhook_url,
                data=json.dumps(payload),
                headers=headers,
                timeout=10
            )
            
            result = response.json()
            if result.get('errcode') == 0:
                print(f"✅ 钉钉消息发送成功: {payload.get('msgtype', 'unknown')}")
                return True
            else:
                print(f"❌ 钉钉消息发送失败: {result.get('errmsg', 'unknown error')}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ 钉钉消息发送异常: {e}")
            return False
        except json.JSONDecodeError as e:
            print(f"❌ 钉钉响应解析失败: {e}")
            return False


class TrainingNotifier:
    """训练进度通知器"""
    
    def __init__(self, dingtalk_config: DingTalkConfig):
        self.dingtalk = DingTalkNotifier(dingtalk_config)
        self.last_notification_iteration = 0
        self.notification_interval = 10  # 每10次迭代发送一次进度通知
    
    def send_training_start_notification(self, total_iterations: int, process_count: int) -> bool:
        """发送训练开始通知"""
        title = "🚀 AI训练多开加速启动"
        text = f"""
### 🚀 AI训练多开加速启动

**训练配置:**
- 目标迭代次数: **{total_iterations}**
- 并行进程数: **{process_count}**
- 启动时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

**系统信息:**
- 平台: Windows A100
- 模式: 多进程并行训练
- 通知频率: 每{self.notification_interval}次迭代

> 训练已开始，请关注后续进度通知
        """
        return self.dingtalk.send_markdown_message(title, text, at_all=True)
    
    def send_progress_notification(self, current_iteration: int, total_iterations: int, 
                                 active_processes: int, gpu_utilization: float, 
                                 elapsed_time: float) -> bool:
        """发送进度通知"""
        # 检查是否需要发送进度通知
        if current_iteration - self.last_notification_iteration < self.notification_interval:
            return True
        
        self.last_notification_iteration = current_iteration
        
        progress_percent = (current_iteration / total_iterations) * 100
        estimated_remaining = (elapsed_time / current_iteration) * (total_iterations - current_iteration) if current_iteration > 0 else 0
        
        title = f"📊 训练进度: {progress_percent:.1f}%"
        text = f"""
### 📊 AI训练进度报告

**进度概览:**
- 当前迭代: **{current_iteration} / {total_iterations}**
- 完成度: **{progress_percent:.1f}%**
- 活跃进程: **{active_processes}**

**资源状态:**
- GPU利用率: **{gpu_utilization:.1f}%**
- 已用时间: **{elapsed_time/60:.1f}分钟**
- 预计剩余: **{estimated_remaining/60:.1f}分钟**

**统计信息:**
- 平均速度: **{current_iteration/elapsed_time*60:.1f} 迭代/分钟**
- 通知间隔: 每{self.notification_interval}次迭代

> 训练正在稳定进行中...
        """
        return self.dingtalk.send_markdown_message(title, text)
    
    def send_completion_notification(self, total_iterations: int, final_iteration: int,
                                   total_time: float, average_speed: float) -> bool:
        """发送训练完成通知"""
        title = "🎉 AI训练完成"
        text = f"""
### 🎉 AI训练任务完成

**完成统计:**
- 目标迭代: **{total_iterations}**
- 实际完成: **{final_iteration}**
- 总用时: **{total_time/60:.1f}分钟**

**性能指标:**
- 平均速度: **{average_speed:.1f} 迭代/分钟**
- 完成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

**资源利用:**
- 多开加速: 启用
- 并行效率: 优化

> 🎯 训练任务已成功完成！
        """
        return self.dingtalk.send_markdown_message(title, text, at_all=True)
    
    def send_error_notification(self, error_message: str, current_iteration: int) -> bool:
        """发送错误通知"""
        title = "❌ 训练出现异常"
        text = f"""
### ❌ 训练异常报告

**错误信息:**
```
{error_message}
```

**当前状态:**
- 当前迭代: {current_iteration}
- 发生时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

**处理建议:**
- 检查GPU资源状态
- 验证训练数据完整性
- 查看详细错误日志

> ⚠️ 请及时处理异常情况
        """
        return self.dingtalk.send_markdown_message(title, text, at_all=True)


# 默认配置（需要用户配置）
DEFAULT_DINGTALK_CONFIG = DingTalkConfig(
    webhook_url="",  # 需要用户配置钉钉机器人webhook
    secret=None,      # 如果需要加签，配置secret
    access_token=None # 或者配置access_token
)


if __name__ == "__main__":
    # 测试钉钉通知功能
    config = DingTalkConfig(
        webhook_url="https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
    )
    notifier = TrainingNotifier(config)
    
    # 测试消息发送
    notifier.send_training_start_notification(1000, 4)
