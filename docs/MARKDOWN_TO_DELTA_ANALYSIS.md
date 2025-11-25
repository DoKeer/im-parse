# Markdown 直接解析为 Delta JSON 方案分析

## 一、背景

### 1.1 现有架构

当前系统采用**统一 AST 中间层**的架构：

```
Markdown ──[MarkdownParser]──> AST ──[Renderer]──> UI
Delta JSON ──[DeltaParser]──> AST ──[Renderer]──> UI
```

- **MarkdownParser**: 将 Markdown 文本解析为 AST
- **DeltaParser**: 将 Delta JSON 解析为 AST
- **AST**: 统一的抽象语法树，包含所有支持的节点类型
- **Renderer**: 各平台（iOS/Android/Web）的渲染器，将 AST 渲染为 UI

### 1.2 问题

用户希望探索**直接路径**的可能性：

```
Markdown ──[MarkdownToDeltaConverter]──> Delta JSON ──[DeltaParser]──> AST ──[Renderer]──> UI
```

即：能否将 Markdown 直接转换为 Delta JSON，跳过 AST 中间层？

## 二、Delta JSON 结构分析

### 2.1 Delta 格式定义

Delta JSON 由 `ops` 数组组成，每个操作（Op）可以是：

```json
{
  "ops": [
    {
      "insert": "文本内容",
      "attributes": { "bold": true, "italic": true }
    },
    {
      "insert": "\n",
      "attributes": { "list": "ordered" }
    },
    {
      "insert": { "imageContainer": { "url": "...", "width": "320", "height": "217" } }
    },
    {
      "insert": { "emoji": { "content": "[加油]", "url": "..." } }
    },
    {
      "insert": { "mention": { "id": "...", "name": "..." } }
    },
    {
      "insert": { "formula": "x^2 + y^2 = z^2" }
    }
  ]
}
```

### 2.2 Delta 支持的 Attributes

- **文本样式**: `bold`, `italic`, `underline`, `strike`, `code`
- **链接**: `link` (URL 字符串)
- **颜色**: `color` (CSS 颜色字符串，如 `"#f06666"`)
- **列表**: `list` (`"ordered"` | `"bullet"` | `"checked"` | `"unchecked"`)
- **其他**: 通过 `Object` 类型支持图片、表情、提及、公式等

### 2.3 Delta 的块级元素表示方式

Delta 使用**线性操作序列**表示文档结构：

1. **段落**: 文本 + `\n`（无 list 属性）
2. **列表**: 文本 + `\n` + `{"list": "ordered"}` 或 `{"list": "bullet"}`
3. **任务列表**: 文本 + `\n` + `{"list": "checked"}` 或 `{"list": "unchecked"}`
4. **图片**: `{"insert": {"imageContainer": {...}}}`
5. **数学公式**: `{"insert": {"formula": "..."}}`
6. **其他块级元素**: 需要通过特殊 Object 或约定表示

## 三、Markdown 到 Delta JSON 映射分析

### 3.1 完全支持的映射

| Markdown 元素 | Delta JSON 表示 | 映射难度 | 说明 |
|--------------|----------------|---------|------|
| **段落** | `{"insert": "文本\n"}` | ✅ 简单 | 直接映射 |
| **粗体** | `{"insert": "文本", "attributes": {"bold": true}}` | ✅ 简单 | 直接映射 |
| **斜体** | `{"insert": "文本", "attributes": {"italic": true}}` | ✅ 简单 | 直接映射 |
| **删除线** | `{"insert": "文本", "attributes": {"strike": true}}` | ✅ 简单 | 直接映射 |
| **行内代码** | `{"insert": "代码", "attributes": {"code": true}}` | ✅ 简单 | 直接映射 |
| **链接** | `{"insert": "文本", "attributes": {"link": "url"}}` | ✅ 简单 | 直接映射 |
| **无序列表** | `{"insert": "文本\n", "attributes": {"list": "bullet"}}` | ✅ 简单 | 直接映射 |
| **有序列表** | `{"insert": "文本\n", "attributes": {"list": "ordered"}}` | ✅ 简单 | 直接映射 |
| **任务列表** | `{"insert": "文本\n", "attributes": {"list": "checked"}}` | ✅ 简单 | 直接映射 |
| **图片** | `{"insert": {"imageContainer": {"url": "...", "width": "...", "height": "..."}}}` | ✅ 简单 | 需要提取 alt 文本（可能丢失） |
| **数学公式（块级）** | `{"insert": {"formula": "..."}}` | ✅ 简单 | 直接映射 |
| **数学公式（行内）** | 需要特殊处理，见下文 | ⚠️ 中等 | Delta 可能不支持行内公式 |

