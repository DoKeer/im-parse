# IMParseSDK

IMParseSDK 是一个用于解析和渲染 Markdown 和 Delta 格式消息的 iOS SDK。

## 功能特性

- ✅ 支持 Markdown 和 Delta 格式解析
- ✅ 提供 UIKit 和 SwiftUI 两种渲染器
- ✅ 支持数学公式渲染（KaTeX）
- ✅ 支持 Mermaid 图表渲染
- ✅ 支持自定义样式配置
- ✅ 高性能的布局计算
- ✅ 异步图片加载支持

## 安装

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'IMParseSDK', :path => '../ios/IMParseSDK'
```

或者从远程仓库安装：

```ruby
pod 'IMParseSDK', :git => 'https://github.com/your-org/im-parse.git', :tag => '0.1.0'
```

然后运行：

```bash
pod install
```

## 快速开始

### 基本使用

#### SwiftUI

```swift
import SwiftUI
import IMParseSDK

struct ContentView: View {
    let message: Message
    
    var body: some View {
        let renderer = SwiftUIRenderer()
        let context = RenderContext(
            theme: .default,
            width: UIScreen.main.bounds.width - 32,
            onLinkTap: { url in
                UIApplication.shared.open(url)
            }
        )
        
        if let astJSON = message.astJSON,
           let jsonData = astJSON.data(using: .utf8),
           let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) {
            return AnyView(renderer.render(ast: rootNode, context: context))
        }
        
        return AnyView(Text(message.content))
    }
}
```

#### UIKit

```swift
import UIKit
import IMParseSDK

class MessageViewController: UIViewController {
    func renderMessage(_ message: Message) {
        let renderer = UIKitRenderer()
        let context = UIKitRenderContext(
            theme: .default,
            width: view.bounds.width - 32,
            onLinkTap: { url in
                UIApplication.shared.open(url)
            }
        )
        
        if let astJSON = message.astJSON,
           let jsonData = astJSON.data(using: .utf8),
           let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) {
            let view = renderer.render(ast: rootNode, context: context)
            view.frame = CGRect(x: 16, y: 100, width: view.bounds.width - 32, height: view.bounds.height)
            self.view.addSubview(view)
        }
    }
}
```

### 解析消息

```swift
import IMParseSDK

var message = Message(
    type: .markdown,
    content: "# Hello, World!\n\nThis is a **markdown** message.",
    sender: "Alice"
)

// 解析为 AST
message.parse()

// 转换为 HTML
if let html = message.toHTML() {
    print(html)
}

// 使用自定义样式配置
if let config = StyleConfig.default() {
    if let html = message.toHTML(config: config) {
        print(html)
    }
}
```

### 自定义样式

```swift
import IMParseSDK

// 获取默认配置
if let defaultConfig = StyleConfig.default() {
    var customConfig = defaultConfig
    customConfig.textColor = "#333333"
    customConfig.fontSize = 18
    customConfig.paragraphSpacing = 20
    
    // 使用自定义配置渲染
    let html = message.toHTML(config: customConfig)
}
```

## 架构说明

### 目录结构

```
IMParseSDK/
├── Classes/
│   ├── Core/              # 核心解析和桥接
│   │   ├── IMParseBridge.h
│   │   └── IMParseBridge.swift
│   ├── Models/            # 数据模型
│   │   ├── Message.swift
│   │   └── StyleConfig.swift
│   ├── Renderers/         # 渲染器
│   │   ├── UIKitRenderer.swift
│   │   ├── SwiftUIRenderer.swift
│   │   ├── UIKitLayoutCalculator.swift
│   │   ├── MathHTMLRenderer.swift
│   │   └── MermaidHTMLRenderer.swift
│   ├── Views/             # 视图组件
│   │   ├── MessageHTMLView.swift
│   │   └── MessageHTMLViewController.swift
│   └── Utils/             # 工具类
│       └── SharedWebViewPool.swift
├── Libraries/             # Rust 核心库
│   └── libim_parse_core.a
└── IMParseSDK.h          # Umbrella header
```

### 核心组件

- **IMParseCore**: Rust 核心解析器的 Swift 封装
- **Message**: 消息数据模型
- **StyleConfig**: 样式配置模型
- **UIKitRenderer**: UIKit 渲染器
- **SwiftUIRenderer**: SwiftUI 渲染器
- **UIKitLayoutCalculator**: 布局计算器（用于异步预计算）

## 依赖

- iOS 13.0+
- Swift 5.0+
- Rust 核心库（已包含在 SDK 中）

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

