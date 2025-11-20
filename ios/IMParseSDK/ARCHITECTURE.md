# Rust 核心库架构支持说明

## 架构支持

IMParseSDK 使用 **XCFramework** 来分发 Rust 核心库，支持以下 iOS 架构：

1. **真机 (arm64)**: `aarch64-apple-ios` → `ios-arm64`
2. **模拟器 (arm64)**: `aarch64-apple-ios-sim` → `ios-arm64-simulator` (Apple Silicon Mac)
3. **模拟器 (x86_64)**: `x86_64-apple-ios` → `ios-x86_64-simulator` (Intel Mac，可选)

## 构建流程

### 1. 构建各架构并创建 XCFramework

使用 `build-rust-lib.sh` 脚本自动构建：

```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

脚本会：
1. 构建各架构的 Rust 静态库：
   - `aarch64-apple-ios` (真机)
   - `aarch64-apple-ios-sim` (Apple Silicon 模拟器)
   - `x86_64-apple-ios` (Intel Mac 模拟器，如果可用)

2. 为每个架构创建 Framework：
   - 从静态库创建 Framework 结构
   - 包含 Info.plist、module.modulemap 等

3. 使用 `xcodebuild -create-xcframework` 合并为 XCFramework：
   - 包含所有平台的 Framework
   - 自动处理架构选择

### 2. 输出文件

构建完成后，会在 `IMParseSDK/Libraries/` 目录下生成：

- `im_parse_core.xcframework` - **XCFramework**（包含所有架构）
  - `ios-arm64/im_parse_core.framework/` - 真机 Framework
  - `ios-arm64-simulator/im_parse_core.framework/` - Apple Silicon 模拟器 Framework
  - `ios-x86_64-simulator/im_parse_core.framework/` - Intel Mac 模拟器 Framework（如果构建了）

### 3. CocoaPods 集成

podspec 使用 XCFramework：

```ruby
s.vendored_frameworks = 'IMParseSDK/Libraries/im_parse_core.xcframework'
```

CocoaPods 和 Xcode 会根据构建目标自动选择正确的 Framework：
- 构建真机 → 使用 `ios-arm64`
- 构建 Apple Silicon 模拟器 → 使用 `ios-arm64-simulator`
- 构建 Intel Mac 模拟器 → 使用 `ios-x86_64-simulator`

## 架构选择逻辑

### 问题说明

`aarch64-apple-ios` 和 `aarch64-apple-ios-sim` 都编译为 `arm64` 架构，但它们是不同的平台：
- 真机使用 `ios-arm64`
- 模拟器使用 `ios-arm64-simulator`

`lipo` 工具无法合并相同架构但不同平台的库，因此需要使用 **XCFramework**。

### 解决方案

构建脚本会自动创建 XCFramework，支持：
- **真机设备**: `ios-arm64` (arm64)
- **Apple Silicon Mac 模拟器**: `ios-arm64-simulator` (arm64)
- **Intel Mac 模拟器**: `ios-x86_64-simulator` (x86_64，如果构建了)

Xcode 会根据构建目标自动选择正确的库。

## 验证 XCFramework

可以使用以下命令检查 XCFramework：

```bash
# 查看 XCFramework 结构
ls -la IMParseSDK/Libraries/im_parse_core.xcframework/

# 查看包含的平台
find IMParseSDK/Libraries/im_parse_core.xcframework -name "*.framework" -type d

# 检查每个 Framework 的架构
file IMParseSDK/Libraries/im_parse_core.xcframework/ios-arm64/im_parse_core.framework/im_parse_core
file IMParseSDK/Libraries/im_parse_core.xcframework/ios-arm64-simulator/im_parse_core.framework/im_parse_core
```

输出示例：
```
ios-arm64/im_parse_core.framework/im_parse_core: Mach-O universal binary with 1 architecture: [arm64]
ios-arm64-simulator/im_parse_core.framework/im_parse_core: Mach-O universal binary with 1 architecture: [arm64]
```

## 常见问题

### Q: 为什么使用 XCFramework 而不是静态库？

A: XCFramework 是 Apple 推荐的现代分发方式，优势包括：
- ✅ 支持相同架构但不同平台（arm64 真机 vs arm64 模拟器）
- ✅ 自动架构选择，无需手动配置
- ✅ 更好的 Xcode 集成
- ✅ 支持所有架构（真机和模拟器）

### Q: Framework 和静态库的区别？

A: Framework 是一个目录结构，包含：
- 二进制文件（可以是静态库）
- Headers（头文件）
- Info.plist（元数据）
- Modules（模块映射）

静态库（.a）只是一个二进制文件。

### Q: 如何更新 Rust 库？

A: 修改 Rust 代码后，重新运行 `build-rust-lib.sh` 脚本即可。

### Q: 如果构建失败怎么办？

A: 检查：
1. Rust 工具链是否安装
2. iOS 目标平台是否已添加（`rustup target add aarch64-apple-ios` 等）
3. Xcode 命令行工具是否安装
4. 查看错误信息，可能需要安装缺失的目标平台

## 更多信息

详细说明请参考：[XCFRAMEWORK.md](XCFRAMEWORK.md)

