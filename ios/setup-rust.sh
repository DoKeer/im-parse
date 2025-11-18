#!/bin/bash

# 设置 Rust 环境并安装 iOS 目标平台

set -e

echo "=== Rust 环境设置 ==="
echo ""

# 1. 添加 cargo/bin 到 PATH（如果还没有）
if ! echo "$PATH" | grep -q "\.cargo/bin"; then
    echo "添加 ~/.cargo/bin 到 PATH..."
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # 检查是否需要添加到 .zshrc
    if ! grep -q "\.cargo/bin" ~/.zshrc 2>/dev/null; then
        echo ""
        echo "检测到 ~/.zshrc 中缺少 cargo 路径"
        echo "是否要添加到 ~/.zshrc? (y/n)"
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
            echo "✓ 已添加到 ~/.zshrc"
            echo "  请运行: source ~/.zshrc"
        fi
    fi
else
    echo "✓ Cargo 已在 PATH 中"
fi

# 2. 检查 rustup
if ! command -v rustup &> /dev/null; then
    echo "错误: rustup 未找到"
    echo "请先安装 Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

echo "✓ rustup 可用: $(which rustup)"

# 检查是否有默认工具链
if ! rustup show default &> /dev/null; then
    echo "设置默认 Rust 工具链..."
    rustup default stable
fi

echo ""

# 3. 检查已安装的目标平台
echo "当前已安装的目标平台:"
rustup target list --installed | grep ios || echo "  无 iOS 目标平台"
echo ""

# 4. 安装 iOS 目标平台
ARCH=$(uname -m)
echo "检测到系统架构: $ARCH"
echo ""

echo "安装 iOS 目标平台..."

# iOS 设备（所有 Mac 都需要）
if ! rustup target list --installed | grep -q "aarch64-apple-ios"; then
    echo "  安装 aarch64-apple-ios (iOS 设备)..."
    rustup target add aarch64-apple-ios
else
    echo "  ✓ aarch64-apple-ios 已安装"
fi

# iOS 模拟器（根据架构选择）
if [ "$ARCH" = "arm64" ]; then
    # Apple Silicon Mac
    if ! rustup target list --installed | grep -q "aarch64-apple-ios-sim"; then
        echo "  安装 aarch64-apple-ios-sim (iOS 模拟器 - Apple Silicon)..."
        rustup target add aarch64-apple-ios-sim
    else
        echo "  ✓ aarch64-apple-ios-sim 已安装"
    fi
else
    # Intel Mac
    if ! rustup target list --installed | grep -q "x86_64-apple-ios"; then
        echo "  安装 x86_64-apple-ios (iOS 模拟器 - Intel)..."
        rustup target add x86_64-apple-ios
    else
        echo "  ✓ x86_64-apple-ios 已安装"
    fi
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "已安装的 iOS 目标平台:"
rustup target list --installed | grep ios
echo ""
echo "现在可以运行构建脚本: ./build.sh"

