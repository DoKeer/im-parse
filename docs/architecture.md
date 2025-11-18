# 富文本解析与渲染系统 - 技术架构设计文档

## 一、架构概述

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        输入层                                 │
│  ┌──────────────┐              ┌──────────────┐            │
│  │   Markdown   │              │ Quill Delta  │            │
│  └──────┬───────┘              └──────┬───────┘            │
└─────────┼──────────────────────────────┼─────────────────────┘
          │                              │
          ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   统一解析层 (Rust/C++/WASM)                 │
│  ┌──────────────────┐      ┌──────────────────┐           │
│  │ Markdown Parser  │      │  Delta Parser    │           │
│  │ (pulldown-cmark) │      │  (Custom)        │           │
│  └────────┬─────────┘      └────────┬─────────┘           │
│           │                          │                      │
│           └──────────┬───────────────┘                      │
│                      ▼                                      │
│              ┌──────────────┐                              │
│              │  AST Builder  │                              │
│              └──────┬───────┘                              │
└─────────────────────┼──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   统一 HTML AST (JSON)                       │
│  ┌────────────────────────────────────────────────────┐    │
│  │  RootNode                                          │    │
│  │  ├─ ParagraphNode                                  │    │
│  │  ├─ HeadingNode                                    │    │
│  │  ├─ CodeBlockNode                                  │    │
│  │  ├─ TableNode                                      │    │
│  │  ├─ ListNode                                       │    │
│  │  ├─ MathNode                                       │    │
│  │  ├─ MermaidNode                                    │    │
│  │  ├─ ImageNode                                      │    │
│  │  └─ ...                                            │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ iOS SwiftUI  │ │Android Compose│ │Web/Electron │
│   Renderer   │ │   Renderer    │ │   Renderer   │
└──────────────┘ └──────────────┘ └──────────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   性能优化层                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ 高度预计算    │  │   缓存系统    │  │   懒加载     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

1. **统一抽象**：Markdown 和 Delta 统一解析为 HTML AST
2. **平台无关**：AST 以 JSON 格式，便于跨平台传输
3. **高性能**：解析层使用 Rust/C++，渲染层支持缓存和懒加载
4. **可扩展**：支持自定义节点和渲染器
5. **类型安全**：各平台使用强类型语言，保证类型安全

## 二、解析层设计

### 2.1 Markdown 解析器

#### 2.1.1 技术选型
- **核心库**：`pulldown-cmark` (Rust)
- **扩展支持**：自定义扩展解析器
- **输出格式**：HTML AST

#### 2.1.2 解析流程

```
Markdown 文本
    │
    ▼
pulldown-cmark 解析
    │
    ▼
事件流 (Event Stream)
    │
    ▼
AST Builder 构建
    │
    ▼
统一 HTML AST
```

#### 2.1.3 扩展语法支持

| 语法 | 实现方式 |
|------|---------|
| 表格 | 扩展 pulldown-cmark 表格解析 |
| 任务列表 | 扩展列表解析，识别 `[ ]` 和 `[x]` |
| 代码块高亮 | 解析语言标识，传递给渲染层 |
| 高亮文本 | 自定义扩展 `==text==` |
| KaTeX | 识别 `$...$` 和 `$$...$$` |
| Mermaid | 识别 ````mermaid` 代码块 |

### 2.2 Delta 解析器

#### 2.2.1 Delta 格式规范

Delta 是 Quill 的文档格式，由操作序列组成：

```json
{
  "ops": [
    {"insert": "Hello "},
    {"insert": "World", "attributes": {"bold": true}},
    {"insert": "\n"},
    {"insert": "Item", "attributes": {"list": "bullet"}},
    {"insert": "\n"}
  ]
}
```

#### 2.2.2 解析流程

```
Delta JSON
    │
    ▼
操作序列解析
    │
    ▼
块级元素识别
    │
    ▼
内联样式应用
    │
    ▼
AST Builder 构建
    │
    ▼
统一 HTML AST
```

#### 2.2.3 Delta → AST 映射规则

| Delta 操作/属性 | AST 节点 |
|----------------|---------|
| `insert: "text"` | `TextNode` |
| `attributes.bold` | `StrongNode` |
| `attributes.italic` | `EmNode` |
| `attributes.underline` | `UnderlineNode` |
| `attributes.strike` | `StrikeNode` |
| `attributes.link` | `LinkNode` |
| `attributes.code` | `CodeNode` |
| `attributes.code-block` | `CodeBlockNode` |
| `attributes.list: "bullet"` | `ListNode(type=bullet)` |
| `attributes.list: "ordered"` | `ListNode(type=ordered)` |
| `insert: {image: "url"}` | `ImageNode` |
| `insert: {formula: "latex"}` | `MathNode` |

### 2.3 AST Builder

#### 2.3.1 设计模式
使用 Builder 模式构建 AST，支持：
- 节点栈管理（处理嵌套结构）
- 样式合并（处理多个内联样式）
- 块级元素识别（段落、列表、代码块等）

#### 2.3.2 核心接口

```rust
trait ASTBuilder {
    fn start_document(&mut self);
    fn end_document(&mut self) -> RootNode;
    
