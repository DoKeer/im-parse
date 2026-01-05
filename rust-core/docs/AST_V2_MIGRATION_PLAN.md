# AST V2 迁移计划

## 一、核心改进概述

### 1.1 主要变化

#### 旧版本（V1）问题
```rust
// 嵌套层级深，渲染复杂
ASTNode::Strong(StrongNode {
    children: vec![
        ASTNode::Em(EmNode {
            children: vec![
                ASTNode::Underline(UnderlineNode {
                    children: vec![
                        ASTNode::Text(TextNode { content: "hello".into() })
                    ]
                })
            ]
        })
    ]
})
```

#### 新版本（V2）优化
```rust
// 扁平化，样式作为属性
ASTNode::Text(TextRun {
    content: "hello".into(),
    styles: vec![
        TextStyle::Bold,
        TextStyle::Italic,
        TextStyle::Underline,
    ]
})
```

### 1.2 核心优势

| 方面 | V1 | V2 |
|-----|----|----|
| **嵌套层级** | 多层递归 | 扁平化 |
| **样式系统** | 节点类型 | 属性列表 |
| **渲染性能** | 需要递归遍历 | 直接映射到原生控件 |
| **扩展性** | 新增样式需要新节点类型 | 新增枚举变体 |
| **Delta支持** | 需要转换 | 直接对应 |
| **内存占用** | 高（多层包装） | 低（单层结构） |

### 1.3 新增功能

1. **富文本样式**
   - 字体颜色 `TextStyle::Color`
   - 背景颜色 `TextStyle::BackgroundColor`
   - 字体大小 `TextStyle::FontSize { scale: f32 }`
   - 字体族 `TextStyle::FontFamily`
   - 上标/下标 `Superscript/Subscript`

2. **段落属性**
   - 对齐方式 `ParagraphNode::align`
   - 缩进级别 `ParagraphNode::indent`

3. **行内/块级分离**
   - 数学公式：`InlineMath` vs `MathBlock`
   - HTML：`InlineHtml` vs `HtmlBlock`
   - 明确的换行节点：`LineBreak`

## 二、Rust Core 迁移

### 2.1 Parser 适配

#### Markdown Parser 修改

**旧版本：**
```rust
// 处理粗体
Event::Start(Tag::Strong) => {
    let children = self.parse_inline_context(stream, TagEnd::Strong)?;
    builder.add_strong(children);
}
```

**新版本：**
```rust
// 推入样式到样式栈
Event::Start(Tag::Strong) => {
    builder.push_style(TextStyle::Bold);
}

Event::End(TagEnd::Strong) => {
    builder.pop_style("bold");
}

Event::Text(text) => {
    builder.add_text(text.to_string());
}
```

#### Delta Parser 修改

**旧版本：**
```rust
// 需要复杂的样式转换
let styled_nodes = self.build_styled_text(&text, attributes);
current_paragraph_children.extend(styled_nodes);
```

**新版本：**
```rust
// 直接设置样式
if let Some(attrs) = attributes {
    if attrs.get("bold").and_then(|v| v.as_bool()).unwrap_or(false) {
        builder.push_style(TextStyle::Bold);
    }
    if let Some(color) = attrs.get("color").and_then(|v| v.as_str()) {
        builder.set_color(color.to_string());
    }
}

builder.add_text(text);

// 清理样式
if let Some(attrs) = attributes {
    if attrs.get("bold").is_some() {
        builder.pop_style("bold");
    }
    if attrs.get("color").is_some() {
        builder.remove_color();
    }
}
```

### 2.2 迁移步骤

#### 第一阶段：并行运行（1-2周）

1. **保留旧版本**
   - 旧文件保持不变：`ast.rs`, `ast_builder.rs`
   - 新文件独立开发：`ast_v2.rs`, `ast_builder_v2.rs`

