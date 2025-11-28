#!/bin/bash

# 构建 Rust 核心库为 Android 可用的 .so 文件
# 使用方法: ./build-rust-lib.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_CORE_DIR="$PROJECT_ROOT/rust-core"
SDK_LIB_DIR="$SCRIPT_DIR/IMParseSDK/src/main/jniLibs"
BUILD_DIR="$SCRIPT_DIR/build"

echo "🔨 开始构建 Rust 核心库为 Android .so 文件..."

cd "$RUST_CORE_DIR"

# 清理之前的构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$SDK_LIB_DIR"

# Android 目标架构列表
ANDROID_TARGETS=(
    "aarch64-linux-android"      # arm64-v8a
    "armv7-linux-androideabi"    # armeabi-v7a
    "i686-linux-android"         # x86
    "x86_64-linux-android"       # x86_64
)

# 架构映射函数（兼容旧版 bash）
get_arch() {
    case "$1" in
        aarch64-linux-android) echo "arm64-v8a" ;;
        armv7-linux-androideabi) echo "armeabi-v7a" ;;
        i686-linux-android) echo "x86" ;;
        x86_64-linux-android) echo "x86_64" ;;
        *) echo "" ;;
    esac
}

# 检查并安装 Android 目标
echo "📱 检查 Android 目标..."
for target in "${ANDROID_TARGETS[@]}"; do
    if ! rustup target list --installed | grep -q "^$target$"; then
        echo "   安装目标: $target"
        rustup target add "$target"
    fi
done

# 设置 NDK 路径（如果未设置）
if [ -z "$ANDROID_NDK_HOME" ]; then
    # 尝试从常见位置查找 NDK
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        NDK_VERSION=$(ls -1 "$HOME/Library/Android/sdk/ndk" | head -1)
        ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/$NDK_VERSION"
    elif [ -d "$HOME/Android/Sdk/ndk" ]; then
        NDK_VERSION=$(ls -1 "$HOME/Android/Sdk/ndk" | head -1)
        ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$NDK_VERSION"
    else
        echo "❌ 错误: 未找到 Android NDK"
        echo "   请设置 ANDROID_NDK_HOME 环境变量，或安装 NDK 到默认位置"
        exit 1
    fi
fi

echo "   使用 NDK: $ANDROID_NDK_HOME"

# 获取 NDK API 级别（默认使用 21，支持 Android 5.0+）
NDK_API_LEVEL=${NDK_API_LEVEL:-21}

echo "   使用 API 级别: $NDK_API_LEVEL"

# 构建每个架构
for target in "${ANDROID_TARGETS[@]}"; do
    arch=$(get_arch "$target")
    echo ""
    echo "📱 构建 $target ($arch)..."
    
    # 设置链接器
    case "$target" in
        aarch64-linux-android)
            LINKER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/aarch64-linux-android$NDK_API_LEVEL-clang"
            ;;
        armv7-linux-androideabi)
            LINKER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/armv7a-linux-androideabi$NDK_API_LEVEL-clang"
            ;;
        i686-linux-android)
            LINKER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/i686-linux-android$NDK_API_LEVEL-clang"
            ;;
        x86_64-linux-android)
            LINKER="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/x86_64-linux-android$NDK_API_LEVEL-clang"
            ;;
    esac
    
    # 构建
    # 在 rust-core 目录创建临时配置文件
    CARGO_CONFIG_DIR="$RUST_CORE_DIR/.cargo"
    mkdir -p "$CARGO_CONFIG_DIR"
    CARGO_CONFIG="$CARGO_CONFIG_DIR/config.toml"
    
    # 备份现有配置（如果存在）
    if [ -f "$CARGO_CONFIG" ]; then
        cp "$CARGO_CONFIG" "$CARGO_CONFIG.backup"
    fi
    
    # 创建或更新配置文件
    if [ -f "$CARGO_CONFIG" ]; then
        # 如果文件存在，检查是否已有该目标的配置
        if ! grep -q "\[target.$target\]" "$CARGO_CONFIG"; then
            cat >> "$CARGO_CONFIG" <<EOF

[target.$target]
linker = "$LINKER"
EOF
        else
            # 如果已有配置，更新 linker
            sed -i.bak "s|linker = \".*\"|linker = \"$LINKER\"|" "$CARGO_CONFIG"
        fi
    else
        # 创建新配置文件
        cat > "$CARGO_CONFIG" <<EOF
