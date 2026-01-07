# Link 节点语义优化说明

## 问题背景

之前的 Link 节点设计在语义层不够完整，存在以下问题：

1. **语义边界不清晰**：Link.children 允许任意 InlineNode，但 Markdown 规范有约束（如 link inside link 不允许）
2. **可点击语义与内容分离**：Link 的交互语义没有明确表达
3. **Link 类型缺失**：没有区分显式链接、自动链接、引用链接

## 优化内容

### 1. 增强 LinkNode 语义信息

在 `ast.rs` 中增强了 `LinkNode` 的定义：

```rust
pub enum LinkKind {
    Explicit,  // 显式链接：[text](url)
    Autolink,  // 自动链接：<https://example.com>
    Reference, // 引用链接：[text][id]
}

pub struct LinkNode {
    pub url: String,
    pub children: Vec<ASTNode>,
    pub title: Option<String>,
    pub kind: LinkKind,  // 新增：链接类型
}
```

### 2. 语义验证

在 `markdown_parser.rs` 中添加了 `validate_and_clean_link_children` 方法：

- **移除嵌套的 Link 节点**：符合 Markdown 规范（链接内不能包含链接）
- **保留合法的行内节点**：Text、InlineMath、Image 等
- **展平嵌套链接**：将嵌套链接的文本内容保留，但移除链接语义

### 3. 链接类型检测

添加了 `detect_link_kind` 方法：

- **Autolink 检测**：通过检查 children 是否为空或只包含与 URL 相同的文本
- **Reference 检测**：需要在解析阶段进行（pulldown_cmark 可能已将其解析为普通链接）
- **Explicit 默认**：其他情况默认为显式链接

### 4. 解析器改进

在 `build_inline_nodes` 方法中：

- **检测嵌套链接**：跟踪 link_depth，正确处理嵌套情况
- **语义验证**：调用 `validate_and_clean_link_children` 确保 AST 语义正确
- **类型检测**：调用 `detect_link_kind` 设置链接类型

## 语义约束

### 允许的 Link.children

- ✅ Text 节点
- ✅ InlineMath 节点
- ✅ Image 节点（Markdown 规范允许）
- ✅ 样式文本（Bold、Italic 等）

### 禁止的 Link.children

- ❌ 嵌套的 Link 节点（Markdown 规范禁止）
- ❌ 块级节点（Paragraph、Heading 等）

## 交互语义

Link 节点表示：
- **整个 children 范围都是可点击的**
- **点击行为**：导航到 `url`
- **悬停行为**：显示 `title`（如果存在）

## Round-trip 考虑

### 当前限制

1. **嵌套链接展平**：如果输入包含嵌套链接，AST 会将其展平，round-trip 时会丢失嵌套信息
2. **Reference link 检测**：pulldown_cmark 可能已将 reference link 解析为普通链接，无法完全区分

### 未来改进方向

1. **在 Event 流层面检测**：在解析阶段就区分 autolink 和 reference link
2. **保留原始信息**：添加 `original_markdown` 字段用于 round-trip
3. **更精确的类型检测**：通过分析原始 Markdown 文本来确定链接类型

## 测试覆盖

新增测试用例：

- ✅ `test_link_kind_explicit`：验证显式链接类型
- ✅ `test_nested_link_validation`：验证嵌套链接的处理
- ✅ `test_link_with_image`：验证链接内包含图片
- ✅ `test_link_with_math`：验证链接内包含数学公式

## 总结

### ✅ 已解决的问题

1. **语义边界清晰**：通过验证函数确保 Link.children 符合 Markdown 规范
2. **交互语义明确**：整个 children 范围共享链接的交互语义
3. **链接类型区分**：添加了 LinkKind 枚举，支持显式、自动、引用三种类型

### ⚠️ 仍需改进

1. **Reference link 检测**：需要更精确的检测机制
2. **Round-trip 完整性**：嵌套链接的展平会导致信息丢失
3. **Autolink 检测**：当前检测方法可能不够准确

### 📌 判断标准

根据"如果我把 AST 序列化 → 再反向生成 Markdown / Delta，我会不会丢信息？"的标准：

- **当前状态**：会丢失部分信息（嵌套链接、reference link 的原始形式）
- **改进方向**：在 AST 中保留更多原始信息，或改进检测算法

## 使用建议

1. **渲染器**：应该将整个 Link.children 范围视为可点击区域
2. **编辑器**：应该禁止在链接内创建嵌套链接
3. **AI/分析**：可以利用 LinkKind 进行更精确的语义分析

