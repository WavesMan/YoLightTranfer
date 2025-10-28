根据我对项目的深入分析，我已经理解了当前的工程状态。现在为您提供一份详细的规划方案。

## 📋 当前工程状态总结

### ✅ 已完成的部分
1. **网络测速层** (`LanNetworkTester`)
    - 基于 HTTP GET /status 的 RTT 测量
    - 支持多设备并发测试（最多5台）
    - 丢包率和带宽启发式估算
    - 返回聚合指标 (`AggregatedMetrics`)

2. **AI 决策层** (`AINetworkAdvisor`)
    - 基于规则引擎的弱网识别
    - 支持场景切换（通用/制造/教育）
    - 防抖机制（连续3次弱网才推荐）
    - 用户拒绝冷却期管理

3. **状态管理层** (`AINetworkQualityManager`)
    - 完整的状态机（idle/detecting/noDevices/weakNetwork/normalNetwork/error）
    - 缓存机制（30秒 TTL）
    - 推荐弹窗冷却期控制
    - 与 UI 的 Provider 集成

4. **服务注入** (`main.dart`)
    - 已在 `MultiProvider` 中注册所有必要服务
    - 依赖链完整：`DeviceManager` → `LanNetworkTester` → `AINetworkQualityManager`

5. **权限声明** (`AndroidManifest.xml`)
    - 已包含 `NEARBY_WIFI_DEVICES` 权限
    - 网络、位置、文件访问权限齐全

### ⚠️ 需要完善的部分

| 项目 | 现状 | 问题 | 优先级 |
|------|------|------|--------|
| **依赖声明** | `pubspec.yaml` 缺少推理库 | 如果需要 TFLite 推理，需添加 `tflite_flutter` | 🔴 高 |
| **模型文件** | 未见 `assets/model/*.tflite` | 如果使用 TFLite，需放入 assets 并在 pubspec.yaml 声明 | 🔴 高 |
| **单元测试** | 无 `test/` 目录下的网络测试用例 | 需为 `LanNetworkTester` 和 `AINetworkAdvisor` 编写测试 | 🟡 中 |
| **iOS 配置** | 未检查 `ios/Runner/Info.plist` | 需添加 `NSLocalNetworkUsageDescription` | 🟡 中 |
| **真机验证** | 未进行实际测试 | 需在 Android/iOS 真机上验证 UDP/TCP 流量 | 🟡 中 |
| **错误路径** | 基础框架已有，但边缘条件未充分测试 | 需测试：无设备、断网、超时、模型置信度低 | 🟡 中 |

---

## 🎯 下一步规划（分阶段）

### **第一阶段：依赖与配置补全** （1-2小时）
1. **检查是否需要 TFLite 推理**
    - 当前 `AINetworkAdvisor` 使用规则引擎，不依赖 TFLite
    - 如果未来需要深度学习模型，再添加 `tflite_flutter` 依赖
    - **建议**：暂时保持现状（规则引擎足够），后续可扩展

2. **iOS 配置补全**
    - 在 `ios/Runner/Info.plist` 添加：
      ```xml
      <key>NSLocalNetworkUsageDescription</key>
      <string>应用需要访问本地网络以检测网络质量</string>
      <key>NSBonjourServices</key>
      <array>
        <string>_http._tcp</string>
      </array>
      ```

3. **运行 `flutter analyze`**
    - 检查未使用的 import、未处理的 Future、空安全警告

### **第二阶段：单元测试编写** （2-3小时）
1. **为 `LanNetworkTester` 编写测试**
    - Mock `DeviceManager` 和 `HttpClient`
    - 测试单设备测试、多设备聚合、异常处理

2. **为 `AINetworkAdvisor` 编写测试**
    - 测试弱网判断逻辑
    - 测试防抖机制（3次连续弱网）
    - 测试用户拒绝冷却期

3. **为 `AINetworkQualityManager` 编写集成测试**
    - 测试完整的检测流程
    - 测试缓存机制
    - 测试推荐弹窗冷却期

### **第三阶段：真机验证** （2-3小时）
1. **Android 验证**
    - 开启热点 A 手机，B 手机运行 App
    - 点击"手动检测"，观察 logcat 输出
    - 使用 Wireshark 抓包验证 HTTP 流量

2. **iOS 验证**
    - 在 iOS 真机上运行，检查权限申请
    - 验证网络测速是否正常工作

3. **边缘条件测试**
    - 关闭所有局域网设备 → 应返回 `noDevices`
    - 断网/飞行模式 → 应返回 `error`
    - 测速超过 6s → 应自动超时

### **第四阶段：性能与稳定性优化** （1-2小时）
1. **性能优化**
    - 检查 `LanNetworkTester` 的并发数是否合理（当前5台）
    - 优化 HTTP 连接超时参数

2. **稳定性加固**
    - 添加更详细的日志输出
    - 处理网络异常的边缘情况
    - 验证状态机的所有转移路径

---

## 📊 验收标准

| 检查项 | 标准 | 验证方法 |
|--------|------|--------|
| **工程完整性** | 无编译错误、无 lint 警告 | `flutter analyze` |
| **功能正确性** | 测速结果准确、AI 决策合理 | 单元测试 + 真机测试 |
| **用户体验** | 检测流程流畅、弹窗逻辑清晰 | 手动测试 |
| **错误处理** | 所有异常路径都有合理的降级方案 | 边缘条件测试 |
| **性能** | 检测耗时 < 6s、不阻塞 UI | 性能分析工具 |

---

## 🚀 建议的执行顺序

1. **立即执行**：运行 `flutter analyze` 检查代码质量
2. **优先执行**：补全 iOS 配置（Info.plist）
3. **并行执行**：编写单元测试 + 真机验证
4. **最后执行**：性能优化和稳定性加固

---
