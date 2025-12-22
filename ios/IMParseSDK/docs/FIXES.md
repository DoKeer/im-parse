# IMParseSDK 编译问题修复说明

## 修复的问题

### 1. 函数调用歧义错误

**问题**: Swift 编译器报告 "Ambiguous use of 'xxx'" 错误

**原因**: 在 Swift 文件中使用 `@_silgen_name` 声明了 C 函数，同时头文件中也声明了这些函数，导致冲突。

**解决方案**: 
- 移除了 Swift 文件中的所有 `@_silgen_name` 声明
- 通过 umbrella header (`IMParseSDK.h`) 导入 C 函数
- C 函数和结构体定义在 `IMParseBridge.h` 中，通过 CocoaPods 的自动 bridging 机制访问

### 2. 类型推断错误

**问题**: `Cannot infer contextual base in reference to member 'utf8'`

**原因**: Swift 无法推断 `data(using:)` 方法的参数类型

**解决方案**: 
- 明确指定类型：`String.Encoding.utf8` 而不是 `.utf8`

### 3. Rust 库多架构支持

**问题**: Rust 核心库需要支持真机和模拟器的不同架构

**解决方案**:
- 使用 `build-rust-lib.sh` 脚本构建各架构的静态库
- 使用 `lipo` 工具合并为通用静态库（fat binary）
- podspec 中使用合并后的通用库
- Xcode 会根据构建目标自动选择正确的架构

## 架构支持

### 支持的架构

1. **真机 (arm64)**: `aarch64-apple-ios`
2. **Apple Silicon 模拟器 (arm64)**: `aarch64-apple-ios-sim`
3. **Intel Mac 模拟器 (x86_64)**: `x86_64-apple-ios` (可选)

### 构建流程

```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

脚本会：
1. 构建各架构的静态库
2. 使用 `lipo` 合并为通用库
3. 输出到 `IMParseSDK/Libraries/libim_parse_core.a`

### 验证架构

```bash
lipo -info IMParseSDK/Libraries/libim_parse_core.a
```

## 文件变更

### IMParseBridge.swift
- 移除了所有 `@_silgen_name` 声明
- 移除了重复的 C 结构体定义
- 通过 umbrella header 访问 C 函数

### StyleConfig.swift
- 移除了 `@_silgen_name` 声明
- 修复了类型推断问题（使用 `String.Encoding.utf8`）
- 通过 umbrella header 访问 C 函数

### IMParseBridge.h
- 添加了 `mermaid_to_html` 函数声明
- 添加了 `free_string` 函数声明

### IMParseSDK.podspec
- 更新了链接标志，添加了 `$(inherited)`
- 添加了 `preserve_paths` 配置

## 使用说明

1. **构建 Rust 库**:
   ```bash
   cd ios/IMParseSDK
   ./build-rust-lib.sh
   ```

2. **安装 Pod**:
   ```bash
   cd ios/iOS-demo
   pod install
   ```

3. **在代码中使用**:
   ```swift
   import IMParseSDK
   
   // 所有 C 函数和类型都通过模块自动可用
   let result = IMParseCore.parseMarkdown("# Hello")
   ```

## 注意事项

- 必须使用 `.xcworkspace` 打开项目（不是 `.xcodeproj`）
- 确保 Rust 库已构建并合并为通用库
- 如果修改了 Rust 代码，需要重新运行构建脚本

