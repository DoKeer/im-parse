# 数学公式解析分析

## 测试用例

**输入：**
```markdown
伽玛函数：$\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!$（$z \in \mathbb{C}, \Re(z)>0$）
```

## 解析结果

### AST 结构

```json
{
  "children": [
    {
      "type": "paragraph",
      "children": [
        {
          "type": "text",
          "content": "伽玛函数："
        },
        {
          "type": "math",
          "content": "\\Gamma(z) = \\int_0^\\infty t^{z-1}e^{-t} dt = (z-1)!",
          "display": false
        },
        {
          "type": "text",
          "content": "（"
        },
        {
          "type": "math",
          "content": "z \\in \\mathbb{C}, \\Re(z)>0",
          "display": false
        },
        {
          "type": "text",
          "content": "）"
        }
      ]
    }
  ]
}
```

### 节点分布

段落包含 **5 个子节点**：

| 序号 | 类型 | 内容 |
|------|------|------|
| 0 | Text | "伽玛函数：" |
| 1 | **Math** | `\Gamma(z) = \int_0^\infty t^{z-1}e^{-t} dt = (z-1)!` |
| 2 | Text | "（" |
| 3 | **Math** | `z \in \mathbb{C}, \Re(z)>0` |
| 4 | Text | "）" |

---

## 合理性分析

### ✅ 当前实现是完全合理的

#### 1. 数学公式独立性

- 两个 `$...$` 是**两个独立的数学公式**
- 它们有不同的语义：
  - 第一个：**函数定义**（伽玛函数的积分表达式）
  - 第二个：**定义域条件**（z 的取值范围）
- 解析为两个独立的 `Math` 节点是正确的

#### 2. 文本保留完整性

- 中间的文本（冒号、括号）被保留为 `Text` 节点
- 这保证了**原文的完整性**和**渲染的准确性**
- 后续渲染时可以正确还原为：`伽玛函数：[公式1]（[公式2]）`

#### 3. 语义清晰性

独立的节点结构使语义更清晰：

```
伽玛函数：[定义] （[条件]）
   ↓        ↓       ↓
  Text    Math    Math
```

这种结构便于：
- **独立渲染**：可以对每个公式单独应用样式
- **语义分析**：可以识别"定义-条件"关系
- **交互处理**：可以对每个公式单独处理（如复制、编辑）

---

## 对比分析

### 方案 A：当前实现（推荐 ✅）

**结构：**
```
Text("伽玛函数：") + Math(定义) + Text("（") + Math(条件) + Text("）")
```

**优点：**
- ✅ 语义独立，结构清晰
- ✅ 保留原文完整性
- ✅ 便于独立处理每个公式
- ✅ 符合 Markdown 语法（两个 `$...$` = 两个独立公式）

**缺点：**
- 无明显缺点

---

### 方案 B：合并为一个节点（不推荐 ❌）

**结构：**
```
Text("伽玛函数：") + Math(定义 + 条件) + Text("）")
```

**问题：**
- ❌ 违反 Markdown 语法（两个 `$...$` 不应该合并）
- ❌ 语义混乱（定义和条件混在一起）
- ❌ 丢失了括号等文本信息
- ❌ 无法独立处理每个公式

---

## 更多测试用例验证

### 测试 1：两个独立公式
```markdown
公式1：$x^2$ 和公式2：$y^2$
```

**解析结果：** ✅ 2 个 Math 节点
- Math: `x^2`
- Math: `y^2`

### 测试 2：主公式和条件
```markdown
$a + b$（其中 $a, b \in \mathbb{R}$）
```

**解析结果：** ✅ 2 个 Math 节点
- Math: `a + b`
- Math: `a, b \in \mathbb{R}`

### 测试 3：条件和结论
```markdown
当 $n \to \infty$ 时，$f(n) \to 0$
```

**解析结果：** ✅ 2 个 Math 节点
- Math: `n \to \infty`
- Math: `f(n) \to 0`

---

## 渲染建议

### Android/iOS 渲染

当渲染多个相邻的 Math 节点时，建议：

```kotlin
// Android 示例
when (node) {
    is MathNode -> {
        // 行内公式使用行内样式
        if (!node.display) {
            renderInlineMath(node.content)
        } else {
            renderBlockMath(node.content)
        }
    }
    is TextNode -> {
        renderText(node.content)
    }
}
```

**关键点：**
- 每个 Math 节点独立渲染
- Text 节点保留原样（括号、冒号等）
- 行内公式与文本在同一行显示

---

## 语义型解析器演进

当前的结构为语义型解析器演进提供了良好的基础：

### 未来可以添加语义标注

```rust
pub struct MathNode {
    pub content: String,
    pub display: bool,
    // 未来可以添加：
    pub semantic_role: Option<MathRole>,  // Definition, Condition, Result, etc.
    pub related_nodes: Vec<NodeId>,       // 关联的节点（如条件公式关联定义公式）
}

pub enum MathRole {
    Definition,     // 定义公式
    Condition,      // 条件公式
    Result,         // 结果公式
    Derivation,     // 推导过程
}
```

### 语义分析示例

对于 `伽玛函数：$定义$（$条件$）`，可以分析为：

```rust
// 语义分析后
MathNode {
    content: "\\Gamma(z) = ...",
    display: false,
    semantic_role: Some(MathRole::Definition),
    related_nodes: [node_id_of_condition],  // 指向条件公式
}

MathNode {
    content: "z \\in \\mathbb{C}, ...",
    display: false,
    semantic_role: Some(MathRole::Condition),
    related_nodes: [node_id_of_definition],  // 指向定义公式
}
```

---

## 结论

### ✅ 当前实现完全正确，无需修改

**理由：**

1. **符合 Markdown 语法**：两个 `$...$` = 两个独立的行内公式
2. **语义清晰**：定义和条件分离，便于理解和处理
3. **渲染灵活**：可以对每个公式单独应用样式和交互
4. **演进友好**：为语义分析预留了空间

### 推荐做法

对于包含多个数学公式的文本：
- ✅ 保持当前的解析方式（独立节点）
- ✅ 在渲染层正确处理相邻的 Math 节点
- ✅ 未来可以通过语义分析添加关联关系

---

**测试文件：** `rust-core/tests/test_gamma_function.rs`  
**测试结果：** ✅ 所有测试通过  
**最后更新：** 2025-01-XX

