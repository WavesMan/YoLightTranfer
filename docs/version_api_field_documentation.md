# 版本检查 API 字段说明文档

## 概述
本文档详细说明了版本检查 API 中每个字段的意义、类型、可选性以及使用示例。

## 顶级字段

### `app` (必需)
**类型**: Object  
**说明**: 包含应用版本信息的核心对象

### `timestamp` (可选)
**类型**: String (ISO 8601 格式)  
**说明**: API 响应生成的时间戳  
**示例**: `"2025-10-26T19:00:00Z"`

### `other_field` (可选)
**类型**: Any  
**说明**: 其他自定义字段，可以包含任意数据  
**示例**: `"可以有其他字段"`

### `platforms` (可选)
**类型**: Object  
**说明**: 各平台的下载信息，支持多平台配置

### `compatibility` (可选)
**类型**: Object  
**说明**: 兼容性要求信息

---

## app 对象字段

### `version` (必需)
**类型**: String  
**说明**: 新版本号，格式为 `x.y.z` 或 `x.y.z+buildNumber`  
**示例**: `"0.1.1"`, `"1.2.3+456"`

### `url` (必需)
**类型**: String (URL)  
**说明**: 默认下载链接或应用主页  
**示例**: `"https://cloud.waveyo.cn/mirror/YoLightTransfer/index.html"`

### `description` (可选)
**类型**: String  
**说明**: 传统的纯文本更新说明，用于向后兼容  
**注意**: 如果同时存在 `changelog` 字段，此字段将被忽略

### `changelog` (可选)
**类型**: Object  
**说明**: 结构化的更新日志，比纯文本更易编辑和维护

### `force` (可选)
**类型**: Boolean  
**默认值**: `false`  
**说明**: 是否强制更新。如果为 `true`，用户无法跳过更新  
**示例**: `false`

---

## changelog 对象字段

### `title` (必需)
**类型**: String  
**说明**: 更新日志的标题  
**示例**: `"YoLightTransfer v0.1.1 更新说明"`

### `sections` (必需)
**类型**: Array of Objects  
**说明**: 更新日志的章节列表，按功能分类

### `footer` (可选)
**类型**: String  
**说明**: 更新日志的页脚信息，通常包含感谢语或建议  
**支持 Markdown 格式**: 支持在页脚中使用 Markdown 链接格式 `[文本](URL)`  
**示例**: 
```json
"footer": "感谢您使用 YoLightTransfer！建议所有用户更新到此版本以获得最佳体验。如有问题请[加入QQ群反馈](https://jq.qq.com/?_wv=1027&k=5tG6g3jE)或访问[官方网站](https://example.com)。"
```

---

## sections 数组中的章节对象

### `title` (必需)
**类型**: String  
**说明**: 章节标题，可以使用表情符号增强可读性  
**示例**: `"🚀 新功能"`, `"🐛 问题修复"`

### `type` (必需)
**类型**: String  
**说明**: 章节类型，用于确定显示样式和图标  
**支持的类型**:
- `"added"` - 新功能，显示绿色加号图标
- `"fixed"` - 问题修复，显示红色虫子图标  
- `"changed"` - 技术改进，显示橙色工具图标
- `"deprecated"` - 废弃功能，显示黄色警告图标
- 其他类型显示蓝色信息图标

### `items` (必需)
**类型**: Array of Strings  
**说明**: 章节内容项列表，每个项目描述一个具体的更新内容  
**支持 Markdown 格式**: 支持在内容中使用 Markdown 链接格式 `[文本](URL)`  
**示例**: 
```json
"items": [
  "[加入我们的QQ群反馈交流](https://jq.qq.com/?_wv=1027&k=5tG6g3jE)",
  "访问[官方网站](https://example.com)获取更多信息"
]
```

---

## platforms 对象字段

### `windows` (可选)
**类型**: Object  
**说明**: Windows 平台的下载信息

### `android` (可选)
**类型**: Object  
**说明**: Android 平台的下载信息

### 其他平台
可以添加任意平台名称作为键，如 `"linux"`, `"macos"` 等

---

## 平台特定字段 (如 windows, android)

### `download_url` (必需)
**类型**: String (URL)  
**说明**: 该平台的下载链接

### `file_size` (可选)
**类型**: Number  
**说明**: 文件大小（字节）

### `sha256` (可选)
**类型**: String  
**说明**: 文件的 SHA256 哈希值，用于完整性校验

---

## compatibility 对象字段

### `min_os_version` (可选)
**类型**: String  
**说明**: 最低支持的操作系统版本  
**示例**: `"Windows 10 / Android 8.0"`

### `supported_arch` (可选)
**类型**: Array of Strings  
**说明**: 支持的处理器架构  
**示例**: `["x64", "arm64"]`

### `required_dependencies` (可选)
**类型**: Array  
**说明**: 必需的依赖项列表  
**示例**: `[]` (空数组表示无特殊依赖)

---

## 使用优先级

1. **优先使用 `changelog`** - 如果存在 `changelog` 字段，将显示结构化的更新日志
2. **回退到 `description`** - 如果没有 `changelog`，使用传统的纯文本描述
3. **向后兼容** - 现有的纯文本 API 响应仍然可以正常工作

---

## 最佳实践

1. **版本号格式**: 使用语义化版本号 `x.y.z`
2. **章节类型**: 使用标准的类型名称确保一致的显示效果
3. **国际化**: 可以为不同语言提供多个 `changelog` 对象
4. **测试**: 使用 JSON 验证工具确保格式正确
5. **渐进式更新**: 可以先提供纯文本 `description`，后续添加 `changelog`

---

## 示例响应优先级

```json
// 优先级1: 结构化更新日志
{
  "app": {
    "version": "0.1.1",
    "url": "...",
    "changelog": { ... }
  }
}

// 优先级2: 传统纯文本
{
  "app": {
    "version": "0.1.1", 
    "url": "...",
    "description": "纯文本更新说明"
  }
}

// 向后兼容: 现有格式仍然工作
{
  "app": {
    "version": "0.1.1",
    "url": "...",
    "description": "纯文本更新说明",
    "force": false
  }
}