### 3.2 需要特殊处理的映射

| Markdown 元素 | Delta JSON 表示方案 | 映射难度 | 问题 |
|--------------|-------------------|---------|------|
| **标题 (H1-H6)** | 方案1: 使用文本 + 约定属性<br>方案2: 转换为段落 + 样式<br>方案3: 使用 Object 扩展 | ⚠️ 中等 | Delta 标准不支持标题，需要扩展 |
| **代码块** | 方案1: 使用 Object 扩展<br>方案2: 转换为段落 + code 属性（不准确） | ⚠️ 中等 | Delta 标准不支持代码块，需要扩展 |
| **引用块** | 方案1: 使用 Object 扩展<br>方案2: 转换为段落 + 样式 | ⚠️ 中等 | Delta 标准不支持引用块，需要扩展 |
| **水平线** | 方案1: 使用 Object 扩展<br>方案2: 转换为特殊文本 | ⚠️ 中等 | Delta 标准不支持水平线，需要扩展 |
| **表格** | 方案1: 使用 Object 扩展<br>方案2: 转换为文本表示（丢失结构） | ❌ 困难 | Delta 标准不支持表格，需要复杂扩展 |
| **Mermaid** | 方案1: 使用 Object 扩展<br>方案2: 转换为代码块 Object | ⚠️ 中等 | Delta 标准不支持 Mermaid，需要扩展 |
| **HTML** | 方案1: 使用 Object 扩展<br>方案2: 转换为文本（丢失） | ⚠️ 中等 | Delta 标准不支持 HTML，需要扩展 |
| **行内数学公式** | 方案1: 使用 Object 扩展<br>方案2: 转换为文本 `$...$` | ⚠️ 中等 | Delta 的 Formula 是块级的，行内需要扩展 |

### 3.3 无法映射的元素

| Markdown 元素 | 原因 | 影响 |
|--------------|------|------|
| **表格对齐方式** | Delta 不支持表格 | 高 |
| **代码块语言标识** | Delta 标准不支持代码块 | 中 |
| **图片 alt 文本** | Delta imageContainer 可能不支持 | 低 |
| **引用块的嵌套结构** | Delta 不支持引用块 | 中 |
| **标题的语义级别** | Delta 不支持标题 | 高 |

## 四、方案对比分析

### 4.1 方案 A：现有架构（Markdown → AST → Renderer）

#### 优点 ✅

1. **完整性**: 支持所有 Markdown 和 Delta 特性
   - 所有 AST 节点类型都能完整表示
   - 不丢失任何语义信息

2. **统一性**: 单一数据模型
   - 所有输入格式（Markdown/Delta）都转换为统一的 AST
   - 渲染器只需处理一种数据格式

3. **可扩展性**: 易于添加新节点类型
   - 只需在 AST 中添加新节点类型
   - 各解析器和渲染器独立扩展

4. **类型安全**: Rust 类型系统保证
   - 编译时检查节点类型
   - 避免运行时错误

5. **测试简单**: 每个组件独立测试
   - MarkdownParser 测试
   - DeltaParser 测试
   - Renderer 测试

#### 缺点 ❌

1. **性能开销**: 两次转换
   - Markdown → AST → Delta（如果用户需要 Delta）
   - 额外的内存分配和序列化

2. **代码重复**: 两个解析器维护相似逻辑
   - MarkdownParser 和 DeltaParser 都需要处理数学公式
   - 样式处理逻辑可能重复

3. **间接性**: 如果最终目标是 Delta，需要额外步骤
   - Markdown → AST → Delta JSON（需要 AST 序列化器）

### 4.2 方案 B：直接转换（Markdown → Delta JSON）

#### 优点 ✅

1. **性能**: 单次转换
   - 直接生成 Delta JSON，减少中间步骤
   - 减少内存分配