    fn start_paragraph(&mut self);
    fn end_paragraph(&mut self);
    
    fn add_text(&mut self, text: String);
    fn add_strong(&mut self, children: Vec<ASTNode>);
    fn add_em(&mut self, children: Vec<ASTNode>);
    // ... 其他节点类型
}
```

## 三、AST 数据结构设计

### 3.1 节点类型定义

#### 3.1.1 基础节点

```rust
enum ASTNode {
    Root(RootNode),
    Paragraph(ParagraphNode),
    Heading(HeadingNode),
    Text(TextNode),
    Strong(StrongNode),
    Em(EmNode),
    Underline(UnderlineNode),
    Strike(StrikeNode),
    Code(CodeNode),
    CodeBlock(CodeBlockNode),
    Link(LinkNode),
    Image(ImageNode),
    List(ListNode),
    ListItem(ListItemNode),
    Table(TableNode),
    TableRow(TableRow),
    TableCell(TableCell),
    Math(MathNode),
    Mermaid(MermaidNode),
    Card(CardNode),
    Mention(MentionNode),
    HorizontalRule(HorizontalRuleNode),
    Blockquote(BlockquoteNode),
}
```

#### 3.1.2 节点属性

```rust
struct RootNode {
    children: Vec<ASTNode>,
}

struct ParagraphNode {
    children: Vec<ASTNode>,
}

struct HeadingNode {
    level: u8,  // 1-6
    children: Vec<ASTNode>,
}

struct TextNode {
    content: String,
}

struct StrongNode {
    children: Vec<ASTNode>,
}

struct CodeBlockNode {
    language: Option<String>,
    content: String,
}

struct ImageNode {
    url: String,
    width: Option<f32>,
    height: Option<f32>,
    alt: Option<String>,
}

struct ListNode {
    list_type: ListType,  // bullet | ordered
    items: Vec<ListItemNode>,
}

struct ListItemNode {
    children: Vec<ASTNode>,
    checked: Option<bool>,  // None | Some(true) | Some(false)
}

struct TableNode {
    rows: Vec<TableRow>,
}

struct TableRow {
    cells: Vec<TableCell>,
}

struct TableCell {
    children: Vec<ASTNode>,
    align: Option<TextAlign>,  // left | center | right
}

struct MathNode {
    content: String,
    display: bool,  // true for $$, false for $
}

struct MermaidNode {
    content: String,
}

struct CardNode {
    subtype: String,
    content: String,
    metadata: HashMap<String, String>,
}

struct MentionNode {
    id: String,
    name: String,
}
```

### 3.2 序列化格式

#### 3.2.1 JSON 格式

AST 以 JSON 格式序列化，便于跨平台传输：

```json
{
  "type": "root",
  "children": [
    {
      "type": "paragraph",
      "children": [
        {
          "type": "text",
          "content": "Hello "
        },
        {
          "type": "strong",
          "children": [
            {
              "type": "text",
              "content": "World"
            }
          ]
        }
      ]
    }
  ]
}
```

#### 3.2.2 二进制格式（可选）

对于性能要求高的场景，支持 MessagePack 序列化：

- 体积更小（约减少 30-50%）
- 解析更快（约快 2-3 倍）
- 但可读性较差

## 四、渲染层设计

### 4.1 iOS SwiftUI 渲染器

#### 4.1.1 架构设计

```
ASTNode
    │
    ▼
NodeRenderer Protocol
    │
    ├─ ParagraphRenderer
    ├─ HeadingRenderer
    ├─ CodeBlockRenderer
    ├─ TableRenderer
    ├─ ListRenderer
    ├─ MathRenderer
    ├─ MermaidRenderer
    └─ ...
```

#### 4.1.2 核心实现

```swift
protocol NodeRenderer {
    associatedtype Content: View
    func render(_ node: ASTNode, context: RenderContext) -> Content
}

