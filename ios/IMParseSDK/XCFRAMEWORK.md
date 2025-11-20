# XCFramework 构建说明

## 概述

IMParseSDK 现在使用 XCFramework 来分发 Rust 核心库，这样可以：
- ✅ 支持所有架构（真机和模拟器）
- ✅ 解决相同架构但不同平台的问题（arm64 真机 vs arm64 模拟器）
- ✅ 更好的 Xcode 集成
- ✅ 支持 Apple Silicon 和 Intel Mac

## 构建流程

### 1. 运行构建脚本

```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

### 2. 构建过程

脚本会执行以下步骤：

1. **构建 Rust 静态库**（各架构）：
   - `aarch64-apple-ios` - iOS 真机 (arm64)
   - `aarch64-apple-ios-sim` - iOS 模拟器 (arm64, Apple Silicon Mac)
   - `x86_64-apple-ios` - iOS 模拟器 (x86_64, Intel Mac，可选)

2. **创建 Framework**：
   - 为真机创建独立的 Framework (`ios-arm64`)
   - 为模拟器创建 Framework，并使用 `lipo` 合并 arm64 和 x86_64 架构（如果都有）
   - Framework 包含静态库二进制、Info.plist、module.modulemap

3. **创建 XCFramework**：
   - 使用 `xcodebuild -create-xcframework` 合并所有 Framework
   - 输出到 `IMParseSDK/Libraries/im_parse_core.xcframework`

### 3. 输出文件

构建完成后，会在 `IMParseSDK/Libraries/` 目录下生成：

```
im_parse_core.xcframework/
├── Info.plist
├── ios-arm64/
│   └── im_parse_core.framework/
│       ├── im_parse_core (二进制, arm64)
│       ├── Info.plist
│       ├── Headers/
│       └── Modules/
└── ios-arm64_x86_64-simulator/
    └── im_parse_core.framework/
        ├── im_parse_core (二进制, universal: arm64 + x86_64)
        ├── Info.plist
        ├── Headers/
        └── Modules/
```

**注意**: 模拟器平台名称是 `ios-arm64_x86_64-simulator`，这是 xcodebuild 自动生成的，表示合并了 arm64 和 x86_64 两个架构的 universal binary。

## XCFramework 优势

### 1. 架构支持

XCFramework 包含：
- **ios-arm64**: 真机设备 (arm64)
- **ios-arm64_x86_64-simulator**: 模拟器（合并了 arm64 和 x86_64 架构）
  - Apple Silicon Mac 模拟器使用 arm64 部分
  - Intel Mac 模拟器使用 x86_64 部分

### 2. 自动选择

Xcode 会根据构建目标自动选择正确的 Framework：
- 构建真机 → 使用 `ios-arm64`
- 构建模拟器 → 使用 `ios-arm64_x86_64-simulator`
  - Apple Silicon Mac 自动选择 arm64 架构
  - Intel Mac 自动选择 x86_64 架构

### 3. 无需手动链接

使用 XCFramework 时，不需要：
- ❌ `-force_load` 标志
- ❌ 手动指定库路径
- ❌ 担心架构匹配问题

## CocoaPods 集成

podspec 会自动检测并使用 XCFramework：

```ruby
s.vendored_frameworks = 'IMParseSDK/Libraries/im_parse_core.xcframework'
```

如果 XCFramework 不存在，pod install 会报错，提示运行构建脚本。

## 验证

### 检查 XCFramework 内容

```bash
# 查看 XCFramework 结构
ls -la IMParseSDK/Libraries/im_parse_core.xcframework/

# 查看包含的平台
xcodebuild -checkFirstLaunchStatus 2>/dev/null || true
```

### 检查 Framework 架构

```bash
# 检查真机 Framework
file IMParseSDK/Libraries/im_parse_core.xcframework/ios-arm64/im_parse_core.framework/im_parse_core

# 检查模拟器 Framework
file IMParseSDK/Libraries/im_parse_core.xcframework/ios-arm64-simulator/im_parse_core.framework/im_parse_core
```

## 常见问题

### Q: 为什么使用 Framework 而不是静态库？

A: Framework 是 Apple 推荐的现代分发方式，支持：
- 更好的模块化
- 自动架构选择
- 更好的 Xcode 集成
- 支持 XCFramework

### Q: Framework 和静态库的区别？

A: Framework 是一个目录结构，包含：
- 二进制文件（可以是静态库）
- Headers（头文件）
- Info.plist（元数据）
- Modules（模块映射）

静态库（.a）只是一个二进制文件。

### Q: 如何更新 Rust 库？

A: 修改 Rust 代码后，重新运行构建脚本：
```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

### Q: 如果构建失败怎么办？

A: 检查：
1. Rust 工具链是否安装
2. iOS 目标平台是否已添加
3. Xcode 命令行工具是否安装
4. 查看错误信息，可能需要安装缺失的目标平台

## 手动构建（如果脚本失败）

如果自动脚本失败，可以手动执行：

```bash
cd rust-core

# 1. 构建各架构
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios  # 可选

# 2. 创建 Framework（需要手动创建目录结构和文件）
# 3. 使用 xcodebuild 创建 XCFramework
xcodebuild -create-xcframework \
    -framework path/to/ios-arm64/framework \
    -framework path/to/ios-arm64-simulator/framework \
    -framework path/to/ios-x86_64-simulator/framework \
    -output path/to/output.xcframework
```

但建议使用提供的构建脚本，它会自动处理所有步骤。