2. **直接性**: 符合用户需求
   - 如果用户只需要 Delta JSON，直接生成更直观

3. **代码复用**: 可复用 DeltaParser 的部分逻辑
   - 数学公式解析逻辑
   - 样式处理逻辑

#### 缺点 ❌

1. **不完整性**: 无法支持所有 Markdown 特性
   - **标题**: Delta 标准不支持，需要扩展格式
   - **代码块**: Delta 标准不支持，需要扩展格式
   - **表格**: Delta 标准不支持，需要复杂扩展
   - **引用块**: Delta 标准不支持，需要扩展格式
   - **水平线**: Delta 标准不支持，需要扩展格式
   - **Mermaid**: Delta 标准不支持，需要扩展格式
   - **HTML**: Delta 标准不支持，需要扩展格式

2. **格式扩展**: 需要定义非标准 Delta 格式
   - 破坏 Delta 格式的兼容性
   - 其他 Delta 编辑器可能无法识别

3. **信息丢失**: 某些语义信息可能丢失
   - 标题级别可能丢失
   - 表格对齐方式可能丢失
   - 代码块语言标识可能丢失

4. **维护成本**: 需要维护两套转换逻辑
   - Markdown → Delta（新增）
   - Delta → AST（现有）
   - 如果 Delta 格式扩展，两处都需要更新

5. **测试复杂**: 需要测试多种边界情况
   - Markdown → Delta 转换正确性
   - 扩展格式的兼容性
   - 信息丢失的验证

6. **向后兼容**: 扩展格式可能导致问题
   - 如果 Delta 标准更新，扩展格式可能冲突
   - 其他工具可能无法解析扩展格式

### 4.3 方案 C：混合方案（Markdown → AST → Delta）

#### 优点 ✅

1. **完整性**: 保留所有信息
   - 通过 AST 完整表示所有 Markdown 特性
   - 转换为 Delta 时可以选择性处理

2. **灵活性**: 支持多种输出格式
   - AST → Delta JSON
   - AST → HTML
   - AST → 其他格式

3. **可扩展性**: 易于添加新格式
   - 只需添加新的 AST 序列化器

#### 缺点 ❌

1. **性能**: 仍然需要两次转换
   - Markdown → AST → Delta

2. **实现复杂度**: 需要实现 AST → Delta 序列化器
   - 需要处理所有节点类型
   - 需要处理扩展格式

## 五、技术实现分析

### 5.1 Markdown → Delta 直接转换的挑战

#### 挑战 1: 块级元素的线性化

Delta 使用线性操作序列，而 Markdown 是树形结构。

**示例：Markdown 标题**
```markdown
# 标题文本
```

**Delta 表示方案**：
```json
// 方案 1: 扩展格式（非标准）
{"insert": {"heading": {"level": 1, "text": "标题文本"}}}

// 方案 2: 转换为段落 + 样式（丢失语义）
{"insert": "标题文本\n", "attributes": {"heading": 1}}  // 非标准属性

// 方案 3: 转换为普通段落（完全丢失）
{"insert": "标题文本\n"}
```

#### 挑战 2: 嵌套结构的扁平化

**示例：Markdown 引用块中的列表**
```markdown
> - 列表项 1
> - 列表项 2
```

Delta 无法直接表示这种嵌套关系。

#### 挑战 3: 表格的复杂结构

**示例：Markdown 表格**
```markdown
| 列1 | 列2 |
|-----|-----|
| 数据1 | 数据2 |
```

Delta 标准完全不支持表格，需要定义复杂的扩展格式。

### 5.2 扩展 Delta 格式的设计

如果需要支持所有 Markdown 特性，需要定义扩展格式：

```json
{
  "ops": [
    {
      "insert": {"heading": {"level": 1, "children": [...]}}
    },
    {
      "insert": {"codeBlock": {"language": "rust", "content": "..."}}
    },
    {
      "insert": {"blockquote": {"children": [...]}}
    },
    {
      "insert": {"table": {"rows": [...]}}
    },
    {
      "insert": {"mermaid": {"content": "..."}}
    },
    {
      "insert": {"html": {"content": "..."}}
    },
    {
      "insert": {"horizontalRule": {}}
    }
  ]
}
```

