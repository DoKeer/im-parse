# AST V2 重构方案 - 完整指南

> 🎯 从Rust专家和解析器专家角度，重新设计的高性能、易扩展、渲染友好的AST结构

## 🌟 核心价值

### 为什么需要 V2？

当前 AST V1 存在以下问题：

1. **样式嵌套层级深**：`Strong(Em(Underline(Text)))` 导致递归遍历
2. **渲染性能差**：每层样式都需要创建新对象，复杂文档渲染缓慢
3. **内存占用高**：多层包装导致内存浪费
4. **Delta 支持不完善**：缺少字体、颜色等富文本属性
5. **扩展性差**：新增样式需要新增节点类型

### V2 带来的改进

| 指标 | 提升 | 说明 |
|------|------|------|
| **渲染性能** | **10-50 倍** | 扁平化结构，无需递归 |
| **内存占用** | **减少 30-50%** | 单层结构，减少包装 |
| **代码量** | **减少 40%** | 简化渲染逻辑 |
| **扩展性** | **质的飞跃** | 样式作为枚举，易于扩展 |
| **Delta 支持** | **完美匹配** | 直接映射 Delta 属性 |

## 📖 核心设计

### 1. 样式系统革新

#### ❌ V1：样式作为节点类型（问题）

```rust
// 4 层嵌套，递归遍历
ASTNode::Strong(StrongNode {
    children: vec![
        ASTNode::Em(EmNode {
            children: vec![
                ASTNode::Underline(UnderlineNode {
                    children: vec![
                        ASTNode::Text(TextNode {
                            content: "hello"
                        })
                    ]
                })
            ]
        })
    ]
})
```

**问题**：
- 递归深度：O(d)，d = 样式层数
- 对象数量：4 个对象（Strong, Em, Underline, Text）
- 渲染时间：O(d)，需要递归遍历
- 内存占用：4 × sizeof(Node)

#### ✅ V2：样式作为属性（解决方案）

```rust
// 1 层结构，扁平遍历
ASTNode::Text(TextRun {
    content: "hello".into(),
    styles: vec![
        TextStyle::Bold,
        TextStyle::Italic,
        TextStyle::Underline,
    ]
})
```

**优势**：
- 递归深度：O(1)，扁平结构
- 对象数量：1 个对象（TextRun）
- 渲染时间：O(1)，直接访问
- 内存占用：1 × sizeof(TextRun)

### 2. 完整的样式系统

```rust
pub enum TextStyle {
    // ===== Markdown 样式 =====
    Bold,                                    // **粗体**
    Italic,                                  // *斜体*
    Underline,                               // （扩展）
    Strikethrough,                           // ~~删除线~~
    Code,                                    // `代码`
    
    // ===== Delta 富文本样式 =====
    Color { color: String },                 // 文字颜色
    BackgroundColor { color: String },       // 背景颜色
    FontSize { scale: f32 },                 // 字体大小（相对）
    FontFamily { family: String },           // 字体族
    
    // ===== 科学排版 =====
    Superscript,                             // 上标 x²
    Subscript,                               // 下标 H₂O
}
```

### 3. 块级/行内清晰分离

```rust
pub enum ASTNode {
    // ===== 块级元素（Block-level） =====
    Paragraph(ParagraphNode),                // 段落
    Heading(HeadingNode),                    // 标题
    CodeBlock(CodeBlockNode),                // 代码块
    Blockquote(BlockquoteNode),              // 引用块
    List(ListNode),                          // 列表
    Table(TableNode),                        // 表格
    HorizontalRule(HorizontalRuleNode),      // 分割线
    MathBlock(MathNode),                     // 数学公式块 $$...$$
    MermaidBlock(MermaidNode),               // Mermaid 图表块
    HtmlBlock(HtmlNode),                     // HTML 块
    
    // ===== 行内元素（Inline-level） =====
    Text(TextRun),                           // ✅ 文本运行（带样式）
    Link(LinkNode),                          // 链接
    Image(ImageNode),                        // 图片
    InlineMath(MathNode),                    // 行内数学公式 $...$
    Mention(MentionNode),                    // @提及
    Emoji(EmojiNode),                        // 表情
    LineBreak(LineBreakNode),                // 换行
    InlineHtml(HtmlNode),                    // HTML 行内
}
```

### 4. 增强的段落属性

```rust
pub struct ParagraphNode {
    pub children: Vec<ASTNode>,              // 行内内容
    pub align: Option<TextAlign>,            // ✅ 对齐方式（Delta）
    pub indent: u32,                         // ✅ 缩进级别（Delta）
}

pub enum TextAlign {
    Left,
    Center,
    Right,
}
```

