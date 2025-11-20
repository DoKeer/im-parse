# IMParseSDK 安装指南

## 前置要求

1. **Rust 工具链**: 需要安装 Rust 和 iOS 目标平台
   ```bash
   # 安装 Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # 添加 iOS 目标
   rustup target add aarch64-apple-ios
   rustup target add aarch64-apple-ios-sim
   rustup target add x86_64-apple-ios  # 可选，用于 Intel Mac 模拟器
   ```

2. **Xcode**: 需要安装 Xcode 和命令行工具
   ```bash
   xcode-select --install
   ```

3. **CocoaPods**: 用于依赖管理
   ```bash
   sudo gem install cocoapods
   ```

## 构建 Rust 核心库

在首次使用 SDK 或更新 Rust 代码后，需要构建 Rust 核心库：

```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

这个脚本会：
1. 构建 iOS 设备版本 (arm64)
2. 构建 iOS 模拟器版本 (arm64 和 x86_64)
3. 使用 `lipo` 合并为通用静态库
4. 复制到 SDK 的 `Libraries` 目录

## 在项目中使用

### 方法 1: 本地路径（开发时）

在项目的 `Podfile` 中添加：

```ruby
platform :ios, '13.0'

target 'YourApp' do
  use_frameworks!
  
  # 本地路径
  pod 'IMParseSDK', :path => '../im-parse/ios/IMParseSDK'
end
```

然后运行：

```bash
pod install
```

### 方法 2: Git 仓库（发布后）

在项目的 `Podfile` 中添加：

```ruby
platform :ios, '13.0'

target 'YourApp' do
  use_frameworks!
  
  # Git 仓库
  pod 'IMParseSDK', :git => 'https://github.com/your-org/im-parse.git', :tag => '0.1.0'
end
```

## 验证安装

创建一个简单的测试文件：

```swift
import IMParseSDK

let message = Message(
    type: .markdown,
    content: "# Hello, World!",
    sender: "Test"
)

message.parse()
print("AST JSON: \(message.astJSON ?? "nil")")
```

如果能够成功编译和运行，说明安装成功。

## 常见问题

### 1. 找不到 libim_parse_core.a

**问题**: 编译时提示找不到静态库

**解决**: 运行构建脚本生成库文件
```bash
cd ios/IMParseSDK
./build-rust-lib.sh
```

### 2. 链接错误

**问题**: 链接时出现符号未找到错误

**解决**: 检查 podspec 中的 `OTHER_LDFLAGS` 配置，确保使用了 `-force_load`

### 3. 架构不匹配

**问题**: 在模拟器上运行时出现架构不匹配错误

**解决**: 确保构建了所有需要的架构，并正确合并为通用库

### 4. 头文件找不到

**问题**: 编译时找不到 IMParseBridge.h

**解决**: 检查 podspec 中的 `HEADER_SEARCH_PATHS` 配置

## 更新 SDK

当更新 SDK 代码后：

1. 如果修改了 Rust 代码，重新构建库：
   ```bash
   cd ios/IMParseSDK
   ./build-rust-lib.sh
   ```

2. 更新 Pod 依赖：
   ```bash
   cd YourProject
   pod update IMParseSDK
   ```

3. 清理并重新编译项目

