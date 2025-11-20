# iOS Demo 使用 IMParseSDK

iOS-demo 项目现在使用 IMParseSDK 作为依赖库，而不是直接包含源代码。

## 快速开始

### 1. 安装依赖

```bash
cd ios/iOS-demo
pod install
```

### 2. 打开项目

使用 Xcode 打开工作空间（**不是**项目文件）：

```bash
open iOS-demo.xcworkspace
```

### 3. 运行

在 Xcode 中构建并运行项目。

## 项目结构

### Demo 特定文件

- `DemoApp.swift` - 应用入口和主视图
- `UIKitMessageListViewController.swift` - UIKit 消息列表视图控制器
- `SwiftUIMessageListView.swift` - SwiftUI 消息列表视图
- `MessageDataGenerator.swift` - 测试数据生成器（Demo 专用）

### SDK 依赖

所有核心功能现在通过 `IMParseSDK` 提供：

- 消息解析和渲染
- UIKit 和 SwiftUI 渲染器
- 样式配置
- 数学公式和 Mermaid 图表支持

## 使用示例

### 导入 SDK

```swift
import IMParseSDK
```

### 创建和解析消息

```swift
var message = Message(
    type: .markdown,
    content: "# Hello, World!",
    sender: "Alice"
)

message.parse()
```

### 使用渲染器

#### SwiftUI

```swift
let renderer = SwiftUIRenderer()
let context = RenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in
        UIApplication.shared.open(url)
    }
)

if let astJSON = message.astJSON,
   let jsonData = astJSON.data(using: .utf8),
   let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) {
    let view = renderer.render(ast: rootNode, context: context)
    // 使用 view
}
```

#### UIKit

```swift
let renderer = UIKitRenderer()
let context = UIKitRenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in
        UIApplication.shared.open(url)
    }
)

if let astJSON = message.astJSON,
   let jsonData = astJSON.data(using: .utf8),
   let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) {
    let view = renderer.render(ast: rootNode, context: context)
    // 添加到视图层次结构
}
```

## 注意事项

1. **必须使用 `.xcworkspace`**: 使用 CocoaPods 后，必须打开工作空间文件
2. **Rust 库**: 确保 IMParseSDK 的 Rust 库已构建（运行 `../IMParseSDK/build-rust-lib.sh`）
3. **清理构建**: 如果遇到问题，尝试清理构建文件夹

## 更多信息

- SDK 文档: `../IMParseSDK/README.md`
- 迁移说明: `MIGRATION.md`
- SDK 安装指南: `../IMParseSDK/INSTALL.md`

