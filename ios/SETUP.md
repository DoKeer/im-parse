# iOS Demo 设置指南

## 前置要求

### 1. 安装 Rust

如果还没有安装 Rust，请运行：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

安装完成后，重新加载 shell 配置：

```bash
source $HOME/.cargo/env
```

### 2. 安装 iOS 目标平台

安装 iOS 编译目标：

```bash
# iOS 设备 (arm64)
rustup target add aarch64-apple-ios

# iOS 模拟器 (x86_64 for Intel Mac, 或 aarch64-apple-ios-sim for Apple Silicon)
rustup target add x86_64-apple-ios

# 如果是 Apple Silicon Mac，还需要安装模拟器目标
rustup target add aarch64-apple-ios-sim
```

### 3. 验证安装

检查目标平台是否已安装：

```bash
rustup target list --installed | grep ios
```

应该看到：
- `aarch64-apple-ios`
- `x86_64-apple-ios` (Intel Mac) 或 `aarch64-apple-ios-sim` (Apple Silicon)

## 构建 Rust 库

### 方法 1: 使用构建脚本（推荐）

```bash
cd ios
./build.sh
```

构建脚本会自动：
1. 检查 rustup 是否安装
2. 检查并安装 iOS 目标平台
3. 构建 iOS 设备版本
4. 构建 iOS 模拟器版本

### 方法 2: 手动构建

```bash
cd rust-core

# 构建 iOS 设备版本
cargo build --release --target aarch64-apple-ios --features ffi

# 构建 iOS 模拟器版本（Intel Mac）
cargo build --release --target x86_64-apple-ios --features ffi

# 或构建 iOS 模拟器版本（Apple Silicon Mac）
cargo build --release --target aarch64-apple-ios-sim --features ffi
```

## 常见问题

### 问题 1: `can't find crate for 'core'`

**错误信息：**
```
error[E0463]: can't find crate for `core`
  = note: the `aarch64-apple-ios` target may not be installed
```

**解决方法：**
运行以下命令安装目标平台：
```bash
rustup target add aarch64-apple-ios
rustup target add x86_64-apple-ios
```

### 问题 2: `command not found: rustup`

**错误信息：**
```
command not found: rustup
```

**解决方法：**
1. 确保已安装 Rust（见前置要求）
2. 重新加载 shell 配置：
   ```bash
   source $HOME/.cargo/env
   ```
3. 或重启终端

### 问题 3: 构建失败 - 链接错误

如果遇到链接错误，检查：
1. Xcode Command Line Tools 是否已安装：
   ```bash
   xcode-select --install
   ```
2. 确保使用正确的目标平台（设备 vs 模拟器）

### 问题 4: Apple Silicon Mac 上的模拟器

在 Apple Silicon Mac 上，iOS 模拟器使用 `aarch64-apple-ios-sim` 目标，而不是 `x86_64-apple-ios`。

安装命令：
```bash
rustup target add aarch64-apple-ios-sim
```

## 验证构建结果

构建成功后，应该生成以下文件：

```
rust-core/target/aarch64-apple-ios/release/libim_parse_core.a
rust-core/target/x86_64-apple-ios/release/libim_parse_core.a  # Intel Mac
# 或
rust-core/target/aarch64-apple-ios-sim/release/libim_parse_core.a  # Apple Silicon Mac
```

检查文件是否存在：
```bash
ls -lh rust-core/target/*/release/libim_parse_core.a
```

## 下一步

构建完成后，请参考 [INTEGRATION.md](./INTEGRATION.md) 了解如何在 Xcode 项目中集成这些库。

