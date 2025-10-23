# 轻量化跨端文件传输工具（Golang核心+前端UI）开发技术路线文档


## 一、项目定位与目标
### 1. 产品定位
一款**轻量化局域网跨端文件传输工具**，支持Windows、安卓、鸿蒙三端互传，核心特点：
- 零配置：打开即用，自动发现局域网内设备
- 无依赖：无需联网，不依赖服务器，纯局域网通信
- 极简操作：设备列表可视化，点选+拖放即可完成传输


### 2. 技术架构（核心更新）
采用**“Golang统一核心逻辑+前端统一UI+分端容器桥接”**架构，最大化代码复用率：
```
┌─────────────────────────────────────────────┐
│  核心逻辑层（Golang）                        │
│  （UDP发现/TCP传输/协议解析，三端共用代码）     │
│  编译为：Windows(.exe) / 安卓(.so) / 鸿蒙(.hsp) │
└───────────────────────┬─────────────────────┘
                        │
┌───────────────────────┼─────────────────────┐
│  桥接层（分端实现）      │                     │
│  ├─ Windows：Tauri进程通信                   │
│  ├─ 安卓：JNI接口                            │
│  └─ 鸿蒙：HSP接口                             │
└───────────────────────┼─────────────────────┘
                        │
┌───────────────────────┼─────────────────────┐
│  前端UI层（HTML+JS）   │                     │
│  （三端共用一套代码：设备列表/传输控制）        │
└───────────────────────┼─────────────────────┘
                        │
┌───────────────────────┼─────────────────────┐
│  容器层（分端实现）     │                     │
│  ├─ Windows：Tauri（WebView）                │
│  ├─ 安卓：原生WebView                        │
│  └─ 鸿蒙：Web组件                             │
└─────────────────────────────────────────────┘
```


## 二、开发路径规划（8周周期）

### 阶段1：Golang核心逻辑开发（第1-2周）

#### 1. 核心模块设计与实现

**目标**：完成UDP设备发现、TCP文件传输的核心逻辑，输出可跨平台编译的Golang代码。

| 模块         | 功能点                          | 关键代码示例                          |
|--------------|---------------------------------|---------------------------------------|
| 协议定义     | 统一UDP心跳包/TCP文件头格式     | ```go<br>// 设备心跳包结构<br>type Heartbeat struct {<br>  AppKey    string `json:"app_key"`   // 应用标识<br>  DeviceID  string `json:"device_id"` // 设备唯一ID<br>  DeviceName string `json:"device_name"` // 设备名<br>  OS        string `json:"os"`        // 系统类型<br>  TcpPort   int    `json:"tcp_port"`  // TCP端口<br>  Timestamp int64  `json:"timestamp"` // 时间戳<br>}<br>``` |
| UDP发现      | 发送广播/监听设备/离线判断      | 实现`StartBroadcast()`（发送心跳）和`StartListener()`（监听并解析设备），通过时间戳判断设备在线状态（10秒超时） |
| TCP传输      | 分片发送/断点续传/进度反馈      | 实现`TCPServer`（接收文件）和`TCPClient`（发送文件），支持1MB分片传输，记录已传偏移量实现断点续传 |
| 设备管理     | 在线设备列表维护/排序           | 用`map`存储设备信息，按“最近活跃时间”排序，提供`GetOnlineDevices()`接口 |

#### 2. 多平台编译配置
编写自动化编译脚本（`build_core.sh`），输出三端核心文件：
```bash
# Windows端（64位exe）
GOOS=windows GOARCH=amd64 go build -o dist/core/win/transfer_core.exe ./cmd

# 安卓端（arm64动态库）
export NDK_HOME=/path/to/android-ndk
CC=$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang
GOOS=android GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o dist/core/android/libtransfer.so ./cmd

# 鸿蒙端（HSP包，依赖鸿蒙SDK）
go build -buildmode=c-shared -o dist/core/harmony/libtransfer.so ./cmd
hsp-packer --input dist/core/harmony --output dist/core/harmony/transfer_core.hsp
```


### 阶段2：前端UI开发（第2-3周）
#### 1. 界面设计（极简风格）
**核心页面**：
- 主界面：顶部设备列表（显示在线设备名称/系统）+ 中部文件拖放区 + 底部传输进度条
- 传输历史：点击右上角图标查看历史记录（文件名/大小/时间/状态）