struct RenderContext {
    var theme: Theme
    var width: CGFloat
    var onLinkTap: ((URL) -> Void)?
    var onImageTap: ((ImageNode) -> Void)?
    var onMentionTap: ((MentionNode) -> Void)?
}
```

#### 4.1.3 特殊节点渲染

- **代码块**：使用 `CodeView` 组件，集成语法高亮库
- **数学公式**：使用 `MathView` 组件，集成 KaTeX 或 MathJax
- **Mermaid**：使用 `WKWebView` 或 SVG 渲染
- **图片**：使用 `AsyncImage`，支持缓存和占位符

### 4.2 Android Compose 渲染器

#### 4.2.1 架构设计

```
ASTNode
    │
    ▼
Composable Function
    │
    ├─ RenderParagraph
    ├─ RenderHeading
    ├─ RenderCodeBlock
    ├─ RenderTable
    ├─ RenderList
    ├─ RenderMath
    ├─ RenderMermaid
    └─ ...
```

#### 4.2.2 核心实现

```kotlin
@Composable
fun RenderAST(
    node: ASTNode,
    modifier: Modifier = Modifier,
    context: RenderContext = remember { RenderContext() }
) {
    when (node) {
        is ParagraphNode -> RenderParagraph(node, modifier, context)
        is HeadingNode -> RenderHeading(node, modifier, context)
        is CodeBlockNode -> RenderCodeBlock(node, modifier, context)
        // ...
    }
}
```

#### 4.2.3 特殊节点渲染

- **代码块**：使用 `CodeBlock` 组件，集成语法高亮库
- **数学公式**：使用 `MathView` 组件，集成 KaTeX
- **Mermaid**：使用 `AndroidView` 包装 WebView 或 SVG
- **图片**：使用 `AsyncImage`，支持 Coil 或 Glide

### 4.3 Web/Electron React 渲染器

#### 4.3.1 架构设计

```
ASTNode
    │
    ▼
React Component
    │
    ├─ <Paragraph>
    ├─ <Heading>
    ├─ <CodeBlock>
    ├─ <Table>
    ├─ <List>
    ├─ <Math>
    ├─ <Mermaid>
    └─ ...
```

#### 4.3.2 核心实现

```typescript
interface RenderProps {
  node: ASTNode;
  context?: RenderContext;
}

function RenderAST({ node, context }: RenderProps) {
  switch (node.type) {
    case 'paragraph':
      return <Paragraph node={node} context={context} />;
    case 'heading':
      return <Heading node={node} context={context} />;
    case 'codeBlock':
      return <CodeBlock node={node} context={context} />;
    // ...
  }
}
```

#### 4.3.2 特殊节点渲染

- **代码块**：使用 `react-syntax-highlighter` 或 `Prism.js`
- **数学公式**：使用 `react-katex` 或 `react-mathjax`
- **Mermaid**：使用 `react-mermaid2` 或直接使用 `mermaid.js`
- **图片**：使用 `<img>` 标签，支持懒加载

## 五、性能优化设计

### 5.1 高度预计算

#### 5.1.1 计算策略

每个 AST 节点实现 `estimatedHeight` 方法：

```rust
trait HeightCalculator {
    fn estimated_height(&self, width: f32, context: &RenderContext) -> f32;
}
```

#### 5.1.2 不同类型节点的高度计算

| 节点类型 | 计算方法 |
|---------|---------|
| TextNode | 文本行数 × 行高，考虑换行 |
| ImageNode | 根据宽高比和最大宽度计算 |
| CodeBlockNode | 行数 × 行高 + 内边距 |
| TableNode | 行数 × 行高 + 表头高度 |
| ListNode | 列表项数量 × 列表项高度 |
| MathNode | 根据公式复杂度估算 |
| MermaidNode | 根据图表类型和内容估算 |

#### 5.1.3 缓存策略

```rust
struct HeightCache {
    cache: HashMap<String, f32>,  // node_id -> height
    ttl: Duration,
}
```

### 5.2 缓存系统

#### 5.2.1 多级缓存

```
L1: 内存缓存 (AST, 渲染结果)
    │
    ▼
L2: 磁盘缓存 (AST JSON, 图片)
    │
    ▼