**问题**：
1. 这些格式不是标准 Delta 格式
2. 其他 Delta 编辑器无法识别
3. 需要自定义解析逻辑

## 六、节点支持度分析

### 6.1 完全支持的节点（100%）

- ✅ Text
- ✅ Strong (bold)
- ✅ Em (italic)
- ✅ Strike
- ✅ Code (行内代码)
- ✅ Link
- ✅ List (有序/无序)
- ✅ ListItem (包括任务列表)
- ✅ Image
- ✅ Math (块级公式)
- ✅ Emoji
- ✅ Mention

### 6.2 部分支持的节点（需要扩展格式）

- ⚠️ Heading: 需要扩展格式或转换为段落
- ⚠️ CodeBlock: 需要扩展格式
- ⚠️ Blockquote: 需要扩展格式
- ⚠️ HorizontalRule: 需要扩展格式
- ⚠️ Mermaid: 需要扩展格式
- ⚠️ Html: 需要扩展格式
- ⚠️ Math (行内): 需要扩展格式（Delta 的 Formula 是块级的）

### 6.3 无法支持的节点（需要复杂扩展）

- ❌ Table: Delta 标准完全不支持，需要定义复杂的表格格式
- ❌ TableRow: 依赖 Table
- ❌ TableCell: 依赖 Table

### 6.4 支持度统计

- **完全支持**: 12/20 节点 (60%)
- **需要扩展**: 7/20 节点 (35%)
- **无法支持**: 1/20 节点 (5%)（Table 相关 3 个节点）

**总体支持度**: 约 60-95%（取决于是否接受扩展格式）

## 七、推荐方案

### 7.1 推荐：保持现有架构（方案 A）

**理由**：

1. **完整性优先**: 当前系统需要支持所有 Markdown 特性，直接转换会导致信息丢失
2. **标准兼容**: 保持 Delta 格式的标准性，不破坏兼容性
3. **维护性**: 单一数据模型更易维护
4. **可扩展性**: 未来添加新格式更容易

### 7.2 如果必须支持 Markdown → Delta 直接转换

**建议采用方案 C（混合方案）**：

1. **保留 AST 中间层**: 确保信息完整性
2. **实现 AST → Delta 序列化器**: 
   - 标准节点直接转换
   - 非标准节点使用扩展格式（需文档化）
   - 提供配置选项控制信息丢失策略

3. **扩展格式设计原则**:
   - 使用明确的命名空间（如 `"imParse.heading"`）
   - 提供回退机制（无法表示时转换为段落）
   - 完整文档化扩展格式

### 7.3 实施建议

如果决定实现 Markdown → Delta 直接转换：

1. **第一阶段**: 实现标准节点转换（60% 节点）
2. **第二阶段**: 设计并实现扩展格式（35% 节点）
3. **第三阶段**: 处理表格等复杂结构（5% 节点，或选择不支持）

**注意**: 扩展格式需要：
- 完整的格式规范文档
- 版本控制机制
- 兼容性测试
- 回退策略

## 八、总结

### 8.1 可行性结论

**技术上可行，但不推荐直接转换**。

- ✅ 约 60% 的节点可以直接映射
- ⚠️ 约 35% 的节点需要扩展格式
- ❌ 约 5% 的节点（表格）需要复杂扩展或选择不支持

### 8.2 关键权衡

| 维度 | 直接转换 | 现有架构 |
|------|---------|---------|
| **完整性** | ⚠️ 60-95% | ✅ 100% |
| **性能** | ✅ 更好 | ⚠️ 稍差 |
| **标准兼容** | ❌ 需要扩展 | ✅ 完全兼容 |
| **维护成本** | ❌ 较高 | ✅ 较低 |
| **可扩展性** | ⚠️ 受限 | ✅ 优秀 |

### 8.3 最终建议

**保持现有架构**，原因：

1. 完整性比性能更重要（除非性能是瓶颈）
2. 标准兼容性避免未来问题
3. 维护成本更低
4. 如果确实需要 Delta JSON 输出，可以实现 AST → Delta 序列化器（方案 C）

**如果性能是瓶颈**，可以考虑：
- 优化现有解析器性能
- 实现缓存机制
- 只在必要时进行转换

