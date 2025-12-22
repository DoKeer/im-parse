# IMParseSDK 目录结构说明

## 目录结构

```
IMParseSDK/
├── IMParseSDK.podspec          # CocoaPods 配置文件
├── README.md                    # SDK 使用文档
├── INSTALL.md                   # 安装指南
├── STRUCTURE.md                 # 本文件 - 结构说明
├── build-rust-lib.sh            # Rust 库构建脚本
├── .gitignore                   # Git 忽略文件
└── IMParseSDK/                  # SDK 源代码目录
    ├── IMParseSDK.h             # Umbrella header
    ├── Libraries/               # Rust 静态库目录
    │   └── libim_parse_core.a   # Rust 核心静态库（通用架构）
    └── Classes/                 # Swift 源代码
        ├── Core/                # 核心解析和桥接
        │   ├── IMParseBridge.h  # C FFI 头文件
        │   └── IMParseBridge.swift  # Swift FFI 封装
        ├── Models/              # 数据模型
        │   ├── Message.swift    # 消息模型
        │   └── StyleConfig.swift # 样式配置模型
        ├── Renderers/           # 渲染器
        │   ├── UIKitRenderer.swift          # UIKit 渲染器
        │   ├── SwiftUIRenderer.swift         # SwiftUI 渲染器
        │   ├── UIKitLayoutCalculator.swift  # UIKit 布局计算器
        │   ├── MathHTMLRenderer.swift       # 数学公式 HTML 渲染器
        │   └── MermaidHTMLRenderer.swift     # Mermaid 图表 HTML 渲染器
        ├── Views/               # 视图组件
        │   ├── MessageHTMLView.swift         # SwiftUI HTML 视图
        │   └── MessageHTMLViewController.swift  # UIKit HTML 视图控制器
        └── Utils/               # 工具类
            └── SharedWebViewPool.swift       # WebView 池（用于数学公式和图表）
```

## 核心类说明

### Core（核心层）

- **IMParseBridge.h/swift**: Rust FFI 桥接层，提供 C 接口的 Swift 封装
  - `IMParseCore`: 核心解析器类
  - `ParseResult`: 解析结果结构体

### Models（模型层）

- **Message.swift**: 消息数据模型
  - `Message`: 消息结构体，支持 Markdown 和 Delta 格式
  - `MessageType`: 消息类型枚举
  - 提供解析、布局计算、HTML 转换等功能

- **StyleConfig.swift**: 样式配置模型
  - `StyleConfig`: 样式配置结构体
  - 与 Rust 端的样式配置对应
  - 支持默认和深色模式配置

### Renderers（渲染器层）

- **UIKitRenderer.swift**: UIKit 渲染器
  - 将 AST 渲染为 UIKit 视图
  - 支持自定义主题和回调

- **SwiftUIRenderer.swift**: SwiftUI 渲染器
  - 将 AST 渲染为 SwiftUI 视图
  - 包含所有 AST 节点类型的定义
  - 支持自定义主题和回调

- **UIKitLayoutCalculator.swift**: UIKit 布局计算器
  - 在后台线程预计算布局
  - `NodeLayout`: 布局节点类
  - 支持异步布局计算

- **MathHTMLRenderer.swift**: 数学公式 HTML 渲染器
  - 使用 KaTeX 渲染数学公式
  - 支持行内和块级公式

- **MermaidHTMLRenderer.swift**: Mermaid 图表 HTML 渲染器
  - 使用 Mermaid.js 渲染图表
  - 支持多种图表类型

### Views（视图层）

- **MessageHTMLView.swift**: SwiftUI HTML 视图
  - 用于显示 HTML 格式的消息内容

- **MessageHTMLViewController.swift**: UIKit HTML 视图控制器
  - 用于显示 HTML 格式的消息内容

### Utils（工具层）

- **SharedWebViewPool.swift**: WebView 池
  - 复用 WebView 实例，提高性能
  - 用于数学公式和 Mermaid 图表的渲染

## Rust 核心库

Rust 核心库位于 `Libraries/libim_parse_core.a`，是一个通用静态库，包含以下架构：
- `arm64` (iOS 设备)
- `arm64-apple-ios-sim` (Apple Silicon 模拟器)
- `x86_64-apple-ios` (Intel Mac 模拟器，可选)

使用 `build-rust-lib.sh` 脚本可以自动构建并合并这些架构。

## 使用流程

1. **解析**: 使用 `IMParseCore` 解析 Markdown 或 Delta 格式
2. **转换**: 将解析结果转换为 AST JSON
3. **渲染**: 使用 `UIKitRenderer` 或 `SwiftUIRenderer` 渲染 AST
4. **布局**: 可选使用 `UIKitLayoutCalculator` 预计算布局

## 依赖关系

```
IMParseCore (Rust FFI)
    ↓
Message / StyleConfig (Models)
    ↓
UIKitRenderer / SwiftUIRenderer (Renderers)
    ↓
Views (UI Components)
```

## 注意事项

1. **AST 类型定义**: AST 节点类型定义在 `SwiftUIRenderer.swift` 中，UIKit 渲染器也使用这些类型
2. **静态库**: Rust 核心库需要在使用前构建，使用 `build-rust-lib.sh` 脚本
3. **模块导入**: SDK 内部文件不需要导入 `IMParseSDK`，只有外部使用时才需要
4. **线程安全**: 布局计算应在后台线程进行，渲染应在主线程进行