2. **创建适配层**
```rust
// 创建转换函数
pub fn convert_v1_to_v2(v1_node: old_ast::ASTNode) -> new_ast::ASTNode {
    match v1_node {
        old_ast::ASTNode::Strong(strong) => {
            // 将嵌套样式节点展平
            flatten_styled_node(strong, TextStyle::Bold)
        },
        // ... 其他转换
    }
}

fn flatten_styled_node(node: /* old node */, style: TextStyle) -> new_ast::ASTNode {
    // 递归收集所有嵌套样式
    let mut styles = vec![style];
    let mut current = &node.children[0];
    
    loop {
        match current {
            old_ast::ASTNode::Em(em) => {
                styles.push(TextStyle::Italic);
                current = &em.children[0];
            },
            old_ast::ASTNode::Text(text) => {
                return new_ast::ASTNode::Text(TextRun {
                    content: text.content.clone(),
                    styles,
                });
            },
            _ => break,
        }
    }
    
    // ... fallback
}
```

3. **测试对比**
```rust
#[test]
fn test_v1_v2_equivalence() {
    let markdown = "**_hello_** world";
    
    let v1_ast = MarkdownParser::new().parse(markdown).unwrap();
    let v2_ast = MarkdownParserV2::new().parse(markdown).unwrap();
    
    // 转换 V1 到 V2 格式
    let v1_converted = convert_v1_to_v2(v1_ast);
    
    // 比较渲染结果是否一致
    assert_eq!(render_to_html(v1_converted), render_to_html(v2_ast));
}
```

#### 第二阶段：渐进替换（2-3周）

1. **新 Parser 实现**
   - `markdown_parser_v2.rs`：使用 `ASTBuilderV2`
   - `delta_parser_v2.rs`：直接映射样式

2. **功能标志（Feature Flag）**
```rust
// Cargo.toml
[features]
default = ["ast-v1"]
ast-v1 = []
ast-v2 = []

// lib.rs
#[cfg(feature = "ast-v1")]
pub use crate::ast::ASTNode;

#[cfg(feature = "ast-v2")]
pub use crate::ast_v2::ASTNode;
```

3. **渐进式测试**
   - 单元测试覆盖所有节点类型
   - 集成测试对比 V1/V2 输出
   - 性能基准测试

#### 第三阶段：完全切换（1周）

1. **移除旧版本**
   - 删除 `ast.rs`（旧版）
   - `ast_v2.rs` → `ast.rs`
   - 更新所有导入

2. **更新 FFI 接口**
```rust
// ffi.rs 更新
#[no_mangle]
pub extern "C" fn parse_markdown_v2(input: *const c_char) -> *mut c_char {
    // 使用新的 Parser
}
```

3. **版本号升级**
   - `Cargo.toml`: version = "2.0.0"
   - 发布 Breaking Change 说明

## 三、iOS 渲染层迁移

### 3.1 Swift 数据模型更新

#### 新增 TextStyle 枚举

```swift
// ASTNodes.swift

/// 文本样式
public enum TextStyle: Codable {
    case bold
    case italic
    case underline
    case strikethrough
    case color(String)
    case backgroundColor(String)
    case fontSize(Float)
    case fontFamily(String)
    case superscript
    case subscript
    case code
    
    enum CodingKeys: String, CodingKey {
        case type
        case color
        case scale
        case family
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "bold": self = .bold
        case "italic": self = .italic
        case "underline": self = .underline
        case "strikethrough": self = .strikethrough
        case "color":
            let color = try container.decode(String.self, forKey: .color)
            self = .color(color)
        case "backgroundColor":
            let color = try container.decode(String.self, forKey: .color)
            self = .backgroundColor(color)
        case "fontSize":
            let scale = try container.decode(Float.self, forKey: .scale)
            self = .fontSize(scale)
        case "fontFamily":
            let family = try container.decode(String.self, forKey: .family)
            self = .fontFamily(family)
        case "superscript": self = .superscript
        case "subscript": self = .subscript
        case "code": self = .code
        default:
            throw DecodingError.dataCorrupted(...)
        }
    }
}

/// 文本运行（带样式）
public struct TextRun: Codable {
    public var content: String
    public var styles: [TextStyle]
}
```