L3: 网络缓存 (图片 CDN)
```

#### 5.2.2 缓存键设计

- **AST 缓存键**：`md5(input_content)`
- **渲染结果缓存键**：`md5(ast_json + theme + width)`
- **高度缓存键**：`md5(ast_json + width)`
- **图片缓存键**：`md5(image_url)`

#### 5.2.3 缓存失效策略

- **时间失效**：TTL 机制，默认 24 小时
- **内容失效**：输入内容变化时失效
- **主题失效**：主题切换时失效
- **手动失效**：支持手动清除缓存

### 5.3 懒加载

#### 5.3.1 虚拟滚动

- 只渲染可见区域的内容
- 使用占位符代替不可见内容
- 滚动时动态加载和卸载

#### 5.3.2 图片懒加载

- 图片进入可视区域才加载
- 使用占位符和加载动画
- 支持渐进式加载（模糊 → 清晰）

#### 5.3.3 复杂节点延迟渲染

- Mermaid 图表：首次可见时才渲染
- 数学公式：可以延迟渲染，使用占位符
- 代码块：可以延迟语法高亮

## 六、扩展能力设计

### 6.1 自定义节点

#### 6.1.1 节点注册机制

```rust
trait CustomNodeRegistry {
    fn register_node_type(&mut self, node_type: String, parser: Box<dyn NodeParser>);
    fn register_renderer(&mut self, node_type: String, renderer: Box<dyn NodeRenderer>);
}
```

#### 6.1.2 自定义节点示例

```rust
struct AICardNode {
    message_id: String,
    content: String,
    metadata: HashMap<String, String>,
}
```

### 6.2 主题系统

#### 6.2.1 主题定义

```rust
struct Theme {
    colors: ColorScheme,
    typography: Typography,
    spacing: Spacing,
    code_theme: CodeTheme,
}
```

#### 6.2.2 主题应用

- 通过 `RenderContext` 传递主题
- 各平台实现主题到样式的映射
- 支持动态切换主题

### 6.3 增量更新

#### 6.3.1 差异算法

使用树形结构的差异算法（类似 React 的 diff）：

```rust
fn diff_ast(old: &ASTNode, new: &ASTNode) -> Vec<DiffOperation> {
    // 比较节点类型、属性、子节点
    // 返回差异操作列表
}
```

#### 6.3.2 更新策略

- **节点替换**：节点类型变化时替换整个节点
- **属性更新**：只更新变化的属性
- **子节点更新**：使用 key 标识，只更新变化的子节点

## 七、安全性设计

### 7.1 输入验证

- **XSS 防护**：过滤危险标签和属性
- **URL 验证**：验证链接 URL 的安全性
- **图片验证**：验证图片来源和格式
- **代码执行隔离**：代码块不执行，仅显示

### 7.2 资源加载

- **CORS 检查**：检查跨域资源加载
- **内容安全策略**：限制资源来源
- **沙箱隔离**：WebView 使用沙箱模式

## 八、部署和集成

### 8.1 构建产物

#### 8.1.1 Rust 库

- **静态库**：`.a` 文件（iOS/Android）
- **动态库**：`.so` 文件（Android）
- **WASM**：`.wasm` 文件（Web）

#### 8.1.2 平台绑定

- **iOS**：Swift Package 或 CocoaPods
- **Android**：AAR 或 Maven 依赖
- **Web**：NPM 包

### 8.2 集成方式

#### 8.2.1 iOS 集成

```swift
import IMParse

let parser = MarkdownParser()
let ast = parser.parse(markdown: "# Hello")
let renderer = SwiftUIRenderer()
let view = renderer.render(ast: ast)
```

#### 8.2.2 Android 集成

```kotlin
import com.imparse.*

val parser = MarkdownParser()
val ast = parser.parse(markdown = "# Hello")
val renderer = ComposeRenderer()
setContent {
    renderer.Render(ast = ast)
}
```

#### 8.2.3 Web 集成

```typescript
import { parseMarkdown, RenderAST } from '@imparse/core';

const ast = parseMarkdown('# Hello');
ReactDOM.render(<RenderAST node={ast} />, container);
```

## 九、测试策略

### 9.1 单元测试

- 解析器测试：各种 Markdown/Delta 输入
- AST 构建测试：节点构建正确性
- 渲染器测试：各节点类型渲染正确性

### 9.2 集成测试

- 端到端测试：输入 → 解析 → 渲染 → 显示
- 跨平台一致性测试：相同输入在不同平台渲染一致
- 性能测试：解析和渲染性能基准测试

### 9.3 兼容性测试

- 不同平台版本测试
- 不同屏幕尺寸测试
- 不同字体大小测试

## 十、监控和调试

### 10.1 性能监控

- 解析时间统计
- 渲染时间统计
- 内存使用统计
- 缓存命中率统计

### 10.2 错误处理

- 解析错误：返回错误信息，不崩溃
- 渲染错误：降级渲染，显示错误占位符
- 资源加载错误：显示错误提示

### 10.3 调试工具

- AST 可视化工具
- 渲染树查看器
- 性能分析工具

