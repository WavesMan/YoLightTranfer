import 'package:flutter/material.dart';

/// 输入表单组件
class InputForm extends StatelessWidget {
  final TextEditingController ssidController;
  final TextEditingController passwordController;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const InputForm({
    super.key,
    required this.ssidController,
    required this.passwordController,
    required this.isConnecting,
    required this.isConnected,
    this.onConnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SSID输入
        TextField(
          controller: ssidController,
          decoration: const InputDecoration(
            labelText: 'SSID',
            hintText: '输入热点名称',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.wifi),
          ),
        ),
        const SizedBox(height: 16),
        
        // 密码输入
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '输入热点密码',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        
        // 连接按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isConnecting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi),
            label: Text(_getConnectButtonText()),
            onPressed: isConnecting ? null : onConnect,
          ),
        ),

      ],
    );
  }

  /// 获取连接按钮文本
  String _getConnectButtonText() {
    if (isConnecting) {
      return '连接中...';
    } else if (isConnected) {
      return '重新连接';
    } else {
      return '连接';
    }
  }
}