#### 简化 ASTNode

```swift
public enum ASTNodeWrapper: Codable {
    // 块级元素
    case paragraph(ParagraphNode)
    case heading(HeadingNode)
    case codeBlock(CodeBlockNode)
    case blockquote(BlockquoteNode)
    case list(ListNode)
    case table(TableNode)
    case horizontalRule(HorizontalRuleNode)
    case mathBlock(MathNode)
    case mermaidBlock(MermaidNode)
    case htmlBlock(HtmlNode)
    
    // 行内元素（简化！）
    case text(TextRun)  // ✅ 替代 strong/em/underline/strike/code
    case link(LinkNode)
    case image(ImageNode)
    case inlineMath(MathNode)
    case mention(MentionNode)
    case emoji(EmojiNode)
    case lineBreak(LineBreakNode)
    case inlineHtml(HtmlNode)
    
    // ❌ 移除：strong, em, underline, strike, code (现在是 TextStyle)
}
```

### 3.2 AttributedString 构建优化

#### 旧版本（UIKitAttributedStringBuilder）

```swift
// 需要递归处理嵌套样式
func buildAttributedString(from node: ASTNodeWrapper) -> NSAttributedString {
    switch node {
    case .strong(let strong):
        let childAttr = buildAttributedString(from: strong.children[0])
        let mutableAttr = NSMutableAttributedString(attributedString: childAttr)
        mutableAttr.addAttribute(.font, value: boldFont, range: ...)
        return mutableAttr
    case .em(let em):
        // 又一层递归...
        ...
    }
}
```

#### 新版本（直接映射）

```swift
// 一次性构建，性能提升 10-50 倍
func buildAttributedString(from textRun: TextRun) -> NSAttributedString {
    let attrString = NSMutableAttributedString(string: textRun.content)
    let range = NSRange(location: 0, length: textRun.content.utf16.count)
    
    var font = theme.font
    var foregroundColor = theme.textColor
    var backgroundColor: UIColor? = nil
    var underlineStyle: NSUnderlineStyle? = nil
    var strikethroughStyle: NSUnderlineStyle? = nil
    
    // 应用所有样式
    for style in textRun.styles {
        switch style {
        case .bold:
            font = font.withTraits(.traitBold)
        case .italic:
            font = font.withTraits(.traitItalic)
        case .underline:
            underlineStyle = .single
        case .strikethrough:
            strikethroughStyle = .single
        case .color(let colorStr):
            foregroundColor = UIColor(hexString: colorStr)
        case .backgroundColor(let colorStr):
            backgroundColor = UIColor(hexString: colorStr)
        case .fontSize(let scale):
            font = font.withSize(font.pointSize * CGFloat(scale))
        case .fontFamily(let family):
            font = UIFont(name: family, size: font.pointSize) ?? font
        case .superscript:
            attrString.addAttribute(.baselineOffset, value: font.pointSize * 0.3, range: range)
            font = font.withSize(font.pointSize * 0.75)
        case .subscript:
            attrString.addAttribute(.baselineOffset, value: -font.pointSize * 0.2, range: range)
            font = font.withSize(font.pointSize * 0.75)
        case .code:
            font = theme.codeFont
            backgroundColor = theme.codeBackgroundColor
        }
    }
    
    // 一次性设置所有属性
    attrString.addAttribute(.font, value: font, range: range)
    attrString.addAttribute(.foregroundColor, value: foregroundColor, range: range)
    if let bgColor = backgroundColor {
        attrString.addAttribute(.backgroundColor, value: bgColor, range: range)
    }
    if let underline = underlineStyle {
        attrString.addAttribute(.underlineStyle, value: underline.rawValue, range: range)
    }
    if let strikethrough = strikethroughStyle {
        attrString.addAttribute(.strikethroughStyle, value: strikethrough.rawValue, range: range)
    }
    
    return attrString
}
```

### 3.3 Layout Calculator 简化

#### 旧版本