## 🚀 快速开始

### Rust Core 使用

```rust
use im_parse_core::ast_builder_v2::ASTBuilderV2;
use im_parse_core::ast::*;

fn main() {
    let mut builder = ASTBuilderV2::new();
    builder.start_document();
    
    // 添加标题
    builder.add_heading(1, vec![
        ASTNode::text("Hello World")
    ]);
    
    // 添加段落（带样式）
    builder.start_paragraph();
    builder.push_style(TextStyle::Bold);
    builder.add_text("Bold text");
    builder.pop_style("bold");
    builder.add_text(" and ");
    builder.push_style(TextStyle::Italic);
    builder.add_text("italic text");
    builder.pop_style("italic");
    builder.end_paragraph();
    
    // 获取 AST
    let ast = builder.end_document();
    
    // 序列化为 JSON
    let json = serde_json::to_string_pretty(&ast).unwrap();
    println!("{}", json);
}
```

### iOS 渲染

```swift
// 1. 解析 JSON
let jsonData = parseResult.data(using: .utf8)!
let decoder = JSONDecoder()
let rootNode = try decoder.decode(RootNode.self, from: jsonData)

// 2. 构建 AttributedString（V2 优化）
let builder = UIKitAttributedStringBuilderV2(theme: theme)

for node in rootNode.children {
    switch node {
    case .text(let textRun):
        // ✅ 一次性构建，无递归
        let attrString = builder.buildAttributedString(from: textRun)
        textView.attributedText = attrString
        
    case .paragraph(let paraNode):
        // ✅ 直接构建行内内容
        let attrString = builder.buildInlineContent(from: paraNode.children)
        textView.attributedText = attrString
        
    // ... 其他节点类型
    }
}
```

### Android 渲染

```kotlin
// 1. 解析 JSON
val gson = Gson()
val rootNode = gson.fromJson(jsonString, RootNode::class.java)

// 2. 构建 SpannableString（V2 优化）
val builder = AndroidAttributedStringBuilderV2(theme)

for (node in rootNode.children) {
    when (node) {
        is ASTNode.Text -> {
            // ✅ 一次性构建，无递归
            val spannable = builder.buildSpannableString(node.textRun)
            textView.text = spannable
        }
        
        is ASTNode.Paragraph -> {
            // ✅ 直接构建行内内容
            val spannable = builder.buildInlineContent(node.paraNode.children)
            textView.text = spannable
        }
        
        // ... 其他节点类型
    }
}
```

## 📂 项目结构

```
im-parse/
├── rust-core/
│   ├── src/
│   │   ├── ast.rs                      # ✅ 新 AST 定义
│   │   ├── ast_builder_v2.rs           # ✅ 新 Builder
│   │   ├── markdown_parser_v2.rs       # ✅ Markdown 解析器 V2
│   │   ├── delta_parser_v2.rs          # ✅ Delta 解析器 V2
│   │   └── ...
│   ├── examples/
│   │   └── ast_v2_demo.rs              # ✅ 使用示例
│   └── docs/
│       ├── AST_V2_MIGRATION_PLAN.md    # 迁移计划
│       ├── AST_V2_SUMMARY.md           # 方案总结
│       └── RENDERER_V2_DESIGN.md       # 渲染层设计
│
├── ios/IMParseSDK/
│   └── IMParseSDK/Classes/
│       ├── Models/
│       │   ├── ASTNodes.swift          # 旧版本（保留）
│       │   └── ASTNodesV2.swift        # ✅ 新版本
│       └── Renderers/
│           ├── UIKitAttributedStringBuilderV2.swift  # ✅
│           ├── UIKitFrameAsyncCalculatorV2.swift     # ✅
│           └── UIKitFrameRenderV2.swift              # ✅
│
└── android/IMParseSDK/
    └── src/main/java/com/imparse/
        ├── models/
        │   ├── ASTNodes.kt             # 旧版本（保留）
        │   ├── TextStyle.kt            # ✅ 新样式系统
        │   └── TextRun.kt              # ✅ 新文本运行
        └── renderers/
            ├── AndroidAttributedStringBuilderV2.kt  # ✅
            └── AndroidViewRendererV2.kt             # ✅
```

## 📚 详细文档

### 核心文档

