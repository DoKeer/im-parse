# Markdown Parser 结构性优化方案

## 📊 当前架构分析

### 风险点确认

#### ⚠️ 风险一：Event 流控制分散（结构性问题）

**当前问题：**
```rust
// 在 3 个函数中分散控制 Event 流：
- collect_inline_content    // peek + next
- collect_block_content     // peek + next  
- collect_list_item_content // peek + next
```

**问题诊断：**
1. **状态控制隐式化**：Event 消费逻辑分散在递归调用栈中
2. **难以证明正确性**：无法静态分析"所有 Event 都被正确消费"
3. **维护成本高**：新增 Tag 时需要同时修改多个函数
4. **潜在死锁风险**：嵌套的 `peek() + break` 可能导致事件错位

**具体代码证据：**
- L287-395: `collect_inline_content` 中混杂了 13 种 Event 处理
- L563-757: `collect_block_content` 递归调用自身和其他 collect
- L759-1000: `collect_list_item_content` 有相似的混合逻辑

---

#### ⚠️ 风险二：数学公式解析 O(n²) 复杂度

**性能路径分析：**
```
flush_text_buffer()
  ├─ buffer.iter().map()           // O(n)
  ├─ split_block_math()            // O(n)
  ├─ split_inline_math()           // O(n)
  └─ process_text_fragment_with_styles()
        ├─ buffer.iter()           // O(m)  ← 对每个文本片段
        ├─ text.chars().collect()  // O(k)
        └─ chars[local_start..end] // O(k)
```

**复杂度计算：**
- `buffer` 长度 = m 个 TextFragment
- 总文本长度 = n 字符
- 每次 `process_text_fragment_with_styles` 扫描整个 buffer
- 最坏情况：**O(m × n) = O(n²)**（m ∝ n）

**风险场景：**
- IM 场景中的长消息（1000+ 字符）
- 表格单元格内的复杂公式
- 粘贴的学术论文片段

**当前代码证据：**
- L514-546: `process_text_fragment_with_styles` 每次都线性扫描 buffer
- L533: `text.chars().collect()` 重复字符索引
- L454-461: 嵌套循环处理 inline math

---

#### ⚠️ 风险三：InlineStyle 嵌套顺序不可靠

**当前假设（危险）：**
```rust
// L1228: 假设 styles 的顺序 = 语义嵌套顺序
for style in styles.iter().rev() {
    current = wrap(style, current)
}
```

**反例场景：**
```markdown
**Bold *nested italic** still italic*
<!-- pulldown-cmark 可能产生：[Strong, Em] -->
<!-- 但语义上 Em 应该在 Strong 外 -->
```

**风险来源：**
- 依赖 pulldown-cmark 的"善意行为"
- 不合法 Markdown 输入会破坏假设
- HTML 混入时顺序未定义
- Delta → Markdown 转换时可能产生非法嵌套

---

## 🎯 优化方案

### 阶段一：Event 流控制重构（优先级：🔴 高）

#### 设计原则
**显式区分两层架构：**

```rust
// Layer 1: Event 流控制（集中式）
trait EventConsumer {
    fn consume_until(&mut self, end_tag: TagEnd) -> Vec<Event>;
}

// Layer 2: AST 构造（纯函数）
trait ASTBuilder {
    fn build_paragraph(events: &[Event]) -> ParagraphNode;
    fn build_heading(events: &[Event], level: u8) -> HeadingNode;
}
```

#### 实现策略

**1. 引入 EventStream 封装**
```rust
struct EventStream<'a, I: Iterator<Item = Event<'a>>> {
    inner: Peekable<I>,
    position: usize,  // 调试用：追踪消费位置
}

impl<'a, I> EventStream<'a, I> {
    // 集中式消费
    fn consume_until(&mut self, matcher: impl Fn(&Event) -> bool) -> Vec<Event> {
        let mut events = Vec::new();
        while let Some(event) = self.inner.peek() {
            if matcher(event) {
                break;
            }
            events.push(self.inner.next().unwrap());
        }
        events
    }
    
    // 安全的终止消费
    fn expect_end(&mut self, expected: TagEnd) -> Result<(), ParseError> {
        match self.inner.next() {
            Some(Event::End(tag)) if tag == expected => Ok(()),
            other => Err(ParseError::UnexpectedEvent(format!("{:?}", other)))
        }
    }
}
```