[target.$target]
linker = "$LINKER"
EOF
    fi
    
    # 设置编译器和工具链路径
    case "$target" in
        aarch64-linux-android)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/aarch64-linux-android$NDK_API_LEVEL-clang"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
        armv7-linux-androideabi)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/armv7a-linux-androideabi$NDK_API_LEVEL-clang"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
        i686-linux-android)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/i686-linux-android$NDK_API_LEVEL-clang"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
        x86_64-linux-android)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/x86_64-linux-android$NDK_API_LEVEL-clang"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
    esac
    
    # 编译 JNI 绑定代码
    JNI_CPP="$SCRIPT_DIR/IMParseSDK/src/main/cpp/im_parse_jni.cpp"
    JNI_OBJ="$BUILD_DIR/jni_${arch}.o"
    JNI_LIB="$BUILD_DIR/libjni_bridge_${arch}.a"
    
    if [ -f "$JNI_CPP" ]; then
        echo "   🔨 编译 JNI 绑定代码..."
        
        # 确定架构特定的包含路径和目标
        case "$target" in
            aarch64-linux-android)
                TARGET_ARCH="aarch64-linux-android"
                TARGET_TRIPLE="aarch64-linux-android"
                ;;
            armv7-linux-androideabi)
                TARGET_ARCH="arm-linux-androideabi"
                TARGET_TRIPLE="armv7-linux-androideabi"
                ;;
            i686-linux-android)
                TARGET_ARCH="i686-linux-android"
                TARGET_TRIPLE="i686-linux-android"
                ;;
            x86_64-linux-android)
                TARGET_ARCH="x86_64-linux-android"
                TARGET_TRIPLE="x86_64-linux-android"
                ;;
        esac
        
        $CC \
            -c "$JNI_CPP" \
            -o "$JNI_OBJ" \
            -I"$ANDROID_NDK_HOME/sysroot/usr/include" \
            -I"$ANDROID_NDK_HOME/sysroot/usr/include/$TARGET_ARCH" \
            -I"$ANDROID_NDK_HOME/sources/cxx-stl/llvm-libc++/include" \
            -I"$ANDROID_NDK_HOME/sources/cxx-stl/llvm-libc++/../llvm-libc++abi/include" \
            -I"$ANDROID_NDK_HOME/sources/android/support/include" \
            -std=c++17 \
            -fPIC \
            -O2 \
            --sysroot="$SYSROOT" \
            --target=${TARGET_TRIPLE}${NDK_API_LEVEL}
        
        if [ -f "$JNI_OBJ" ]; then
            echo "   📦 创建静态库..."
            $AR rcs "$JNI_LIB" "$JNI_OBJ"
            echo "   ✅ JNI 绑定代码编译完成"
        else
            echo "   ⚠️  警告: JNI 对象文件编译失败"
        fi
    else
        echo "   ⚠️  警告: 未找到 JNI 绑定代码: $JNI_CPP"
    fi
    
    # 构建 Rust 库（如果存在 JNI 库，则链接它）
    if [ -f "$JNI_LIB" ]; then
        RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=$JNI_LIB" \
        cargo build --release --target "$target"
    else
        RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so" \
        cargo build --release --target "$target"
    fi
    
    # 恢复配置（如果备份存在）
    if [ -f "$CARGO_CONFIG.backup" ]; then
        mv "$CARGO_CONFIG.backup" "$CARGO_CONFIG"
    else
        rm -f "$CARGO_CONFIG"
    fi
    
    # 如果 Rust 库构建成功，但需要链接 JNI 代码，需要重新链接
    SOURCE_LIB="$RUST_CORE_DIR/target/$target/release/libim_parse_core.so"
    
    if [ -f "$SOURCE_LIB" ] && [ -f "$JNI_LIB" ]; then
        echo "   🔗 链接 JNI 绑定代码..."
        TEMP_LIB="$BUILD_DIR/libim_parse_core_${arch}.so"
        
        # 确定架构特定的库路径
        case "$target" in
            aarch64-linux-android)
                LIB_ARCH="aarch64-linux-android"
                ;;
            armv7-linux-androideabi)
                LIB_ARCH="arm-linux-androideabi"
                ;;
            i686-linux-android)
                LIB_ARCH="i686-linux-android"
                ;;
            x86_64-linux-android)
                LIB_ARCH="x86_64-linux-android"
                ;;
        esac
        
        # 使用链接器重新链接，包含 JNI 库
        $LINKER \
            -shared \
            -o "$TEMP_LIB" \
            -Wl,--whole-archive "$SOURCE_LIB" "$JNI_LIB" -Wl,--no-whole-archive \
            -Wl,-soname,libim_parse_core.so \
            -llog \
            -landroid \
            -latomic \
            -lc++ \
            -L"$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot/usr/lib/$LIB_ARCH/$NDK_API_LEVEL"
        
        if [ -f "$TEMP_LIB" ]; then
            SOURCE_LIB="$TEMP_LIB"
            echo "   ✅ JNI 绑定代码已链接"
        else
            echo "   ⚠️  警告: 重新链接失败，使用原始库"
        fi
    fi
    
    # 复制 .so 文件到对应目录
    DEST_DIR="$SDK_LIB_DIR/$arch"
    
    if [ -f "$SOURCE_LIB" ]; then
        mkdir -p "$DEST_DIR"
        cp "$SOURCE_LIB" "$DEST_DIR/libim_parse_core.so"
        echo "   ✅ 已复制到: $DEST_DIR/libim_parse_core.so"
        
        # 显示文件信息
        file "$DEST_DIR/libim_parse_core.so" | head -1
    else
        echo "   ⚠️  警告: 未找到 $SOURCE_LIB"
    fi
done

echo ""
echo "✨ 构建完成！"
echo "📁 .so 文件位置: $SDK_LIB_DIR"
echo ""
echo "📊 构建结果:"
for target in "${ANDROID_TARGETS[@]}"; do
    arch=$(get_arch "$target")
    lib_path="$SDK_LIB_DIR/$arch/libim_parse_core.so"
    if [ -f "$lib_path" ]; then
        size=$(du -h "$lib_path" | cut -f1)
        echo "   ✅ $arch: $size"
    else
        echo "   ❌ $arch: 未找到"
    fi
done