```swift
func calculateLayout(for node: ASTNodeWrapper) -> NodeLayout {
    switch node {
    case .strong(let strong):
        // 递归计算子节点
        let childLayout = calculateLayout(for: strong.children[0])
        // 应用粗体字体
        return applyBoldFont(to: childLayout)
    case .em(let em):
        // 又一层递归...
        ...
    }
}
```

#### 新版本

```swift
func calculateLayout(for node: ASTNodeWrapper) -> NodeLayout {
    switch node {
    case .text(let textRun):
        // 直接计算，无需递归！
        let attributedString = buildAttributedString(from: textRun)
        let size = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        return NodeLayout(
            node: node,
            frame: CGRect(origin: .zero, size: size),
            content: attributedString
        )
    
    // ❌ 不再需要 case .strong, .em, .underline, .strike, .code
    }
}
```

### 3.4 迁移步骤

#### 阶段 1：数据模型更新（3天）

1. 创建 `ASTNodesV2.swift`，实现新的 `TextStyle` 和 `TextRun`
2. 保留旧的 `ASTNodes.swift`，添加转换函数
3. 单元测试验证 JSON 序列化/反序列化

#### 阶段 2：渲染器适配（5天）

1. 创建 `UIKitAttributedStringBuilderV2.swift`
2. 优化 `buildAttributedString(from: TextRun)`
3. 性能测试对比（预期提升 10-50 倍）

#### 阶段 3：Layout 计算器适配（3天）

1. 更新 `UIKitFrameAsyncCalculator`
2. 移除递归样式处理逻辑
3. 简化缓存策略

#### 阶段 4：集成测试（2天）

1. 端到端测试
2. UI 回归测试
3. 性能基准测试

## 四、Android 渲染层迁移

### 4.1 Kotlin 数据模型更新

```kotlin
// TextStyle.kt

sealed class TextStyle {
    object Bold : TextStyle()
    object Italic : TextStyle()
    object Underline : TextStyle()
    object Strikethrough : TextStyle()
    data class Color(val color: String) : TextStyle()
    data class BackgroundColor(val color: String) : TextStyle()
    data class FontSize(val scale: Float) : TextStyle()
    data class FontFamily(val family: String) : TextStyle()
    object Superscript : TextStyle()
    object Subscript : TextStyle()
    object Code : TextStyle()
}

// TextRun.kt

data class TextRun(
    val content: String,
    val styles: List<TextStyle> = emptyList()
)
```

### 4.2 SpannableString 构建优化

```kotlin
// AndroidAttributedStringBuilder.kt

fun buildSpannableString(textRun: TextRun, theme: Theme): SpannableString {
    val spannable = SpannableString(textRun.content)
    val range = 0 until textRun.content.length
    
    var typeface = Typeface.DEFAULT
    var isBold = false
    var isItalic = false
    var textColor = theme.textColor
    var backgroundColor: Int? = null
    
    // 应用所有样式
    textRun.styles.forEach { style ->
        when (style) {
            is TextStyle.Bold -> isBold = true
            is TextStyle.Italic -> isItalic = true
            is TextStyle.Underline -> 
                spannable.setSpan(UnderlineSpan(), range.first, range.last, SPAN_EXCLUSIVE_EXCLUSIVE)
            is TextStyle.Strikethrough -> 
                spannable.setSpan(StrikethroughSpan(), range.first, range.last, SPAN_EXCLUSIVE_EXCLUSIVE)
            is TextStyle.Color -> 
                textColor = Color.parseColor(style.color)
            is TextStyle.BackgroundColor -> 
                backgroundColor = Color.parseColor(style.color)
            is TextStyle.FontSize -> 
                spannable.setSpan(
                    RelativeSizeSpan(style.scale), 
                    range.first, range.last, 
                    SPAN_EXCLUSIVE_EXCLUSIVE
                )
            is TextStyle.FontFamily -> 
                typeface = Typeface.create(style.family, Typeface.NORMAL)
            is TextStyle.Superscript -> 
                spannable.setSpan(SuperscriptSpan(), range.first, range.last, SPAN_EXCLUSIVE_EXCLUSIVE)
            is TextStyle.Subscript -> 
                spannable.setSpan(SubscriptSpan(), range.first, range.last, SPAN_EXCLUSIVE_EXCLUSIVE)
            is TextStyle.Code -> {
                typeface = Typeface.MONOSPACE
                backgroundColor = theme.codeBackgroundColor
            }
        }
    }
    
    // 应用字体样式
    if (isBold && isItalic) {
        typeface = Typeface.create(typeface, Typeface.BOLD_ITALIC)
    } else if (isBold) {
        typeface = Typeface.create(typeface, Typeface.BOLD)
    } else if (isItalic) {
        typeface = Typeface.create(typeface, Typeface.ITALIC)
    }
    
    spannable.setSpan(
        StyleSpan(typeface.style), 
        range.first, range.last, 
        SPAN_EXCLUSIVE_EXCLUSIVE
    )
    spannable.setSpan(
        ForegroundColorSpan(textColor), 
        range.first, range.last, 
        SPAN_EXCLUSIVE_EXCLUSIVE
    )
    backgroundColor?.let {
        spannable.setSpan(
            BackgroundColorSpan(it), 
            range.first, range.last, 
            SPAN_EXCLUSIVE_EXCLUSIVE
        )
    }
    
    return spannable
}
```