#### 2. 前端与核心层通信接口定义
封装统一的`bridge.js`接口（三端共用，分端实现具体逻辑）：
```javascript
// 前端调用核心层的接口
const Bridge = {
  // 启动设备发现（参数：设备名）
  startDiscovery: (deviceName) => {},
  // 发送文件（参数：目标IP/端口/本地文件路径）
  sendFile: (ip, port, filePath) => {},
  // 注册设备变化回调（核心层通知UI更新设备列表）
  onDeviceUpdate: (callback) => {},
  // 注册传输进度回调（核心层通知UI更新进度）
  onTransferProgress: (callback) => {}
};
```

#### 3. 前端实现
- 技术栈：HTML5 + Tailwind CSS + 原生JS（避免框架依赖，压缩后体积<50KB）
- 关键功能：
  - 设备列表动态渲染（收到`onDeviceUpdate`回调时更新）
  - 文件拖放选择（支持单文件/多文件）
  - 传输进度实时展示（百分比+已传大小）


### 阶段3：分端容器集成（第4-6周）
#### 1. Windows端（Tauri + Golang.exe）
**集成步骤**：
1. 初始化Tauri项目，将前端资源（HTML/JS/CSS）放入`src`目录
2. 配置`tauri.conf.json`：声明文件访问权限、嵌入Golang核心`transfer_core.exe`
3. 实现桥接逻辑（Tauri调用Golang.exe）：
   ```rust
   // src-tauri/src/main.rs（Tauri后端）
   use std::process::Command;
   use tauri::Manager;
   
   // 启动Golang核心进程
   let core_process = Command::new("transfer_core.exe")
       .arg("--mode=ipc")
       .spawn()
       .unwrap();
   
   // 前端调用startDiscovery时，转发给Golang
   #[tauri::command]
   fn start_discovery(device_name: &str) {
       core_process.stdin.as_ref().unwrap().write_all(
           format!("{{\"action\":\"start_discovery\",\"params\":{{\"name\":\"{}\"}}}}\n", device_name).as_bytes()
       ).unwrap();
   }
   
   // 监听Golang的输出，转发给前端
   tauri::async_runtime::spawn(async move {
       let mut buf = String::new();
       core_process.stdout.as_ref().unwrap().read_to_string(&mut buf).unwrap();
       app.emit_all("device_update", buf).unwrap();
   });
   ```
4. 前端`bridge.js`实现（调用Tauri接口）：
   ```javascript
   Bridge.startDiscovery = async (deviceName) => {
     await window.__TAURI__.invoke('start_discovery', { deviceName });
   };
   ```

#### 2. 安卓端（WebView + Golang.so）
**集成步骤**：
1. 创建安卓项目，将前端资源放入`src/main/assets`，Golang的`libtransfer.so`放入`src/main/jniLibs/arm64-v8a`
2. 配置WebView：启用JS、允许文件访问、注入Java桥接类`TransferBridge`
3. 实现Java与Golang的JNI交互：
   ```java
   // TransferBridge.java
   public class TransferBridge {
       static { System.loadLibrary("transfer"); } // 加载Golang动态库
   
       // JNI声明（对应Golang导出函数）
       private native void startDiscovery(String deviceName);
       private native void sendFile(String ip, int port, String filePath);
   
       // 供JS调用的接口
       @JavascriptInterface
       public void jsStartDiscovery(String deviceName) {
           startDiscovery(deviceName);
       }
   
       // Golang回调Java（通知设备更新）
       public void onDeviceUpdate(String deviceJson) {
           webView.post(() -> {
               webView.evaluateJavascript("Bridge.onDeviceUpdate(" + deviceJson + ")", null);
           });
       }
   }
   ```
4. 前端`bridge.js`实现（调用Java接口）：
   ```javascript
   Bridge.startDiscovery = (deviceName) => {
     window.TransferBridge.jsStartDiscovery(deviceName);
   };
   ```

#### 3. 鸿蒙端（Web组件 + Golang.hsp）
**集成步骤**：
1. 创建鸿蒙应用项目，将前端资源放入`src/main/rawfile`，Golang的`transfer_core.hsp`放入`entry/libs`
2. 配置Web组件加载本地前端页面，启用JS交互：
   ```xml
   <!-- main_pages.json -->
   {
     "src": "$rawfile/index.html",
     "javaScriptAccess": true,
     "fileAccess": true
   }
   ```
