# IMParseSDK 模块设计文档

## 目录

1. [模块概述](#模块概述)
2. [架构设计](#架构设计)
3. [核心组件](#核心组件)
4. [数据模型](#数据模型)
5. [渲染器设计](#渲染器设计)
6. [API 设计](#api-设计)
7. [性能优化](#性能优化)
8. [扩展性设计](#扩展性设计)
9. [依赖关系](#依赖关系)
10. [线程模型](#线程模型)
11. [错误处理](#错误处理)
12. [测试策略](#测试策略)

---

## 模块概述

### 1.1 模块定位

**IMParseSDK** 是一个用于解析和渲染富文本消息的 iOS SDK，主要功能包括：

- **解析能力**：支持 Markdown 和 Delta 格式的文本解析
- **渲染能力**：提供 UIKit 和 SwiftUI 两种渲染器
- **高级功能**：支持数学公式（KaTeX）、Mermaid 图表等复杂内容渲染
- **性能优化**：提供异步布局计算、视图复用等优化机制
- **可扩展性**：支持自定义样式、事件处理等

### 1.2 技术栈

- **语言**：Swift 5.0+
- **平台**：iOS 13.0+（UIKit），iOS 15.0+（SwiftUI）
- **核心库**：Rust（通过 FFI 桥接）
- **分发方式**：CocoaPods（支持 Subspecs）
- **架构支持**：arm64（真机）、arm64-simulator、x86_64-simulator

### 1.3 模块结构

```
IMParseSDK/
├── Core/                    # 核心解析层
│   ├── IMParseBridge.h     # C FFI 头文件
│   └── IMParseBridge.swift # Swift FFI 封装
├── Models/                  # 数据模型层
│   ├── ASTNodes.swift      # AST 节点定义
│   └── StyleConfig.swift   # 样式配置模型
├── Renderers/               # 渲染器层
│   ├── UIKitRenderer.swift              # UIKit 渲染器
│   ├── UIKitLayoutCalculator.swift      # UIKit 布局计算器
│   ├── UIKitAttributedStringBuilder.swift # 属性字符串构建器
│   ├── UIKitRenderContext.swift         # UIKit 渲染上下文
│   ├── UIKitTheme.swift                 # UIKit 主题配置
│   ├── UIKitGestureHandler.swift        # 手势处理器
│   ├── SwiftUIRenderer.swift            # SwiftUI 渲染器
│   ├── SwiftUIRenderContext.swift       # SwiftUI 渲染上下文
│   ├── MathHTMLRenderer.swift           # 数学公式渲染器
│   └── MermaidHTMLRenderer.swift        # Mermaid 图表渲染器
└── Utils/                   # 工具类
    └── SharedWebViewPool.swift          # WebView 池
```

---

## 架构设计

### 2.1 分层架构

IMParseSDK 采用**分层架构**设计，从上到下分为：

```
┌─────────────────────────────────────┐
│     应用层 (Application Layer)      │
│  - UIKit/SwiftUI 视图控制器         │
│  - 业务逻辑处理                      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     渲染层 (Rendering Layer)       │
│  - UIKitRenderer                    │
│  - SwiftUIRenderer                  │
│  - 布局计算器                       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     模型层 (Model Layer)             │
│  - ASTNodes                         │
│  - StyleConfig                      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     核心层 (Core Layer)              │
│  - IMParseCore (Rust FFI)           │
│  - 解析引擎                         │
└─────────────────────────────────────┘
```

### 2.2 数据流

```
输入文本 (Markdown/Delta)
    ↓
IMParseCore.parseMarkdown/parseDelta()
    ↓
ParseResult (包含 AST JSON)
    ↓
JSONDecoder.decode(RootNode.self)
    ↓
RootNode (AST 树)
    ↓
Renderer.render(ast:context:)
    ↓
UIView/View (渲染结果)
```

### 2.3 设计模式

#### 2.3.1 策略模式（Strategy Pattern）

- **渲染策略**：`UIKitRenderer` 和 `SwiftUIRenderer` 实现不同的渲染策略
- **布局策略**：`UIKitLayoutCalculator` 提供预计算布局策略，`UIKitRenderer.render()` 提供 Auto Layout 策略

#### 2.3.2 建造者模式（Builder Pattern）

- **属性字符串构建**：`UIKitAttributedStringBuilder` 负责构建复杂的 `NSAttributedString`
- **视图构建**：渲染器通过递归构建视图树

#### 2.3.3 观察者模式（Observer Pattern）

- **事件回调**：通过 `UIKitRenderContext` 中的回调闭包实现事件通知
- **布局变化通知**：`onLayoutHeightChanged` 回调

#### 2.3.4 单例模式（Singleton Pattern）

- **WebView 池**：`SharedWebViewPool` 提供共享的 WebView 实例
- **HTML 渲染器**：`MathHTMLRenderer.shared` 和 `MermaidHTMLRenderer.shared`

---

## 核心组件

### 3.1 IMParseCore（核心解析器）

**职责**：封装 Rust FFI 调用，提供 Swift 友好的 API

**主要方法**：
```swift
public class IMParseCore {
    // 解析 Markdown
    public static func parseMarkdown(_ input: String) -> ParseResult
    
    // 解析 Delta
    public static func parseDelta(_ input: String) -> ParseResult
    
    // 数学公式转 HTML
    public static func mathToHTML(_ content: String, display: Bool) -> ParseResult
    
    // Mermaid 图表转 HTML
    public static func mermaidToHTML(_ content: String, textColor: String, backgroundColor: String) -> ParseResult
}
```

**设计要点**：
- 使用静态方法，无需实例化
- 自动处理 C 字符串转换和内存管理
- 统一的错误处理机制

### 3.2 ASTNodes（AST 节点模型）

**职责**：定义抽象语法树（AST）的节点类型

**节点类型**：
- **块级节点**：`RootNode`, `ParagraphNode`, `HeadingNode`, `CodeBlockNode`, `ListNode`, `TableNode`, `BlockquoteNode`, `HorizontalRuleNode`
- **行内节点**：`TextNode`, `StrongNode`, `EmNode`, `UnderlineNode`, `StrikeNode`, `CodeNode`, `LinkNode`, `ImageNode`, `MentionNode`, `EmojiNode`, `ColorNode`
- **特殊节点**：`MathNode`, `MermaidNode`

**设计要点**：
- 使用 `ASTNodeWrapper` 枚举统一包装所有节点类型
- 支持 Codable 协议，便于 JSON 序列化/反序列化
- 节点结构扁平化，避免过度嵌套

### 3.3 StyleConfig（样式配置）

**职责**：定义渲染样式配置，与 Rust 端配置对应

**配置项**：
- 字体：`fontSize`, `codeFontSize`
- 颜色：`textColor`, `linkColor`, `codeBackgroundColor`, `headingColors` 等
- 间距：`paragraphSpacing`, `listItemSpacing`, `codeBlockPadding` 等
- 组件样式：表格、引用块、图片、提及等

**设计要点**：
- 与 Rust 端配置结构完全对应
- 支持从 Rust 端获取默认配置
- 支持深色模式配置

---

## 数据模型

### 4.1 ParseResult（解析结果）

```swift
public struct ParseResult {
    public let success: Bool
    public let astJSON: String?
    public let error: ParseError?
    
    public struct ParseError {
        public let code: Int32
        public let message: String
    }
}
```

**设计要点**：
- 统一的成功/失败状态
- 错误信息包含错误码和消息
- AST JSON 字符串格式，便于序列化

### 4.2 UIKitRenderContext（渲染上下文）

```swift
public struct UIKitRenderContext {
    public var theme: UIKitTheme
    public var width: CGFloat
    public var onLinkTap: ((URL) -> Void)?
    public var onImageTap: ((ImageNode) -> Void)?
    public var onMentionTap: ((MentionNode) -> Void)?
    public var onCodeBlockTap: ((CodeBlockNode) -> Void)?
    public var onMathTap: ((MathNode) -> Void)?
    public var onMermaidTap: ((MermaidNode) -> Void)?
    public var currentFont: UIFont?
    public var currentTextColor: UIColor?
    public weak var imageLoaderDelegate: UIKitImageLoaderDelegate?
    public var onLayoutHeightChanged: ((CGFloat) -> Void)?
}
```

**设计要点**：
- 包含所有渲染所需的状态和配置
- 支持事件回调，实现交互功能
- 支持上下文传递（如标题字体、颜色）

### 4.3 UIKitTheme（主题配置）

```swift
public struct UIKitTheme {
    // 字体配置
    public var font: UIFont
    public var fontSize: CGFloat
    public var codeFont: UIFont
    
    // 颜色配置
    public var textColor: UIColor
    public var linkColor: UIColor
    // ... 更多配置
    
    // 从 StyleConfig 创建
    public init(from config: StyleConfig)
    
    // 默认主题
    public static var `default`: UIKitTheme
}
```

**设计要点**：
- 从 `StyleConfig` 自动转换，避免重复定义
- 预计算 UIKit 对象（UIColor, UIFont），提高性能
- 支持自定义主题

---

## 渲染器设计

### 5.1 UIKitRenderer（UIKit 渲染器）

#### 5.1.1 渲染模式

**模式 1：Auto Layout 模式**
```swift
func render(ast: RootNode, context: UIKitRenderContext) -> UIView
```
- 使用 `UIStackView` 和 Auto Layout
- 适合动态内容、需要自动调整的场景
- 性能相对较低，但灵活性高

**模式 2：Frame 布局模式**
```swift
func renderWithFrame(ast: RootNode, context: UIKitRenderContext) -> UIView
```
- 使用 `UIKitLayoutCalculator` 预计算布局
- 所有视图使用精确的 frame 定位
- 性能更好，适合列表滚动等场景

#### 5.1.2 组件设计

**UIKitAttributedStringBuilder**
- 职责：构建 `NSAttributedString`
- 支持：文本样式（粗体、斜体、下划线、删除线）、链接、行内代码等
- 设计：单一职责，可复用

**UIKitLayoutCalculator**
- 职责：在后台线程预计算布局
- 输出：`NodeLayout` 对象，包含 frame 和内容
- 优化：避免主线程阻塞，提高滚动性能

**UIKitGestureHandler**
- 职责：处理点击事件
- 设计：使用 `TapGestureHandler` 类持有点击闭包，避免依赖渲染器实例生命周期

#### 5.1.3 特殊节点渲染

**图片渲染**
- 支持异步加载（通过 `UIKitImageLoaderDelegate`）
- 支持宽高比自适应
- 支持点击事件

**数学公式渲染**
- 使用 `MathHTMLRenderer` 将 KaTeX HTML 渲染为图片
- 支持行内和块级公式
- 使用 WebView 池优化性能

**Mermaid 图表渲染**
- 使用 `MermaidHTMLRenderer` 将 Mermaid 代码渲染为图片
- 支持自定义颜色主题
- 使用 WebView 池优化性能

### 5.2 SwiftUIRenderer（SwiftUI 渲染器）

**设计要点**：
- 使用 SwiftUI 原生组件构建视图树
- 支持声明式 UI 更新
- 与 UIKit 渲染器共享 AST 模型和样式配置

**主要方法**：
```swift
func render(ast: RootNode, context: SwiftUIRenderContext) -> AnyView
```

### 5.3 渲染流程

```
RootNode
    ↓
遍历 children
    ↓
根据节点类型选择渲染方法
    ↓
递归渲染子节点
    ↓
组合为最终视图
```

---

## API 设计

### 6.1 公共 API

#### 6.1.1 解析 API

```swift
// 解析 Markdown
let result = IMParseCore.parseMarkdown("# Hello\nWorld")

// 解析 Delta
let result = IMParseCore.parseDelta(deltaJSON)

// 检查结果
guard result.success, let astJSON = result.astJSON else {
    print("Error: \(result.error?.message ?? "Unknown")")
    return
}
```

#### 6.1.2 渲染 API

**UIKit**
```swift
// 创建渲染上下文
let context = UIKitRenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in UIApplication.shared.open(url) },
    onImageTap: { node in /* 处理图片点击 */ },
    imageLoaderDelegate: self
)

// 渲染
let renderer = UIKitRenderer()
let view = renderer.renderWithFrame(ast: rootNode, context: context)
```

**SwiftUI**
```swift
let context = SwiftUIRenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in UIApplication.shared.open(url) }
)

let renderer = SwiftUIRenderer()
let view = renderer.render(ast: rootNode, context: context)
```

### 6.2 扩展 API

#### 6.2.1 自定义样式

```swift
// 从 StyleConfig 创建主题
let config = StyleConfig.default()!
let theme = UIKitTheme(from: config)

// 自定义主题
var customTheme = UIKitTheme.default
customTheme.textColor = .systemBlue
customTheme.fontSize = 18
```

#### 6.2.2 事件处理

```swift
let context = UIKitRenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in
        // 处理链接点击
    },
    onImageTap: { node in
        // 处理图片点击
    },
    onMentionTap: { node in
        // 处理提及点击
    },
    onCodeBlockTap: { node in
        // 处理代码块点击
    },
    onMathTap: { node in
        // 处理数学公式点击
    },
    onMermaidTap: { node in
        // 处理 Mermaid 图表点击
    }
)
```

#### 6.2.3 图片加载代理

```swift
class MyViewController: UIViewController, UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
        // 使用第三方库（如 Kingfisher）加载图片
        imageView.kf.setImage(with: url) { result in
            switch result {
            case .success(let value):
                completion(value.image, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}
```

---

## 性能优化

### 7.1 布局计算优化

**预计算布局**
- 使用 `UIKitLayoutCalculator` 在后台线程计算布局
- 避免主线程阻塞，提高滚动性能
- 支持精确的 frame 定位，减少布局计算开销

**布局缓存**
- `NodeLayout` 对象可以缓存，避免重复计算
- 适合列表场景，cell 复用时可复用布局

### 7.2 视图复用

**WebView 池**
- `SharedWebViewPool` 提供共享的 WebView 实例
- 用于数学公式和 Mermaid 图表的 HTML 渲染
- 减少 WebView 创建和销毁的开销

### 7.3 异步渲染

**图片加载**
- 支持异步图片加载，不阻塞主线程
- 通过 `UIKitImageLoaderDelegate` 支持自定义加载策略
- 支持加载进度和错误处理

**HTML 渲染**
- 数学公式和 Mermaid 图表使用异步渲染
- 使用 WKWebView 在后台渲染，完成后截图

### 7.4 内存优化

**弱引用**
- 事件回调使用闭包捕获，避免循环引用
- `UIKitImageLoaderDelegate` 使用弱引用
- `TapGestureHandler` 使用关联对象保持引用，避免过早释放

**对象复用**
- `UIKitAttributedStringBuilder` 可复用
- `UIKitRenderer` 实例可复用（但通常每次创建新实例）

---

## 扩展性设计

### 8.1 节点类型扩展

**添加新节点类型**：
1. 在 `ASTNodes.swift` 中定义新节点结构体
2. 在 `ASTNodeWrapper` 枚举中添加新 case
3. 在渲染器中添加对应的渲染方法

### 8.2 样式扩展

**添加新样式属性**：
1. 在 `StyleConfig` 中添加新属性
2. 在 `UIKitTheme` 中添加对应的 UIKit 对象属性
3. 在渲染逻辑中应用新样式

### 8.3 渲染器扩展

**自定义渲染器**：
- 实现自定义渲染逻辑
- 复用 `UIKitAttributedStringBuilder` 等工具类
- 遵循 `UIKitRenderContext` 协议

### 8.4 事件扩展

**添加新事件类型**：
1. 在 `UIKitRenderContext` 中添加新回调属性
2. 在渲染器中添加事件处理逻辑
3. 使用 `UIKitGestureHandler` 处理点击事件

---

## 依赖关系

### 9.1 模块依赖

```
IMParseSDK/Core
    ↓
IMParseSDK/UIKit (依赖 Core)
    ↓
IMParseSDK/SwiftUI (依赖 Core)
    ↓
IMParseSDK/Full (依赖 UIKit + SwiftUI)
```

### 9.2 外部依赖

- **Foundation**：基础框架
- **UIKit**：UIKit 渲染器需要
- **SwiftUI**：SwiftUI 渲染器需要（iOS 15.0+）
- **WebKit**：HTML 渲染需要

### 9.3 Rust 核心库

- **im_parse_core.xcframework**：Rust 核心库
- 支持架构：arm64（真机）、arm64-simulator、x86_64-simulator
- 通过 FFI 桥接调用

---

## 线程模型

### 10.1 线程安全

**主线程操作**：
- UI 渲染必须在主线程
- 视图创建和更新必须在主线程

**后台线程操作**：
- 布局计算可以在后台线程（`UIKitLayoutCalculator`）
- AST 解析可以在后台线程
- JSON 解码可以在后台线程

### 10.2 异步处理

**推荐流程**：
```swift
// 后台线程：解析和计算布局
DispatchQueue.global(qos: .userInitiated).async {
    let result = IMParseCore.parseMarkdown(content)
    guard let astJSON = result.astJSON else { return }
    let rootNode = try? JSONDecoder().decode(RootNode.self, from: astJSON.data(using: .utf8)!)
    let layout = UIKitLayoutCalculator.calculateLayout(ast: rootNode!, context: context)
    
    // 主线程：渲染视图
    DispatchQueue.main.async {
        let view = layout.render(context: context)
        containerView.addSubview(view)
    }
}
```

---

## 错误处理

### 11.1 解析错误

```swift
let result = IMParseCore.parseMarkdown(content)
if !result.success {
    if let error = result.error {
        print("解析失败 [\(error.code)]: \(error.message)")
    }
    // 处理错误
}
```

### 11.2 渲染错误

**节点类型不匹配**：
- 使用 `ASTNodeWrapper` 枚举确保类型安全
- 在渲染方法中使用 `switch` 处理所有情况

**样式配置错误**：
- `UIKitTheme` 提供默认值，避免 nil
- 颜色解析失败时使用系统默认颜色

### 11.3 资源加载错误

**图片加载失败**：
- 通过 `UIKitImageLoaderDelegate` 的 `completion` 回调传递错误
- 渲染器显示错误提示

**HTML 渲染失败**：
- `MathHTMLRenderer` 和 `MermaidHTMLRenderer` 显示错误信息
- 使用占位视图提示用户

---

## 测试策略

### 12.1 单元测试

**解析测试**：
- 测试各种 Markdown 语法
- 测试 Delta 格式解析
- 测试错误输入处理

**渲染测试**：
- 测试各种节点类型的渲染
- 测试样式应用
- 测试事件回调

### 12.2 集成测试

**端到端测试**：
- 测试完整的解析→渲染流程
- 测试性能（布局计算时间、渲染时间）
- 测试内存使用

### 12.3 UI 测试

**视觉回归测试**：
- 截图对比测试
- 不同设备尺寸测试
- 深色模式测试

---

## 总结

IMParseSDK 是一个设计良好的模块化 SDK，具有以下特点：

1. **清晰的分层架构**：核心层、模型层、渲染层分离
2. **灵活的渲染策略**：支持 UIKit 和 SwiftUI，支持多种布局模式
3. **高性能优化**：预计算布局、视图复用、异步渲染
4. **良好的扩展性**：支持自定义样式、事件处理、节点类型
5. **完善的错误处理**：统一的错误模型和处理机制
6. **线程安全**：明确的主线程/后台线程分工

该设计文档为 SDK 的维护和扩展提供了清晰的指导。