**2. 重构 collect_inline_content**
```rust
// 旧版：290 行，混合控制
fn collect_inline_content(...) { ... }

// 新版：分离职责
fn parse_inline_context(&mut self, stream: &mut EventStream) -> Vec<ASTNode> {
    let events = stream.consume_until(|e| matches!(e, 
        Event::End(TagEnd::Paragraph | TagEnd::TableCell | ...)
    ));
    self.build_inline_nodes(&events)
}

fn build_inline_nodes(&self, events: &[Event]) -> Vec<ASTNode> {
    // 纯函数：不消费 stream，只构造 AST
}
```

#### 收益
- ✅ Event 消费逻辑集中在 `EventStream`
- ✅ 易于单元测试（`build_*` 系列函数）
- ✅ 新增 Tag 时只需修改 `consume_until` 匹配器
- ✅ 可添加 `#[cfg(debug)]` 的消费追踪

---

### 阶段二：基于 Span 的文本处理（优先级：🟡 中）

#### 目标
将复杂度从 **O(n²)** 降至 **O(n)**

#### 数据结构重构

**旧版：**
```rust
struct TextFragment {
    content: String,      // 存储实际内容
    styles: Vec<InlineStyle>,
}
```

**新版：**
```rust
struct TextSpan {
    start: usize,         // 在完整文本中的字节偏移
    end: usize,
    styles: Vec<InlineStyle>,
}

struct TextBuffer {
    full_text: String,    // 完整文本（一次性构建）
    spans: Vec<TextSpan>, // 样式区间
}
```

#### 处理流程优化

**1. 累积阶段**
```rust
impl TextBuffer {
    fn push(&mut self, text: &str, styles: &[InlineStyle]) {
        let start = self.full_text.len();
        self.full_text.push_str(text);
        let end = self.full_text.len();
        
        self.spans.push(TextSpan {
            start,
            end,
            styles: styles.to_vec(),
        });
    }
}
```

**2. 数学公式解析优化**
```rust
enum MathSpan {
    Text { start: usize, end: usize },
    Math { start: usize, end: usize, display: bool },
}

fn parse_math_spans(text: &str) -> Vec<MathSpan> {
    // 一次遍历，产出 (start, end, kind)
    // 无需重复字符串切片
}
```

**3. 样式应用优化**
```rust
fn build_styled_nodes(buffer: &TextBuffer, math_spans: &[MathSpan]) -> Vec<ASTNode> {
    let mut nodes = Vec::new();
    
    for math_span in math_spans {
        match math_span {
            MathSpan::Math { start, end, display } => {
                nodes.push(ASTNode::Math(MathNode {
                    content: buffer.full_text[*start..*end].to_string(),
                    display: *display,
                }));
            }
            MathSpan::Text { start, end } => {
                // 使用区间树快速查找覆盖的样式 spans
                let styles = buffer.find_overlapping_spans(*start, *end);
                nodes.extend(apply_styles(&buffer.full_text[*start..*end], &styles));
            }
        }
    }
    
    nodes
}
```

#### 复杂度分析

| 操作 | 旧版 | 新版 | 改进 |
|------|------|------|------|
| 文本累积 | O(n) | O(n) | - |
| 数学公式解析 | O(n) | O(n) | - |
| 样式查找 | O(m×n) | O(m log m) | **O(n) → O(log n)** |
| 总复杂度 | O(n²) | O(n log n) | **显著提升** |

#### 收益
- ✅ 长文本性能提升 10-100 倍（实测需要 benchmark）
- ✅ 内存占用降低（减少字符串切片）
- ✅ 代码更清晰（分离"解析位置"和"构造节点"）

---

### 阶段三：样式嵌套安全性增强（优先级：🟢 低）

#### 问题根源
依赖 `Vec<InlineStyle>` 的 push/pop 顺序来推断嵌套关系。

#### 解决方案

**1. 引入样式树结构**
```rust
#[derive(Debug, Clone)]
enum StyleTree {
    Leaf(InlineStyle),
    Nested {
        style: InlineStyle,
        children: Vec<StyleTree>,
    },
}
```

**2. 构造显式样式栈**
```rust
struct StyleStack {
    stack: Vec<InlineStyle>,
    open_positions: HashMap<InlineStyle, usize>,
}

impl StyleStack {
    fn push(&mut self, style: InlineStyle) {
        self.open_positions.insert(style.clone(), self.stack.len());
        self.stack.push(style);
    }
    
    fn pop(&mut self, style: &InlineStyle) -> Result<(), StyleMismatch> {
        // 检查是否正确闭合
        if let Some(&pos) = self.open_positions.get(style) {
            if pos != self.stack.len() - 1 {
                // 发现交错嵌套，返回警告
                return Err(StyleMismatch {
                    expected: self.stack.last(),
                    got: style.clone(),
                });
            }
            self.stack.pop();
            self.open_positions.remove(style);
            Ok(())
        } else {
            Err(StyleMismatch::NotOpened)
        }
    }
}
```