3. 实现鸿蒙与Golang的HSP交互：
   ```typescript
   // 导入Golang的HSP包
   import transferCore from '@ohos.transfer_core';
   
   // 接收前端JS调用
   webComponent.onMessageReceived((msg) => {
     const data = JSON.parse(msg);
     if (data.action === 'start_discovery') {
       // 调用Golang核心函数
       transferCore.startDiscovery(data.params.deviceName, (devices) => {
         // 回调前端更新设备列表
         webComponent.postMessageToWeb({
           action: 'device_update',
           data: devices
         });
       });
     }
   });
   ```
4. 前端`bridge.js`实现（调用鸿蒙接口）：
   ```javascript
   Bridge.startDiscovery = (deviceName) => {
     window.webkit.messageHandlers.harmony.postMessage({
       action: 'start_discovery',
       params: { deviceName }
     });
   };
   ```


### 阶段4：三端联调与优化（第7周）
#### 1. 联调场景覆盖
- 跨系统设备发现：Windows ↔ 安卓、安卓 ↔ 鸿蒙、Windows ↔ 鸿蒙（验证发现成功率>95%）
- 文件传输测试：
  - 小文件（1KB文本）：验证传输完整性
  - 大文件（1GB视频）：验证断点续传和稳定性
  - 多文件（5个50MB图片）：验证批量传输效率

#### 2. 优化方向
- **性能优化**：
  - 调整TCP分片大小（根据局域网带宽动态适配，默认1MB）
  - 鸿蒙端启用分布式网络能力，提升跨设备发现效率
- **体验优化**：
  - 传输完成后弹窗提示（适配各端系统风格）
  - 设备列表按“距离”（网络延迟）排序，优先显示响应快的设备
- **兼容性优化**：
  - 处理安卓13+的文件访问权限限制（使用SAF框架）
  - 适配Windows防火墙自动放行规则（添加端口例外）


### 阶段5：打包与发布（第8周）
| 平台   | 打包方式                          | 交付物规格                          |
|--------|-----------------------------------|-------------------------------------|
| Windows | Tauri build 生成单文件EXE          | 体积<15MB，支持Win10+               |
| 安卓   | Android Studio 生成签名APK         | 体积<20MB，支持Android 7.0+         |
| 鸿蒙   | DevEco Studio 打包HAP包            | 体积<18MB，支持HarmonyOS 3.0+       |

**发布准备**：
- 编写用户手册（仅1页，说明“打开→选设备→拖文件”三步操作）
- 准备各平台应用商店截图（突出“无网传输”“极简操作”卖点）


## 三、技术难点与解决方案
| 难点场景                | 解决方案                                  |
|-------------------------|-------------------------------------------|
| 三端Golang代码兼容       | 用`build tag`隔离平台特定代码（如文件路径处理），核心逻辑保持一致：<br>`// +build android`<br>`package platform` |
| 大文件传输内存溢出       | 采用流式读写（`os.Open`+`bufio.Reader`），分片传输不加载完整文件到内存 |
| 鸿蒙HSP包调用限制        | 提前申请鸿蒙开发者认证，使用API 9+版本，避免调用私有接口 |
| 跨网段设备发现失败       | 同时发送UDP广播（255.255.255.255）和多播（224.0.0.1），提升覆盖范围 |


## 四、里程碑交付物
| 时间节点   | 交付物                                  | 验收标准                          |
|------------|-----------------------------------------|-----------------------------------|
| 第2周末    | Golang核心逻辑代码+单元测试             | 单端可运行，通过UDP发现和TCP传输测试 |
| 第3周末    | 前端UI代码（HTML+JS）                   | 静态页面可交互，调用模拟bridge接口正常 |
| 第6周末    | 三端独立运行版本                        | 单端内可完成“发现设备+传输文件”全流程 |
| 第7周末    | 跨端联调版本                            | 三端任意两两组合，文件传输成功率100% |
| 第8周末    | 正式发布包+用户手册                     | 安装包通过各平台兼容性测试，操作流程≤3步 |


该路线通过“Golang核心统一+前端UI统一”，将三端开发工作量减少60%以上，同时保证功能一致性和轻量化特性。开发过程中可优先完成Windows+安卓版本，鸿蒙版本作为补充，降低初期风险。