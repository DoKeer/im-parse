# IMParse iOS Demo

这是一个用于测试 IMParse SDK 的 iOS Demo 应用。

## 功能特性

- ✅ 支持 1000 条测试消息（Markdown 和 Delta 混合）
- ✅ UIKit 版本的消息列表
- ✅ SwiftUI 版本的消息列表
- ✅ 消息解析和 AST 生成
- ✅ 高度预计算
- ✅ 虚拟滚动优化

## 项目结构

```
ios/
├── IMParseBridge.h          # C FFI 头文件
├── IMParseBridge.swift      # Swift FFI 包装
├── Message.swift            # 消息模型和数据生成器
├── UIKitMessageListViewController.swift  # UIKit 列表视图
├── SwiftUIMessageListView.swift         # SwiftUI 列表视图
└── DemoApp.swift            # 应用入口
```

## 集成 Rust 库

### 1. 构建 Rust 静态库

```bash
cd rust-core
cargo build --release --features ffi
```

这会生成 `libim_parse_core.a` 静态库。

### 2. 在 Xcode 中配置

1. 将 `libim_parse_core.a` 添加到项目
2. 添加头文件搜索路径：`rust-core/target/release/include`（如果有）
3. 链接 Rust 库和系统库：
   - `libim_parse_core.a`
   - `libc++`
   - `libresolv`

### 3. 桥接头文件

创建 `IMParseDemo-Bridging-Header.h`：

```objc
#import "IMParseBridge.h"
```

## 使用方法

1. 打开 Xcode 项目
2. 运行应用
3. 在 Tab 栏切换 UIKit 和 SwiftUI 视图
4. 查看消息列表性能和渲染效果

## 测试场景

- **大量消息**：1000 条消息测试滚动性能
- **混合格式**：Markdown 和 Delta 消息混合
- **高度计算**：测试高度预计算的准确性
- **解析性能**：测试解析速度
- **内存占用**：监控内存使用情况

## 注意事项

1. 需要先构建 Rust 库
2. 确保 FFI 函数正确链接
3. 在实际项目中，应该将 AST JSON 解析为 Swift 对象并使用 SwiftUIRenderer 渲染

