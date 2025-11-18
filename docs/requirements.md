# 富文本解析与渲染系统 - 需求文档

## 一、项目概述

### 1.1 项目背景
构建一个高性能、跨平台的富文本解析与渲染系统，支持多种输入格式（Markdown、Quill Delta），统一输出为 HTML AST，并在 iOS、Android、Electron/Web 等平台上提供一致的渲染体验。

### 1.2 核心目标
- **统一解析**：将 Markdown 和 Quill Delta 两种格式统一解析为 HTML AST
- **跨平台渲染**：支持 iOS SwiftUI、Android Compose、Electron/Web 多平台
- **高性能**：支持高度预计算、缓存机制，适合 IM 场景大量消息渲染
- **可扩展**：支持自定义节点、数学公式、Mermaid 图表等扩展能力

## 二、功能需求

### 2.1 输入格式支持

#### 2.1.1 Markdown 格式
支持标准 Markdown 语法及以下扩展：
- **基础语法**：标题、段落、粗体、斜体、删除线、代码、链接
- **表格**：支持表格语法，包括表头、对齐方式
- **任务列表**：支持 `- [ ]` 和 `- [x]` 语法
- **代码块**：支持语法高亮，指定编程语言
- **高亮**：支持文本高亮（`==text==`）
- **数学公式**：支持 KaTeX 格式的数学公式
- **Mermaid 图表**：支持 Mermaid 语法绘制流程图、时序图等

#### 2.1.2 Quill Delta 格式
支持 Quill 标准 Delta JSON 格式，包括：
- **文本插入**：纯文本内容
- **格式化属性**：粗体、斜体、下划线、删除线、颜色、背景色
- **链接**：超链接支持
- **代码块**：代码块及语言标识
- **列表**：有序列表、无序列表
- **图片**：图片插入，支持 URL、宽度、高度
- **公式**：数学公式支持
- **自定义属性**：支持扩展自定义属性

### 2.2 统一 AST 输出

#### 2.2.1 AST 节点类型
系统应支持以下节点类型：

| 节点类型 | 说明 | 属性 |
|---------|------|------|
| RootNode | 根节点 | children: Vec<ASTNode> |
| ParagraphNode | 段落 | children: Vec<ASTNode> |
| HeadingNode | 标题 | level: u8, children: Vec<ASTNode> |
| TextNode | 文本 | content: String |
| StrongNode | 粗体 | children: Vec<ASTNode> |
| EmNode | 斜体 | children: Vec<ASTNode> |
| UnderlineNode | 下划线 | children: Vec<ASTNode> |
| StrikeNode | 删除线 | children: Vec<ASTNode> |
| CodeNode | 行内代码 | content: String |
| CodeBlockNode | 代码块 | language: String, content: String |
| LinkNode | 链接 | url: String, children: Vec<ASTNode> |
| ImageNode | 图片 | url: String, width: Option<f32>, height: Option<f32>, alt: Option<String> |
| ListNode | 列表 | list_type: ListType, items: Vec<ListItemNode> |
| ListItemNode | 列表项 | children: Vec<ASTNode>, checked: Option<bool> |
| TableNode | 表格 | rows: Vec<TableRow> |
| TableRow | 表格行 | cells: Vec<TableCell> |
| TableCell | 表格单元格 | children: Vec<ASTNode>, align: Option<TextAlign> |
| MathNode | 数学公式 | content: String, display: bool |
| MermaidNode | Mermaid 图表 | content: String |
| CardNode | 卡片 | subtype: String, content: String, metadata: HashMap<String, String> |
| MentionNode | @提及 | id: String, name: String |
| HorizontalRuleNode | 水平分割线 | - |
| BlockquoteNode | 引用块 | children: Vec<ASTNode> |

#### 2.2.2 AST 序列化格式
AST 以 JSON 格式序列化，便于跨平台传输和缓存。

### 2.3 跨平台渲染

#### 2.3.1 iOS SwiftUI 渲染器
- 支持所有 AST 节点类型的 SwiftUI 视图渲染
- 支持异步图片加载
- 支持代码块语法高亮
- 支持数学公式渲染（使用 MathView）
- 支持 Mermaid 图表渲染（使用 WebView 或 SVG）
- 支持交互：链接点击、图片预览、@提及点击

#### 2.3.2 Android Compose 渲染器
- 支持所有 AST 节点类型的 Compose 组件渲染
- 支持异步图片加载
- 支持代码块语法高亮
- 支持数学公式渲染
- 支持 Mermaid 图表渲染
- 支持交互：链接点击、图片预览、@提及点击

#### 2.3.3 Electron/Web 渲染器
- 基于 React 的组件化渲染
- 支持 WASM 解析器集成
- 支持代码块语法高亮（Prism.js 或 highlight.js）
- 支持数学公式渲染（KaTeX）
- 支持 Mermaid 图表渲染（Mermaid.js）
- 支持交互：链接点击、图片预览、@提及点击

### 2.4 性能优化

