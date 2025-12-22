# IMParseSDK 使用指南

## 目录

1. [快速开始](#快速开始)
2. [在 UIKit CollectionView Cell 中接入](#在-uikit-collectionview-cell-中接入)
3. [核心 API 说明](#核心-api-说明)
4. [高级用法](#高级用法)
5. [性能优化建议](#性能优化建议)

---

## 快速开始

### 1. 导入 SDK

```swift
import IMParseSDK
```

### 2. 基本使用流程

```swift
// 1. 解析 Markdown 或 Delta 内容
let result = IMParseCore.parseMarkdown("# Hello World\n\nThis is a **markdown** text.")

// 2. 检查解析结果
guard result.success, let astJSON = result.astJSON else {
    print("解析失败: \(result.error?.message ?? "未知错误")")
    return
}

// 3. 解码为 AST 节点
let jsonData = astJSON.data(using: .utf8)!
let rootNode = try JSONDecoder().decode(RootNode.self, from: jsonData)

// 4. 创建渲染上下文
let context = UIKitRenderContext(
    theme: .default,
    width: 300, // 内容宽度
    onLinkTap: { url in
        UIApplication.shared.open(url)
    }
)

// 5. 渲染为 UIView
let renderer = UIKitRenderer()
let contentView = renderer.renderWithFrame(ast: rootNode, context: context)

// 6. 添加到视图层次结构
containerView.addSubview(contentView)
```

---

## 在 UIKit CollectionView Cell 中接入

### 场景：替换现有的 Markdown 解析和渲染逻辑

假设你有一个现有的 CollectionView Cell，需要将 Markdown 解析和渲染改为使用 IMParseSDK。

### 步骤 1：定义消息模型（可选）

如果你的项目还没有消息模型，可以创建一个：

```swift
import Foundation
import IMParseSDK

struct Message {
    let id: String
    let content: String // Markdown 或 Delta 内容
    var astJSON: String? // 解析后的 AST JSON
    var layout: NodeLayout? // 预计算的布局（可选，用于性能优化）
    
    /// 解析内容为 AST
    mutating func parse() {
        let result = IMParseCore.parseMarkdown(content)
        if result.success {
            self.astJSON = result.astJSON
        }
    }
    
    /// 预计算布局（在后台线程执行）
    mutating func calculateLayout(width: CGFloat) {
        // 确保已解析
        if astJSON == nil {
            parse()
        }
        
        guard let astJSON = astJSON,
              let jsonData = astJSON.data(using: .utf8),
              let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) else {
            return
        }
        
        let context = UIKitRenderContext(
            theme: .default,
            width: width
        )
        
        self.layout = UIKitLayoutCalculator.calculateLayout(ast: rootNode, context: context)
    }
}
```

### 步骤 2：创建 CollectionView Cell

```swift
import UIKit
import IMParseSDK

class MessageCollectionViewCell: UICollectionViewCell {
    
    // 内容容器视图
    private let contentContainerView = UIView()
    
    // 当前显示的内容视图
    private var currentContentView: UIView?
    
    // 当前消息
    private var message: Message?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentContainerView)
        
        NSLayoutConstraint.activate([
            contentContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            contentContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    /// 配置 Cell（方法 1：使用预计算布局，推荐）
    func configure(with message: Message, contentWidth: CGFloat) {
        self.message = message
        
        // 清除旧的内容视图
        currentContentView?.removeFromSuperview()
        currentContentView = nil
        
        // 优先使用预计算的布局
        if let layout = message.layout {
            let context = UIKitRenderContext(
                theme: .default,
                width: contentWidth,
                onLinkTap: { url in
                    UIApplication.shared.open(url)
                },
                imageLoaderDelegate: self // 实现图片加载代理
            )
            
            // 使用预计算的布局渲染
            let astView = layout.render(context: context)
            astView.frame = CGRect(origin: .zero, size: layout.frame.size)
            
            contentContainerView.addSubview(astView)
            currentContentView = astView
            return
        }
        
        // 如果没有预计算布局，实时解析和渲染
        renderMessage(message, contentWidth: contentWidth)
    }
    
    /// 配置 Cell（方法 2：实时解析和渲染）
    func configureRealtime(with message: Message, contentWidth: CGFloat) {
        self.message = message
        renderMessage(message, contentWidth: contentWidth)
    }
    
    /// 渲染消息内容
    private func renderMessage(_ message: Message, contentWidth: CGFloat) {
        // 清除旧的内容视图
        currentContentView?.removeFromSuperview()
        currentContentView = nil
        
        // 如果有 AST JSON，直接使用
        if let astJSON = message.astJSON {
            renderFromAST(astJSON: astJSON, contentWidth: contentWidth)
            return
        }
        
        // 否则需要先解析
        var mutableMessage = message
        mutableMessage.parse()
        
        if let astJSON = mutableMessage.astJSON {
            renderFromAST(astJSON: astJSON, contentWidth: contentWidth)
        } else {
            // 解析失败，显示原始文本
            showPlainText(message.content)
        }
    }
    
    /// 从 AST JSON 渲染
    private func renderFromAST(astJSON: String, contentWidth: CGFloat) {
        guard let jsonData = astJSON.data(using: .utf8),
              let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) else {
            showPlainText(message?.content ?? "")
            return
        }
        
        // 创建渲染上下文
        let context = UIKitRenderContext(
            theme: .default,
            width: contentWidth,
            onLinkTap: { url in
                UIApplication.shared.open(url)
            },
            imageLoaderDelegate: self
        )
        
        // 使用 UIKitRenderer 渲染
        let renderer = UIKitRenderer()
        let astView = renderer.renderWithFrame(ast: rootNode, context: context)
        
        // 设置 frame（renderWithFrame 返回的视图已经计算好尺寸）
        astView.frame = CGRect(origin: .zero, size: astView.bounds.size)
        
        contentContainerView.addSubview(astView)
        currentContentView = astView
    }
    
    /// 显示纯文本（解析失败时的降级方案）
    private func showPlainText(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        contentContainerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            label.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor)
        ])
        
        currentContentView = label
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentContentView?.removeFromSuperview()
        currentContentView = nil
        message = nil
    }
}

// MARK: - UIKitImageLoaderDelegate

extension MessageCollectionViewCell: UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
        // 使用你项目中的图片加载库（如 Kingfisher、SDWebImage 等）
        // 示例：使用 URLSession
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "ImageLoadError", code: -1, userInfo: nil))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(image, nil)
            }
        }.resume()
    }
}
```

### 步骤 3：在 CollectionView 中使用

```swift
class MessageListViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var messages: [Message] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        loadMessages()
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MessageCollectionViewCell.self, forCellWithReuseIdentifier: "MessageCell")
        
        // 设置布局
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        collectionView.collectionViewLayout = layout
    }
    
    private func loadMessages() {
        // 计算内容宽度（根据你的布局调整）
        let screenWidth = view.bounds.width
        let contentWidth = screenWidth - 32 // 左右各 16 的边距
        
        // 在后台线程解析和预计算布局
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var processedMessages = self?.messages ?? []
            
            for i in 0..<processedMessages.count {
                // 解析
                processedMessages[i].parse()
                // 预计算布局
                processedMessages[i].calculateLayout(width: contentWidth)
            }
            
            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self?.messages = processedMessages
                self?.collectionView.reloadData()
            }
        }
    }
}

extension MessageListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MessageCell", for: indexPath) as! MessageCollectionViewCell
        
        let message = messages[indexPath.item]
        let contentWidth = collectionView.bounds.width - 32 // 根据实际布局调整
        
        // 使用预计算布局（推荐）
        cell.configure(with: message, contentWidth: contentWidth)
        
        return cell
    }
}

extension MessageListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let message = messages[indexPath.item]
        let contentWidth = collectionView.bounds.width - 32
        
        // 如果有预计算的布局，使用精确高度
        if let layout = message.layout {
            let height = layout.frame.height + 16 // 加上上下边距
            return CGSize(width: collectionView.bounds.width, height: height)
        }
        
        // 否则返回估算高度
        return CGSize(width: collectionView.bounds.width, height: 100)
    }
}
```

---

## 核心 API 说明

### IMParseCore

核心解析类，提供以下静态方法：

#### 解析方法

```swift
// 解析 Markdown 为 AST JSON
static func parseMarkdown(_ input: String) -> ParseResult

// 解析 Delta 为 AST JSON
static func parseDelta(_ input: String) -> ParseResult

// Markdown 转 HTML
static func markdownToHTML(_ input: String) -> ParseResult
static func markdownToHTML(_ input: String, config: StyleConfig?) -> ParseResult

// Delta 转 HTML
static func deltaToHTML(_ input: String) -> ParseResult
static func deltaToHTML(_ input: String, config: StyleConfig?) -> ParseResult
```

#### ParseResult

```swift
public struct ParseResult {
    public let success: Bool
    public let astJSON: String?  // 解析成功时的 AST JSON 字符串
    public let error: ParseError? // 解析失败时的错误信息
}
```

### UIKitRenderer

UIKit 渲染器，提供两种渲染方式：

#### 1. renderWithFrame（推荐）

使用 frame 布局，性能更好，适合需要精确控制高度的场景：

```swift
let renderer = UIKitRenderer()
let view = renderer.renderWithFrame(ast: rootNode, context: context)
// view.bounds.size 已经包含计算好的尺寸
```

#### 2. render

使用 Auto Layout，适合需要动态调整的场景：

```swift
let renderer = UIKitRenderer()
let view = renderer.render(ast: rootNode, context: context)
// 需要设置约束或使用 UIStackView
```

### UIKitLayoutCalculator

布局计算器，用于预计算布局（在后台线程执行）：

```swift
let layout = UIKitLayoutCalculator.calculateLayout(ast: rootNode, context: context)
// layout.frame 包含计算好的尺寸
// layout.render(context:) 可以渲染为 UIView
```

### UIKitRenderContext

渲染上下文，包含主题、宽度、回调等配置：

```swift
let context = UIKitRenderContext(
    theme: .default,                    // 主题配置
    width: 300,                         // 内容宽度
    onLinkTap: { url in ... },         // 链接点击回调
    onImageTap: { imageNode in ... },  // 图片点击回调（可选）
    onMentionTap: { mentionNode in ... }, // 提及点击回调（可选）
    imageLoaderDelegate: self,         // 图片加载代理（可选）
    onLayoutHeightChanged: { height in ... } // 布局高度变化回调（可选）
)
```

### UIKitTheme

主题配置，可以通过 `UIKitTheme.default` 使用默认主题，或自定义：

```swift
var theme = UIKitTheme.default
theme.font = .systemFont(ofSize: 18)
theme.textColor = .label
theme.linkColor = .systemBlue
// ... 更多配置
```

---

## 高级用法

### 自定义主题

```swift
let customTheme = UIKitTheme(
    font: .systemFont(ofSize: 16),
    fontSize: 16,
    codeFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
    textColor: .label,
    linkColor: .systemBlue,
    codeBackgroundColor: UIColor(white: 0.95, alpha: 1.0),
    codeTextColor: .label,
    headingColors: [.label, .label, .label, .label, .label, .label],
    paragraphSpacing: 16,
    listItemSpacing: 8,
    codeBlockPadding: 16,
    codeBlockBorderRadius: 8,
    tableCellPadding: 8,
    tableBorderColor: UIColor.gray.withAlphaComponent(0.3),
    tableHeaderBackground: UIColor.gray.withAlphaComponent(0.1),
    blockquoteBorderWidth: 4,
    blockquoteBorderColor: UIColor.gray.withAlphaComponent(0.3),
    blockquoteTextColor: .secondaryLabel,
    imageBorderRadius: 8,
    imageMargin: 16,
    mentionBackground: UIColor.systemBlue.withAlphaComponent(0.1),
    mentionTextColor: .systemBlue,
    cardBackground: UIColor.systemGray6,
    cardBorderColor: UIColor.gray.withAlphaComponent(0.3),
    cardPadding: 16,
    cardBorderRadius: 8,
    hrColor: .separator,
    lineHeight: 1.6,
    maxContentWidth: 800,
    contentPadding: 20
)

let context = UIKitRenderContext(theme: customTheme, width: 300)
```

### 处理链接点击

```swift
let context = UIKitRenderContext(
    theme: .default,
    width: 300,
    onLinkTap: { url in
        // 自定义链接处理逻辑
        if url.scheme == "http" || url.scheme == "https" {
            UIApplication.shared.open(url)
        } else if url.scheme == "app" {
            // 处理应用内链接
            handleAppLink(url)
        }
    }
)
```

### 处理图片加载

实现 `UIKitImageLoaderDelegate` 协议：

```swift
extension YourViewController: UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
        // 使用 Kingfisher
        imageView.kf.setImage(
            with: url,
            placeholder: nil,
            options: [.transition(.fade(0.2))],
            completionHandler: { result in
                switch result {
                case .success(let value):
                    completion(value.image, nil)
                case .failure(let error):
                    completion(nil, error)
                }
            }
        )
    }
}
```

### 处理布局高度变化

如果内容高度可能动态变化（如图片加载后），可以使用回调：

```swift
let context = UIKitRenderContext(
    theme: .default,
    width: 300,
    onLayoutHeightChanged: { newHeight in
        // 通知 CollectionView 更新 cell 高度
        collectionView.performBatchUpdates(nil, completion: nil)
    }
)
```

---

## 性能优化建议

### 1. 预计算布局

在后台线程预计算布局，避免在主线程进行复杂的文本测量：

```swift
// 在后台线程
DispatchQueue.global(qos: .userInitiated).async {
    var message = messages[index]
    message.parse()
    message.calculateLayout(width: contentWidth)
    // 保存 layout 到 message
}

// 在主线程渲染
cell.configure(with: message, contentWidth: contentWidth)
```

### 2. 缓存 AST JSON

如果消息内容不变，可以缓存解析后的 AST JSON：

```swift
struct Message {
    let content: String
    var astJSON: String? // 缓存 AST JSON
    
    mutating func parse() {
        if astJSON == nil {
            let result = IMParseCore.parseMarkdown(content)
            astJSON = result.astJSON
        }
    }
}
```

### 3. 使用 renderWithFrame 而不是 render

`renderWithFrame` 使用 frame 布局，性能更好：

```swift
// 推荐
let view = renderer.renderWithFrame(ast: rootNode, context: context)

// 不推荐（除非需要 Auto Layout）
let view = renderer.render(ast: rootNode, context: context)
```

### 4. 批量处理

在加载大量消息时，批量解析和计算布局：

```swift
DispatchQueue.global(qos: .userInitiated).async {
    var processedMessages: [Message] = []
    
    for message in messages {
        var msg = message
        msg.parse()
        msg.calculateLayout(width: contentWidth)
        processedMessages.append(msg)
    }
    
    DispatchQueue.main.async {
        self.messages = processedMessages
        self.collectionView.reloadData()
    }
}
```

### 5. 图片加载优化

使用图片加载库（如 Kingfisher）的缓存功能，避免重复加载：

```swift
extension MessageCollectionViewCell: UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
        imageView.kf.setImage(
            with: url,
            options: [.cacheOriginalImage, .transition(.fade(0.2))]
        ) { result in
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

## 常见问题

### Q: 如何支持 Delta 格式？

A: 使用 `IMParseCore.parseDelta()` 代替 `parseMarkdown()`：

```swift
let result = IMParseCore.parseDelta(deltaContent)
```

### Q: 如何自定义样式？

A: 创建自定义 `UIKitTheme` 并传入 `UIKitRenderContext`：

```swift
var theme = UIKitTheme.default
theme.font = .systemFont(ofSize: 18)
let context = UIKitRenderContext(theme: theme, width: 300)
```

### Q: 如何处理图片加载失败？

A: 在 `UIKitImageLoaderDelegate` 的 `loadImage` 方法中处理错误：

```swift
func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
    // 加载图片
    // 如果失败，调用 completion(nil, error)
}
```

### Q: 如何支持深色模式？

A: 根据当前外观模式创建不同的主题：

```swift
let theme: UIKitTheme
if traitCollection.userInterfaceStyle == .dark {
    theme = createDarkTheme()
} else {
    theme = createLightTheme()
}
```

---

## 完整示例

参考项目中的 `UIKitMessageListViewController.swift` 查看完整的使用示例。

