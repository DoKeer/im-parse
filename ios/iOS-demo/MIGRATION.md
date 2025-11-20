# iOS Demo 迁移说明

iOS-demo 项目已迁移为使用 IMParseSDK 作为依赖，而不是直接包含源代码。

## 变更内容

### 已删除的文件（现在由 IMParseSDK 提供）

以下文件已从 demo 项目中删除，改为从 IMParseSDK 导入：

- `IMParseBridge.h` / `IMParseBridge.swift` - Rust FFI 桥接
- `Message.swift` - 消息模型（保留 `MessageDataGenerator` 在 demo 中）
- `StyleConfig.swift` - 样式配置
- `UIKitRenderer.swift` - UIKit 渲染器
- `SwiftUIRenderer.swift` - SwiftUI 渲染器
- `UIKitLayoutCalculator.swift` - 布局计算器
- `MathHTMLRenderer.swift` - 数学公式渲染器
- `MermaidHTMLRenderer.swift` - Mermaid 图表渲染器
- `SharedWebViewPool.swift` - WebView 池
- `MessageHTMLView.swift` - SwiftUI HTML 视图
- `MessageHTMLViewController.swift` - UIKit HTML 视图控制器

### 保留的文件（Demo 特定）

- `DemoApp.swift` - 应用入口
- `UIKitMessageListViewController.swift` - UIKit 消息列表视图控制器
- `SwiftUIMessageListView.swift` - SwiftUI 消息列表视图
- `MessageDataGenerator.swift` - Demo 专用的测试数据生成器
- `Info.plist` - 应用配置
- `Assets.xcassets/` - 资源文件

## 设置步骤

### 1. 安装 CocoaPods 依赖

```bash
cd ios/iOS-demo
pod install
```

### 2. 打开工作空间

使用 Xcode 打开 `iOS-demo.xcworkspace`（不是 `.xcodeproj`）：

```bash
open iOS-demo.xcworkspace
```

### 3. 构建项目

在 Xcode 中构建并运行项目。所有 SDK 功能现在通过 `import IMParseSDK` 导入。

## 代码变更

所有使用 SDK 功能的文件都已添加 `import IMParseSDK`：

- `DemoApp.swift`
- `UIKitMessageListViewController.swift`
- `SwiftUIMessageListView.swift`
- `MessageDataGenerator.swift`

## 注意事项

1. **必须使用 `.xcworkspace`**: 使用 CocoaPods 后，必须打开 `.xcworkspace` 文件，而不是 `.xcodeproj`

2. **Rust 库构建**: 如果 SDK 的 Rust 库未构建，需要先运行：
   ```bash
   cd ../IMParseSDK
   ./build-rust-lib.sh
   ```

3. **Xcode 项目文件**: 如果遇到编译错误，可能需要：
   - 清理构建文件夹（Product > Clean Build Folder）
   - 删除 DerivedData
   - 重新运行 `pod install`

## 验证

运行项目后，应该能够：
- 正常显示 SwiftUI 和 UIKit 两个标签页
- 加载和显示测试消息
- 正确渲染 Markdown 和 Delta 格式的内容

如果遇到任何问题，请检查：
1. Podfile 中的路径是否正确
2. IMParseSDK 是否已正确构建
3. 所有导入语句是否已添加