**3. 兼容模式处理**
```rust
fn build_styled_nodes_safe(content: String, styles: &[InlineStyle]) -> Vec<ASTNode> {
    // 尝试构造样式树
    match StyleTree::from_flat_list(styles) {
        Ok(tree) => build_from_tree(content, tree),
        Err(StyleMismatch { .. }) => {
            // 降级：拍平所有样式
            eprintln!("Warning: style mismatch, falling back to flat rendering");
            build_flat(content, styles)
        }
    }
}
```

#### 收益
- ✅ 检测不合法的样式嵌套
- ✅ Delta → Markdown 场景更健壮
- ✅ 调试信息更清晰

---

## 📅 实施计划

### Sprint 1: Event 流控制重构（3-5 天）
- [ ] 实现 `EventStream` 封装
- [ ] 重构 `parse()` 主函数使用 EventStream
- [ ] 迁移 `collect_inline_content` → `parse_inline_context`
- [ ] 迁移 `collect_block_content` → `parse_block_context`
- [ ] 单元测试：确保所有现有测试通过

### Sprint 2: Span-based 文本处理（5-7 天）
- [ ] 实现 `TextSpan` 和 `TextBuffer`
- [ ] 重构 `flush_text_buffer` 使用 Span
- [ ] 优化 `split_block_math` 返回 Span
- [ ] 优化 `split_inline_math` 返回 Span
- [ ] 性能测试：对比旧版 benchmark

### Sprint 3: 样式嵌套安全（2-3 天）
- [ ] 实现 `StyleStack` 和错误检测
- [ ] 添加兼容模式降级逻辑
- [ ] 集成测试：不合法 Markdown 输入

### Sprint 4: 清理和文档（1-2 天）
- [ ] 删除旧代码
- [ ] 更新架构文档
- [ ] 性能报告
- [ ] Code review

---

## 🔍 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 重构引入新 bug | 中 | 高 | 保留旧代码，A/B 测试 |
| Span 计算错误（Unicode） | 低 | 高 | 使用 `char_indices()`，添加 Unicode 测试 |
| 性能优化无效 | 低 | 中 | 先 benchmark 再优化 |
| 兼容性破坏 | 低 | 中 | 保持 API 不变，内部重构 |

---

## 📈 成功指标

1. **代码质量**
   - 降低圈复杂度：`collect_*` 函数从 15+ 降至 < 10
   - 减少代码行数：预计减少 20%

2. **性能**
   - 长文本解析（1000+ 字符）：提升 5-10 倍
   - 内存占用：降低 30%

3. **可维护性**
   - 新增 Tag 支持：修改点从 3 处降至 1 处
   - 单元测试覆盖率：从 60% 提升至 90%

---

## 🎓 参考资料

### 解析器设计模式
- **Two-stage parsing**: Lexing → Parsing
- **Pushdown automaton**: 状态机 + 栈
- **Span-based IR**: Rust Compiler 的设计

### 类似项目
- `comrak` (CommonMark parser): 使用 Arena 分配
- `pulldown-cmark` 本身的优化历史
- `rustdoc` 的 Markdown 处理

---

## 💡 长期优化方向

### 1. Arena 分配
减少 `Vec<ASTNode>` 的堆分配，使用 `typed-arena`：
```rust
struct Parser<'arena> {
    arena: &'arena Arena<ASTNode>,
}
```

### 2. 并行解析
对于超长文档（10K+ 字符），可以分块并行解析：
- 按段落边界切分
- 使用 `rayon` 并行处理
- 合并 AST

### 3. 增量解析
支持文档编辑场景：
- 缓存 AST
- 只重新解析修改的段落
- 类似 Tree-sitter 的设计

---

## ✅ 结论

当前代码的三个风险点都**确实存在**，并且在以下场景会暴露：

1. **Event 流控制混乱** → 维护新 Tag 时出 bug
2. **O(n²) 复杂度** → IM 长消息场景性能差
3. **样式嵌套不可靠** → 不合法 Markdown 渲染错误

优化方案按优先级排序：
1. 🔴 **Event 流重构**（必须做）
2. 🟡 **Span 优化**（推荐做）
3. 🟢 **样式安全**（可选做）

**建议：先完成 Sprint 1，验证架构可行性后再继续。**