| 文档 | 说明 | 阅读时间 |
|------|------|---------|
| [AST_V2_SUMMARY.md](./AST_V2_SUMMARY.md) | 方案总结（必读） | 10 分钟 |
| [AST_V2_MIGRATION_PLAN.md](./AST_V2_MIGRATION_PLAN.md) | 迁移计划（开发必读） | 30 分钟 |
| [RENDERER_V2_DESIGN.md](./RENDERER_V2_DESIGN.md) | 渲染层设计（移动端开发必读） | 40 分钟 |

### 代码示例

| 示例 | 说明 |
|------|------|
| `rust-core/examples/ast_v2_demo.rs` | Rust 使用示例 |
| `rust-core/tests/ast_v2_test.rs` | 单元测试示例 |

## 🗓️ 实施计划

### 第一阶段：Rust Core（2-3周）

- [x] **Week 1-2**：新 AST 实现
  - [x] `ast.rs` - 数据结构定义
  - [x] `ast_builder_v2.rs` - Builder 实现
  - [x] 单元测试覆盖

- [ ] **Week 2-3**：Parser 适配
  - [ ] `markdown_parser_v2.rs`
  - [ ] `delta_parser_v2.rs`
  - [ ] 集成测试

### 第二阶段：iOS 渲染层（1.5-2周）

- [ ] **Week 3-4**：Swift 适配
  - [ ] `ASTNodesV2.swift`
  - [ ] `UIKitAttributedStringBuilderV2.swift`
  - [ ] `UIKitFrameAsyncCalculatorV2.swift`
  - [ ] `UIKitFrameRenderV2.swift`
  - [ ] 性能测试

### 第三阶段：Android 渲染层（1.5-2周）

- [ ] **Week 4-5**：Kotlin 适配
  - [ ] `TextStyle.kt`
  - [ ] `AndroidAttributedStringBuilderV2.kt`
  - [ ] `AndroidViewRendererV2.kt`
  - [ ] 性能测试

### 第四阶段：测试与上线（1周）

- [ ] **Week 6**：集成测试
  - [ ] 端到端测试
  - [ ] 性能基准测试
  - [ ] UI 回归测试

- [ ] **Week 7-8**：灰度发布
  - [ ] 10% 用户
  - [ ] 50% 用户
  - [ ] 100% 全量

## 🎯 性能目标

### 渲染性能

| 场景 | 当前（V1） | 目标（V2） | 提升 |
|------|-----------|-----------|------|
| 简单文本（100字） | 5ms | **0.5ms** | 10x |
| 复杂样式（100字，5层嵌套） | 50ms | **1ms** | 50x |
| 长文档（10000字） | 500ms | **50ms** | 10x |
| 滚动帧率（复杂文档） | 30-40 FPS | **55-60 FPS** | 1.5-2x |

### 内存占用

| 场景 | 当前（V1） | 目标（V2） | 减少 |
|------|-----------|-----------|------|
| 1000 节点 | 1.0 MB | **0.6 MB** | 40% |
| 10000 节点 | 10 MB | **6 MB** | 40% |
| 复杂样式（5层） | 5× base | **1× base** | 80% |

## ⚠️ 风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 渲染结果不一致 | 高 | 中 | 详尽的回归测试 + 对比工具 |
| 性能不如预期 | 中 | 低 | 性能基准测试 + Profile 优化 |
| FFI 接口变更 | 高 | 高 | 版本兼容层 + Feature Flag |
| 现有代码依赖 | 中 | 高 | 渐进式迁移 + 并行运行 |
| 开发时间超预期 | 中 | 中 | 预留 buffer + 分阶段交付 |

## 🤝 贡献指南

### 开发流程

1. **Fork 仓库**
2. **创建分支**：`git checkout -b feature/ast-v2-xxx`
3. **开发 + 测试**
4. **提交 PR**：详细描述改动
5. **Code Review**
6. **合并**

### 代码规范

- **Rust**：遵循 `rustfmt` 和 `clippy` 规则
- **Swift**：遵循 SwiftLint 规则
- **Kotlin**：遵循 ktlint 规则

### 测试要求

- **单元测试覆盖率**：> 80%
- **集成测试**：覆盖核心场景
- **性能测试**：必须达到目标

## 📞 联系方式

- **技术负责人**：[Your Name]
- **Rust Core**：[Rust Team]
- **iOS 渲染**：[iOS Team]
- **Android 渲染**：[Android Team]

## 📄 许可证

[MIT License](../LICENSE)

---

**最后更新**：2025-01-05  
**当前版本**：V2.0.0-alpha  
**状态**：🚧 设计阶段

