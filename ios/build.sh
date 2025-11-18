#!/bin/bash

# 构建 Rust 静态库用于 iOS

set -e

# 确保 cargo/bin 在 PATH 中
if ! echo "$PATH" | grep -q "\.cargo/bin"; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# 检查 rustup 是否可用
if ! command -v rustup &> /dev/null; then
    echo "错误: 未找到 rustup 命令"
    echo "请先安装 Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "然后运行: source ~/.zshrc"
    exit 1
fi

# 检查是否有默认工具链
if ! rustup show default &> /dev/null 2>&1; then
    echo "设置默认 Rust 工具链..."
    rustup default stable
fi

cd "$(dirname "$0")/../rust-core"

# 检查并安装 iOS 目标平台
echo "检查 iOS 目标平台..."

if ! rustup target list --installed | grep -q "aarch64-apple-ios"; then
    echo "安装 aarch64-apple-ios 目标平台..."
    rustup target add aarch64-apple-ios
fi

if ! rustup target list --installed | grep -q "x86_64-apple-ios"; then
    echo "安装 x86_64-apple-ios 目标平台..."
    rustup target add x86_64-apple-ios
fi

# 构建 iOS 架构的静态库
echo "开始构建 Rust 库..."

# 检测 Mac 架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    # Apple Silicon Mac
    echo "检测到 Apple Silicon Mac"
    echo "构建 iOS 模拟器版本 (aarch64-apple-ios-sim)..."
    if ! rustup target list --installed | grep -q "aarch64-apple-ios-sim"; then
        echo "安装 aarch64-apple-ios-sim 目标平台..."
        rustup target add aarch64-apple-ios-sim
    fi
    cargo build --release --target aarch64-apple-ios-sim --features ffi
    SIM_TARGET="aarch64-apple-ios-sim"
else
    # Intel Mac
    echo "检测到 Intel Mac"
    echo "构建 iOS 模拟器版本 (x86_64-apple-ios)..."
    cargo build --release --target x86_64-apple-ios --features ffi
    SIM_TARGET="x86_64-apple-ios"
fi

# iOS 设备 (arm64) - 所有 Mac 都需要
echo "构建 iOS 设备版本 (aarch64-apple-ios)..."
cargo build --release --target aarch64-apple-ios --features ffi

echo ""
echo "构建完成！"
echo "静态库位置："
echo "  - rust-core/target/$SIM_TARGET/release/libim_parse_core.a (模拟器)"
echo "  - rust-core/target/aarch64-apple-ios/release/libim_parse_core.a (设备)"

