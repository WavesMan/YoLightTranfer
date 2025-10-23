以下为**TCP 传输控制协议技术文档**（多语言适配、跨平台方案，适用于 Android、Windows、Linux、HarmonyOS 等全平台的统一通信协议）。该协议专为**文件/数据传输任务列表+精细控制（取消、断连检测）**等需求而设计，避免语言/平台差异，易于不同开发组移植实现。

------

# TCP 文件传输控制协议技术文档

## 1. 协议通信基础

- **传输层**：TCP（可靠数据流）
- **消息帧格式**：**UTF-8编码的JSON对象，每帧以`换行（\n）`结尾**（即`一行一帧`，易于流式分割）
- **端口/Socket管理**：平台自定，建议一端持久作为Server、一端为Client

#### 示例一帧

```
{"op":"CANCEL","transferId":"file-20231012345"}
```

## 2. 消息类型与格式

| 字段       | 类型   | 必选 | 说明                             |
| ---------- | ------ | ---- | -------------------------------- |
| op         | String | 是   | 操作类型（见下表）               |
| transferId | String | 是   | 传输任务唯一ID（文件名或hash等） |
| extra      | Any    | 否   | 可选补充参数                     |

### 操作类型定义（op 字段）

| 值       | 说明                 |
| -------- | -------------------- |
| CANCEL   | 取消任务             |
| PROGRESS | 传输进度报告（见后） |
| PING     | 心跳包               |
| PONG     | 心跳回应             |
| ACK      | 普通确认响应         |
| ERROR    | 异常通知             |

### TODO：可根据业务扩展其它op（如目录、断点信息、文件属性等）

#### `extra` 字段

可传递如“断点重试位置”、“自定义错误”等平台/业务扩展内容（类型不限，JSON支持自动解析）。

------

## 3. 核心流程与协议时序

### 3.1 任务控制与状态同步

- **A、B端皆实现 Control Loop**，收到控制帧立即本地同步并回应用操作结果
- **UI操作——本地先行状态变更，并发送控制消息，另一端收到后同步变更自身业务状态＆UI。**

#### 示例时序（文件传输取消）

```
[Android]                  [Windows]
   |  --CANCEL->               |
   |                          |
   |  <-ACK/PONG--            |
   |                          |
（UI同步/本地IO挂起，全端同步取消）
```

- `CANCEL` 的响应流程与实际IO挂起/断开需业务层同步完成
- 任何一端均可发起请求，协议无主次区分

------

### 3.2 心跳与异常断连检测

- 任一端定期（推荐3~5s）发送`{"op":"PING"}`；对端收到立即回复 `{"op":"PONG"}`。
- 一定周期内未收到心跳，则认定连接断开或异常，需：**关闭本地任务并释放资源，UI同步“对方断开”**。
- 进程/killed/系统释放资源时，Socket断开；对端 `read` 或 `write` 抛出异常亦需相同处理。

------

### 3.3 传输进度报告（可选扩展）

无需频繁（建议每进度变化或定时批量上报）：

```
{"op":"PROGRESS","transferId":"f123","extra":{"transferred":123456,"total":512000}}
```

------

## 4. 跨平台（多语言）实现建议

### 4.1 消息解析与处理伪码（通用模板）

以 pseudo-python / pseudo-java 为例说明：

```
import json

def send_control(sock, op, transferId, extra=None):
    msg = {"op": op, "transferId": transferId}
    if extra is not None:
        msg["extra"] = extra
    sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))

def recv_loop(sock):
    buffer = b""
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            handle_disconnect()
            break
        buffer += chunk
        while b"\n" in buffer:
            line, buffer = buffer.split(b"\n", 1)
            msg = json.loads(line.decode())
            dispatch(msg)
```

> 各语言均有 json parse、流读写与字符串处理能力，上述结构易于实现

------

## 5. 断连安全与平台兼容补充

- **Android端**：被杀/滑掉/结束任务，Socket由系统关闭，远端可检测 EOF 或 ping 超时，不需特殊处理
- **Windows/Linux**：同理，意外exit/fatalError等关闭 socket，协议协商无需区别。
- **HarmonyOS**：同 Android 网络堆栈，协议完全无缝适配

------

## 6. 异常与扩展

- 建议所有错误或未支持操作均返回 `{"op":"ERROR","transferId":"...","extra":{...}}`
- 拓展字段均通过 `extra` 保持兼容，无须更改基础协议

------

## 7. 协议的移植/实现保障

- 所有“控制操作”通过**JSON消息**以**单独一行**分帧，避免因平台字节序/定长等问题导致兼容障碍。
- 任意平台/任意语言只需实现：Socket流读写+JSON对象解析+按逻辑分派处理即可稳定接入！
- 避免复杂粘包、分包、高层 RPC/IDL 与非标准序列化通路

------

## 8. FAQ（常见问题）

- **Q：不同平台TCP粘包/半包问题？**
    A：采用“`\n`分帧”文本协议，所有平台可用 readLine()/缓冲读方式，零成本拆帧，规避粘包问题。
- **Q：文件传输内容与控制信息如何分离？**
    A：推荐文件传输与控制消息采用“控制流+数据流分开socket”或“帧协议中区别 op 字段和 payload 类型”。全由协议层实现即可。

------

# 9. 总结：实现清单

1. 两端均需实现 TCP 连接和 Control Loop，解析/应答 JSON 控制消息
2. 主流程支持 `"CANCEL","PROGRESS","PING","PONG","ACK","ERROR"` 等 op
3. 各终端UI/业务实时同步，异常断连检测
4. **各平台/语言只需 Socket+JSON，核心只关心控制协议，其它细节可自由扩展**

------

如需具体语言（Kotlin/Java、Python、C#、C++ 等）的实现样例或工程模板，可以随时补充！