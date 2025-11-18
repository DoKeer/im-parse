#!/bin/bash

# 修复 Rust 路径问题

echo "检查 Rust 安装..."

# 检查 cargo 是否在 PATH 中
if ! command -v cargo &> /dev/null; then
    echo "Cargo 未在 PATH 中，尝试添加到当前 shell..."
    
    # 检查 cargo env 文件是否存在
    if [ -f "$HOME/.cargo/env" ]; then
        echo "找到 ~/.cargo/env，正在加载..."
        source "$HOME/.cargo/env"
        
        if command -v cargo &> /dev/null; then
            echo "✓ Cargo 已加载"
        else
            echo "✗ 加载失败"
        fi
    else
        echo "未找到 ~/.cargo/env 文件"
        echo "请手动运行: source \$HOME/.cargo/env"
    fi
else
    echo "✓ Cargo 已在 PATH 中"
fi

# 检查 rustup
if command -v rustup &> /dev/null; then
    echo "✓ rustup 可用"
    echo ""
    echo "当前安装的目标平台:"
    rustup target list --installed
    echo ""
    echo "如果需要安装 iOS 目标平台，运行:"
    echo "  rustup target add aarch64-apple-ios"
    echo "  rustup target add x86_64-apple-ios  # Intel Mac"
    echo "  rustup target add aarch64-apple-ios-sim  # Apple Silicon Mac"
else
    echo "✗ rustup 不可用"
    echo ""
    echo "请手动添加到 PATH:"
    echo "  export PATH=\"\$HOME/.cargo/bin:\$PATH\""
    echo ""
    echo "或添加到 ~/.zshrc:"
    echo "  echo 'export PATH=\"\$HOME/.cargo/bin:\$PATH\"' >> ~/.zshrc"
    echo "  source ~/.zshrc"
fi