### 4.3 迁移步骤

类似 iOS，分 4 个阶段：
1. 数据模型更新（3天）
2. 渲染器适配（5天）
3. Layout 计算器适配（3天）
4. 集成测试（2天）

## 五、性能对比

### 5.1 理论分析

| 操作 | V1 | V2 | 提升 |
|------|----|----|------|
| **AST 构建** | O(n * d) | O(n) | d 倍（d=平均嵌套深度） |
| **渲染遍历** | 递归 d 层 | 扁平遍历 | 10-50 倍 |
| **内存占用** | n * d * node_size | n * run_size | 30-50% |
| **序列化** | 多层嵌套 | 扁平结构 | 2-5 倍 |

### 5.2 基准测试计划

```rust
// benches/ast_v2_benchmark.rs

#[bench]
fn bench_v1_complex_styles(b: &mut Bencher) {
    let markdown = "**_~~`hello`~~_** world";
    let parser = MarkdownParser::new();
    b.iter(|| {
        parser.parse(markdown)
    });
}

#[bench]
fn bench_v2_complex_styles(b: &mut Bencher) {
    let markdown = "**_~~`hello`~~_** world";
    let parser = MarkdownParserV2::new();
    b.iter(|| {
        parser.parse(markdown)
    });
}
```

预期结果：
- **解析速度**：V2 比 V1 快 2-3 倍
- **渲染速度**：V2 比 V1 快 10-50 倍（复杂样式场景）
- **内存占用**：V2 比 V1 减少 30-50%

## 六、风险评估

### 6.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 渲染结果不一致 | 高 | 详尽的回归测试 |
| 性能不如预期 | 中 | 性能基准测试 |
| FFI 接口变更 | 高 | 版本兼容层 |
| 现有代码依赖 | 中 | 渐进式迁移 |

### 6.2 时间估算

- **Rust Core**：2-3 周
- **iOS 渲染层**：1.5-2 周
- **Android 渲染层**：1.5-2 周
- **总体测试**：1 周

**总计：6-8 周**

## 七、向后兼容

### 7.1 版本策略

1. **V1.x → V2.0**：Breaking Change
2. **提供转换工具**：`convert_v1_to_v2()`
3. **文档说明**：详细的迁移指南

### 7.2 过渡期支持

- V1 和 V2 并行运行 1-2 个版本周期
- 提供 Feature Flag 切换
- 逐步废弃 V1 API

## 八、后续优化

1. **样式优化器**：合并相邻相同样式的 TextRun
2. **增量渲染**：只更新变化的节点
3. **虚拟滚动**：大文档性能优化
4. **WebAssembly**：Web 端渲染支持