#### 2.4.1 高度预计算
- 每个 AST 节点支持 `estimatedHeight(width: f32) -> f32` 方法
- 支持文本高度计算（考虑字体、行高、换行）
- 支持图片高度计算（考虑宽高比、最大宽度）
- 支持代码块高度估算（基于行数、字体大小）
- 支持表格高度计算（考虑行数、单元格内容）

#### 2.4.2 缓存机制
- **AST 缓存**：解析后的 AST 结果缓存，避免重复解析
- **渲染结果缓存**：渲染后的视图缓存，支持增量更新
- **高度缓存**：计算后的高度值缓存，避免重复计算
- **图片缓存**：图片下载和缩略图缓存

#### 2.4.3 懒加载
- 支持虚拟滚动，只渲染可见区域的内容
- 图片懒加载，进入可视区域才加载
- 复杂节点（Mermaid、数学公式）延迟渲染

### 2.5 扩展能力

#### 2.5.1 自定义节点
- 支持注册自定义节点类型
- 支持自定义渲染器
- 支持自定义属性解析

#### 2.5.2 主题系统
- 支持统一主题配置
- 支持暗色/亮色模式切换
- 支持自定义颜色、字体、间距

#### 2.5.3 增量更新
- 支持 AST 节点级别的增量更新
- 支持差异对比，只更新变化的部分
- 支持动画过渡效果

## 三、非功能需求

### 3.1 性能要求
- **解析性能**：单条消息（< 10KB）解析时间 < 10ms
- **渲染性能**：首次渲染时间 < 50ms（不含图片加载）
- **内存占用**：单条消息 AST 内存占用 < 100KB
- **缓存命中率**：重复消息缓存命中率 > 90%

### 3.2 兼容性要求
- **iOS**：支持 iOS 14.0+
- **Android**：支持 Android 5.0+ (API 21+)
- **Web**：支持现代浏览器（Chrome 90+, Safari 14+, Firefox 88+）
- **Electron**：支持 Electron 12+

### 3.3 可维护性要求
- 代码模块化，职责清晰
- 完善的单元测试和集成测试
- 详细的 API 文档和代码注释
- 支持 TypeScript/Swift/Kotlin 类型检查

### 3.4 安全性要求
- 输入内容安全过滤（XSS 防护）
- 链接 URL 验证
- 图片资源来源验证
- 代码执行沙箱隔离

## 四、技术约束

### 4.1 解析层
- 使用 Rust 或 C++ 实现核心解析逻辑
- 编译为 WASM 供 Web 端使用
- 提供原生库供移动端使用

### 4.2 中间格式
- AST 以 JSON 格式序列化
- 支持二进制序列化（MessagePack）以提升性能

### 4.3 渲染层
- iOS 使用 SwiftUI
- Android 使用 Jetpack Compose
- Web/Electron 使用 React

## 五、验收标准

### 5.1 功能验收
- [ ] 支持 Markdown 所有标准语法和扩展语法
- [ ] 支持 Quill Delta 所有标准格式
- [ ] Markdown 和 Delta 输入渲染效果一致
- [ ] 所有 AST 节点类型在三个平台上正确渲染
- [ ] 高度预计算准确度 > 95%
- [ ] 缓存机制正常工作，性能提升明显

### 5.2 性能验收
- [ ] 解析性能满足要求
- [ ] 渲染性能满足要求
- [ ] 内存占用在合理范围
- [ ] 大量消息（> 1000 条）滚动流畅

### 5.3 兼容性验收
- [ ] 在目标平台和版本上正常运行
- [ ] 不同屏幕尺寸和分辨率适配正常
- [ ] 不同字体大小设置下显示正常

## 六、项目里程碑

### 阶段一：核心解析器（2 周）
- Markdown 解析器实现
- Delta 解析器实现
- 统一 AST 定义
- 基础单元测试

### 阶段二：跨平台渲染器（3 周）
- iOS SwiftUI 渲染器
- Android Compose 渲染器
- Web React 渲染器
- 基础交互功能

### 阶段三：性能优化（2 周）
- 高度预计算实现
- 缓存机制实现
- 懒加载优化
- 性能测试和调优

### 阶段四：扩展功能（2 周）
- 自定义节点支持
- 主题系统
- 增量更新
- 完整测试覆盖

### 阶段五：文档和发布（1 周）
- API 文档完善
- 使用示例和教程
- 性能报告
- 版本发布

## 七、风险评估

### 7.1 技术风险
- **WASM 性能**：WASM 解析性能可能不如原生，需要优化
- **跨平台一致性**：不同平台渲染效果可能存在细微差异
- **复杂节点渲染**：Mermaid 和数学公式在不同平台渲染复杂度高

### 7.2 进度风险
- 解析器开发可能比预期复杂
- 跨平台适配工作量可能超出预期
- 性能优化可能需要多次迭代

### 7.3 缓解措施
- 提前进行技术验证（POC）
- 采用渐进式开发，先实现核心功能
- 建立完善的测试体系，及时发现问题
- 预留缓冲时间应对意外情况

