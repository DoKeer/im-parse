# IM Parse - 富文本解析与渲染系统

一个高性能、跨平台的富文本解析与渲染系统，支持 Markdown 和 Quill Delta 两种输入格式，统一输出为 HTML AST，并在 iOS、Android、Electron/Web 等平台上提供一致的渲染体验。

## 📋 目录

- [功能特性](#功能特性)
- [架构设计](#架构设计)
- [快速开始](#快速开始)
- [使用示例](#使用示例)
- [API 文档](#api-文档)
- [性能优化](#性能优化)
- [开发指南](#开发指南)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

## ✨ 功能特性

### 输入格式支持

- **Markdown**：支持标准 Markdown 语法及扩展
  - 基础语法：标题、段落、粗体、斜体、删除线、代码、链接
  - 表格：支持表格语法，包括表头、对齐方式
  - 任务列表：支持 `- [ ]` 和 `- [x]` 语法
  - 代码块：支持语法高亮，指定编程语言
  - 高亮：支持文本高亮（`==text==`）
  - 数学公式：支持 KaTeX 格式的数学公式
  - Mermaid 图表：支持 Mermaid 语法绘制流程图、时序图等

- **Quill Delta**：支持 Quill 标准 Delta JSON 格式
  - 文本插入和格式化
  - 链接、图片、代码块
  - 有序/无序列表
  - 数学公式
  - 自定义属性

### 跨平台渲染

- **iOS**：SwiftUI 渲染器
- **Android**：Jetpack Compose 渲染器
- **Web/Electron**：React 渲染器

### 性能优化

- **高度预计算**：每个 AST 节点支持高度估算
- **缓存机制**：AST、渲染结果、高度值多级缓存
- **懒加载**：虚拟滚动、图片懒加载、复杂节点延迟渲染

### 扩展能力

- 自定义节点类型
- 统一主题系统
- 增量更新支持

## 🏗️ 架构设计

```
输入层 (Markdown / Delta)
    │
    ▼
统一解析层 (Rust/C++/WASM)
    │
    ▼
统一 HTML AST (JSON)
    │
    ├─ iOS SwiftUI Renderer
    ├─ Android Compose Renderer
    └─ Web/Electron React Renderer
    │
    ▼
性能优化层 (高度预计算 / 缓存 / 懒加载)
```

详细架构设计请参考 [技术架构设计文档](docs/architecture.md)

## 🚀 快速开始

### 安装

#### Rust 核心库

```bash
cd rust-core
cargo build --release
```

#### iOS

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/im-parse-ios", from: "0.1.0")
]
```

#### Android

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.imparse:core:0.1.0")
}
```

#### Web

```bash
npm install @imparse/core
```

### 基本使用

#### Rust

```rust
use im_parse_core::*;

// 解析 Markdown
let ast = parse_markdown("# Hello World")?;

// 解析 Delta
let delta_json = r#"{"ops":[{"insert":"Hello World\n"}]}"#;
let ast = parse_delta(delta_json)?;

// 序列化为 JSON
let json = serialize_ast(&ast)?;
```

#### iOS SwiftUI

```swift
import IMParse

let parser = MarkdownParser()
let ast = parser.parse(markdown: "# Hello World")
let renderer = SwiftUIRenderer()
let view = renderer.render(ast: ast, context: RenderContext(
    theme: .default,
    width: 300
))
```

#### Android Compose

```kotlin
import com.imparse.*

val parser = MarkdownParser()
val ast = parser.parse(markdown = "# Hello World")
setContent {
    RenderAST(
        node = ast,
        context = RenderContext(
            theme = Theme.default,
            width = 300f
        )
    )
}
```

#### Web React

```typescript
import { parseMarkdown, RenderAST } from '@imparse/core';

const ast = parseMarkdown('# Hello World');
ReactDOM.render(
  <RenderAST node={ast} />,
  document.getElementById('root')
);
```

## 📖 使用示例

### Markdown 解析示例

```rust
let markdown = r#"
# 标题

这是一个**粗体**和*斜体*的段落。

- 列表项 1
- 列表项 2

\`\`\`rust
fn main() {
    println!("Hello, world!");
}
\`\`\`
"#;

let ast = parse_markdown(markdown)?;
```

### Delta 解析示例

```rust
let delta = r#"{
  "ops": [
    {"insert": "Hello "},
    {"insert": "World", "attributes": {"bold": true}},
    {"insert": "\n"},
    {"insert": "Item", "attributes": {"list": "bullet"}},
    {"insert": "\n"}
  ]
}"#;

let ast = parse_delta(delta)?;
```

### 高度预计算示例

```rust
use im_parse_core::*;

let ast = parse_markdown("# Hello World")?;
let context = RenderContext::default();
let height = ast.estimated_height(300.0, &context);
```

## 📚 API 文档

### Rust API

- [AST 节点类型](rust-core/src/ast.rs)
- [Markdown 解析器](rust-core/src/markdown_parser.rs)
- [Delta 解析器](rust-core/src/delta_parser.rs)

### iOS API

- [SwiftUI 渲染器](ios/SwiftUIRenderer.swift)

### Android API

- [Compose 渲染器](android/ComposeRenderer.kt)

### Web API

- [React 渲染器](web/src/RenderAST.tsx)

## ⚡ 性能优化

### 解析性能

- 单条消息（< 10KB）解析时间 < 10ms
- 使用 Rust 实现，性能优异

### 渲染性能

- 首次渲染时间 < 50ms（不含图片加载）
- 支持高度预计算，避免布局抖动

### 内存占用

- 单条消息 AST 内存占用 < 100KB
- 支持缓存清理机制

### 缓存命中率

- 重复消息缓存命中率 > 90%
- 支持 TTL 和手动清理

## 🛠️ 开发指南

### 项目结构

```
im-parse/
├── docs/                    # 文档
│   ├── requirements.md     # 需求文档
│   └── architecture.md     # 架构设计文档
├── rust-core/              # Rust 核心库
│   ├── src/
│   │   ├── lib.rs
│   │   ├── ast.rs
│   │   ├── markdown_parser.rs
│   │   ├── delta_parser.rs
│   │   ├── ast_builder.rs
│   │   └── cache.rs
│   └── Cargo.toml
├── ios/                     # iOS 渲染器
│   └── SwiftUIRenderer.swift
├── android/                 # Android 渲染器
│   └── ComposeRenderer.kt
└── web/                     # Web 渲染器
    └── src/
        ├── RenderAST.tsx
        └── types.ts
```

### 构建

#### Rust

```bash
cd rust-core
cargo build --release
```

#### iOS

```bash
cd ios
swift build
```

#### Android

```bash
cd android
./gradlew build
```

#### Web

```bash
cd web
npm install
npm run build
```

### 测试

```bash
# Rust 测试
cd rust-core
cargo test

# 性能测试
cargo bench
```

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 📞 联系方式

- 问题反馈：[GitHub Issues](https://github.com/your-org/im-parse/issues)
- 功能建议：[GitHub Discussions](https://github.com/your-org/im-parse/discussions)

## 🙏 致谢

- [pulldown-cmark](https://github.com/raphlinus/pulldown-cmark) - Markdown 解析器
- [Quill](https://quilljs.com/) - Delta 格式参考

