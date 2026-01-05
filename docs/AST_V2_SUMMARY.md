# AST V2 优化方案总结

> 从Rust专家和解析器专家的角度，重新设计高性能、易扩展、渲染友好的AST结构

## 📋 目录

- [核心思想](#核心思想)
- [关键改进](#关键改进)
- [性能对比](#性能对比)
- [迁移路线图](#迁移路线图)
- [相关文档](#相关文档)

## 🎯 核心思想

### V1 问题（嵌套样式）

```
Strong
  └─ Em
      └─ Underline
          └─ Text("hello")
```

**问题**：
- 递归层级深（3-5层）
- 渲染需要递归遍历
- 内存占用高
- Delta 解析需要转换

### V2 优化（扁平样式）

```
TextRun {
  content: "hello"
  styles: [Bold, Italic, Underline]
}
```

**优势**：
- 扁平化结构（1层）
- 直接映射到原生控件
- 内存占用减少 30-50%
- Delta 直接对应

## 🚀 关键改进

### 1. 样式系统重构

#### 新增 TextStyle 枚举

```rust
pub enum TextStyle {
    // Markdown 样式
    Bold,
    Italic,
    Underline,
    Strikethrough,
    
    // Delta 富文本样式
    Color { color: String },
    BackgroundColor { color: String },
    FontSize { scale: f32 },
    FontFamily { family: String },
    
    // 科学排版
    Superscript,
    Subscript,
    
    // 代码样式
    Code,
}
```

#### TextRun 结构

```rust
pub struct TextRun {
    pub content: String,
    pub styles: Vec<TextStyle>,  // 可叠加样式
}
```

### 2. 块级/行内分离

```rust
pub enum ASTNode {
    // 块级元素
    Paragraph(ParagraphNode),
    Heading(HeadingNode),
    CodeBlock(CodeBlockNode),
    MathBlock(MathNode),      // ✅ 块级数学公式
    MermaidBlock(MermaidNode), // ✅ 块级 Mermaid
    
    // 行内元素
    Text(TextRun),            // ✅ 扁平化文本
    Link(LinkNode),
    InlineMath(MathNode),     // ✅ 行内数学公式
    LineBreak(LineBreakNode), // ✅ 明确的换行
}
```

### 3. 段落属性增强

```rust
pub struct ParagraphNode {
    pub children: Vec<ASTNode>,
    pub align: Option<TextAlign>,    // ✅ 对齐方式
    pub indent: u32,                 // ✅ 缩进级别
}
```

## 📊 性能对比

### 理论分析

| 指标 | V1 | V2 | 提升 |
|------|----|----|------|
| **AST 构建** | O(n·d) | O(n) | d 倍 |
| **渲染遍历** | 递归 d 层 | 扁平遍历 | 10-50x |
| **内存占用** | n·d·node_size | n·run_size | 30-50% ↓ |
| **序列化大小** | 多层嵌套 | 扁平结构 | 2-5x ↓ |

*注：d = 平均样式嵌套深度，n = 文本节点数量*

### 实际测试（预期）

| 场景 | V1 | V2 | 提升 |
|------|----|----|------|
| 简单文本（100字） | 5ms | 0.5ms | 10x |
| 复杂样式（100字，5层嵌套） | 50ms | 1ms | 50x |
| 长文档（10000字） | 500ms | 50ms | 10x |
| 内存占用（1万节点） | 10MB | 6MB | 40% ↓ |
| 滚动帧率（复杂文档） | 30-40 FPS | 55-60 FPS | 1.5-2x |

## 🗺️ 迁移路线图

### 总体时间：6-8 周

#### 第一阶段：Rust Core（2-3周）

✅ **Week 1-2：新 AST 实现**
- [ ] 创建 `ast_v2.rs`
- [ ] 创建 `ast_builder_v2.rs`
- [ ] 单元测试覆盖

✅ **Week 2-3：Parser 适配**
- [ ] `markdown_parser_v2.rs`
- [ ] `delta_parser_v2.rs`
- [ ] 集成测试

#### 第二阶段：iOS 渲染层（1.5-2周）

✅ **Week 3-4：Swift 适配**
- [ ] `ASTNodesV2.swift`
- [ ] `UIKitAttributedStringBuilderV2.swift`
- [ ] `UIKitFrameAsyncCalculatorV2.swift`
- [ ] `UIKitFrameRenderV2.swift`

#### 第三阶段：Android 渲染层（1.5-2周）

✅ **Week 4-5：Kotlin 适配**
- [ ] `TextStyle.kt`
- [ ] `AndroidAttributedStringBuilderV2.kt`
- [ ] `AndroidViewRendererV2.kt`

#### 第四阶段：测试与上线（1周）

✅ **Week 6：集成测试**
- [ ] 端到端测试
- [ ] 性能基准测试
- [ ] UI 回归测试

✅ **Week 7-8：灰度发布**
- [ ] 10% 用户灰度
- [ ] 50% 用户灰度
- [ ] 100% 全量上线

## 📚 相关文档

### 核心设计文档

1. **[AST_V2_MIGRATION_PLAN.md](./AST_V2_MIGRATION_PLAN.md)**
   - 详细的迁移计划
   - Rust Core 实现细节
   - 转换函数实现

2. **[RENDERER_V2_DESIGN.md](./RENDERER_V2_DESIGN.md)**
   - iOS 渲染层详细设计
   - Android 渲染层详细设计
   - 性能测试计划

### 代码实现

1. **Rust Core**
   - `rust-core/src/ast.rs` - 新 AST 定义
   - `rust-core/src/ast_builder_v2.rs` - 新 Builder

2. **iOS**
   - `ios/IMParseSDK/IMParseSDK/Classes/Models/ASTNodesV2.swift`
   - `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitAttributedStringBuilderV2.swift`
   - `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitFrameAsyncCalculatorV2.swift`

3. **Android**
   - `android/IMParseSDK/src/main/java/com/imparse/models/TextStyle.kt`
   - `android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidAttributedStringBuilderV2.kt`
   - `android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRendererV2.kt`

## 💡 最佳实践

### Rust Parser 实现

```rust
// ✅ 使用样式栈管理嵌套
builder.push_style(TextStyle::Bold);
builder.add_text("hello");
builder.pop_style("bold");

// ❌ 不要创建嵌套节点
let strong = StrongNode { children: ... };
```

### iOS 渲染实现

```swift
// ✅ 一次性构建 AttributedString
let attrString = buildAttributedString(from: textRun)

// ❌ 不要递归构建
func buildRecursively(node: ASTNode) {
    if case .strong(let strong) = node {
        for child in strong.children {
            buildRecursively(child)  // ❌
        }
    }
}
```

### Android 渲染实现

```kotlin
// ✅ 一次性构建 SpannableString
val spannable = buildSpannableString(textRun)

// ❌ 不要多次 setSpan
spannable.setSpan(BoldSpan(), ...)
spannable.setSpan(ItalicSpan(), ...)  // 可以一次性设置
```

## ⚠️ 注意事项

### 1. 样式优先级

样式列表按顺序应用，后面的覆盖前面的：

```rust
TextRun {
    content: "hello",
    styles: vec![
        TextStyle::Color { color: "#FF0000" },
        TextStyle::Color { color: "#00FF00" },  // ✅ 生效
    ]
}
```

### 2. Code 样式特殊处理

`Code` 样式优先级最高，会覆盖其他样式：

```rust
TextRun {
    content: "code",
    styles: vec![
        TextStyle::Bold,      // ❌ 被忽略
        TextStyle::Code,      // ✅ 生效
    ]
}
```

### 3. 段落属性不影响行内

段落的 `align` 和 `indent` 只影响块级布局，不影响行内样式：

```rust
ParagraphNode {
    align: Some(TextAlign::Center),  // 只影响段落对齐
    children: vec![
        ASTNode::Text(TextRun {
            styles: vec![TextStyle::Bold],  // 不受影响
            ...
        })
    ]
}
```

## 🔧 工具与资源

### 性能测试工具

```bash
# Rust 基准测试
cd rust-core
cargo bench --bench ast_v2_benchmark

# iOS 性能测试
cd ios/iOS-demo
xcodebuild test -scheme iOS-demo -destination 'platform=iOS Simulator,name=iPhone 14'

# Android 性能测试
cd android/Android-demo
./gradlew connectedAndroidTest
```

### 转换工具

```rust
// V1 → V2 转换
let v1_ast = old_parser.parse(markdown)?;
let v2_ast = convert_v1_to_v2(v1_ast);
```

## 📞 联系方式

如有问题，请联系：
- Rust Core：负责人 A
- iOS 渲染：负责人 B
- Android 渲染：负责人 C

---

**最后更新**：2025-01-05  
**版本**：V2.0.0  
**状态**：设计阶段

