#!/bin/bash

# 构建 Rust 核心库为 Android 可用的 .so 文件
# 使用方法: ./build-rust-lib.sh

set -e

# 临时禁用 set -e，以便在 cbindgen 失败时继续执行
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_CORE_DIR="$PROJECT_ROOT/rust-core"
SDK_LIB_DIR="$SCRIPT_DIR/IMParseSDK/src/main/jniLibs.backup"
BUILD_DIR="$SCRIPT_DIR/build"
HEADER_OUTPUT_DIR="$SCRIPT_DIR/IMParseSDK/src/main/cpp"
HEADER_FILE="$HEADER_OUTPUT_DIR/im_parse_core.h"

echo "🔨 开始构建 Rust 核心库为 Android .so 文件..."

cd "$RUST_CORE_DIR"

# 清理之前的构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$SDK_LIB_DIR"
mkdir -p "$HEADER_OUTPUT_DIR"

# 检查并安装 cbindgen（如果未安装）
CBINDGEN_CMD=""
if command -v cbindgen &> /dev/null; then
    CBINDGEN_CMD="cbindgen"
elif [ -f "$HOME/.cargo/bin/cbindgen" ]; then
    CBINDGEN_CMD="$HOME/.cargo/bin/cbindgen"
elif [ -f "$CARGO_HOME/bin/cbindgen" ]; then
    CBINDGEN_CMD="$CARGO_HOME/bin/cbindgen"
fi

if [ -z "$CBINDGEN_CMD" ]; then
    echo "📦 安装 cbindgen..."
    cargo install cbindgen --force
    INSTALL_RESULT=$?
    if [ $INSTALL_RESULT -eq 0 ]; then
        if [ -f "$HOME/.cargo/bin/cbindgen" ]; then
            CBINDGEN_CMD="$HOME/.cargo/bin/cbindgen"
        elif command -v cbindgen &> /dev/null; then
            CBINDGEN_CMD="cbindgen"
        fi
    else
        echo "   ⚠️  警告: cbindgen 安装失败，将跳过头文件生成"
    fi
fi

# 重新启用 set -e
set -e

# 生成 C 头文件
echo "📝 生成 C 头文件..."
if [ -n "$CBINDGEN_CMD" ] && [ -f "$RUST_CORE_DIR/cbindgen.toml" ]; then
    echo "   使用 cbindgen: $CBINDGEN_CMD"
    "$CBINDGEN_CMD" --config "$RUST_CORE_DIR/cbindgen.toml" --crate im-parse-core --output "$HEADER_FILE"
    if [ $? -eq 0 ] && [ -f "$HEADER_FILE" ]; then
        echo "   ✅ C 头文件已生成: $HEADER_FILE"
    else
        echo "   ⚠️  警告: cbindgen 生成头文件失败"
        echo "       JNI 代码将无法编译，请检查 cbindgen 配置"
    fi
else
    if [ -z "$CBINDGEN_CMD" ]; then
        echo "   ⚠️  警告: cbindgen 未安装或未找到"
    fi
    if [ ! -f "$RUST_CORE_DIR/cbindgen.toml" ]; then
        echo "   ⚠️  警告: 未找到 cbindgen.toml 配置文件"
    fi
    echo "   ⚠️  警告: 无法生成 C 头文件，JNI 代码可能无法编译"
fi

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

# 检查是否使用 cargo-ndk（可选，可以简化构建过程）
USE_CARGO_NDK=${USE_CARGO_NDK:-false}
CARGO_NDK_CMD=""
if [ "$USE_CARGO_NDK" = "true" ] || [ "$USE_CARGO_NDK" = "1" ]; then
    if command -v cargo-ndk &> /dev/null; then
        CARGO_NDK_CMD="cargo-ndk"
    elif [ -f "$HOME/.cargo/bin/cargo-ndk" ]; then
        CARGO_NDK_CMD="$HOME/.cargo/bin/cargo-ndk"
    elif [ -f "$CARGO_HOME/bin/cargo-ndk" ]; then
        CARGO_NDK_CMD="$CARGO_HOME/bin/cargo-ndk"
    else
        echo "📦 检测到 USE_CARGO_NDK=true，但未找到 cargo-ndk，正在安装..."
        cargo install cargo-ndk --force
        if [ $? -eq 0 ]; then
            if [ -f "$HOME/.cargo/bin/cargo-ndk" ]; then
                CARGO_NDK_CMD="$HOME/.cargo/bin/cargo-ndk"
            elif command -v cargo-ndk &> /dev/null; then
                CARGO_NDK_CMD="cargo-ndk"
            fi
        fi
    fi
    
    if [ -n "$CARGO_NDK_CMD" ]; then
        echo "   ✅ 使用 cargo-ndk 进行构建（简化模式）"
    else
        echo "   ⚠️  警告: cargo-ndk 安装失败，将使用手动配置模式"
        CARGO_NDK_CMD=""
    fi
fi

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
    # 如果使用 cargo-ndk，不需要手动配置链接器（cargo-ndk 会自动处理）
    # 如果使用手动模式，需要创建 .cargo/config.toml 配置文件
    if [ -z "$CARGO_NDK_CMD" ]; then
        # 手动配置模式：创建临时配置文件
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
    fi
    
    # 设置编译器和工具链路径
    case "$target" in
        aarch64-linux-android)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/aarch64-linux-android$NDK_API_LEVEL-clang"
            CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/aarch64-linux-android$NDK_API_LEVEL-clang++"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
        armv7-linux-androideabi)
            CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/armv7a-linux-androideabi$NDK_API_LEVEL-clang"
            CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/armv7a-linux-androideabi$NDK_API_LEVEL-clang++"
            AR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-ar"
            SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot"
            ;;
    esac
    
    # 编译 JNI 绑定代码
    JNI_CPP="$SCRIPT_DIR/IMParseSDK/src/main/cpp/im_parse_jni.cpp"
    JNI_OBJ="$BUILD_DIR/jni_${arch}.o"
    JNI_LIB="$BUILD_DIR/libjni_bridge_${arch}.a"
    
    # 注意：JNI 代码现在通过 CMake 构建（在 Gradle 构建时）
    # 此脚本仅用于构建纯 Rust 核心库
    # 如果需要构建包含 JNI 的完整库，请使用:
    #   cd Android-demo && ./gradlew :IMParseSDK:assembleDebug
    if [ -f "$JNI_CPP" ]; then
        echo "   ℹ️  跳过 JNI 编译（使用 CMake 构建）"
        echo "      如需构建完整 JNI 库，请运行: cd Android-demo && ./gradlew :IMParseSDK:assembleDebug"
        JNI_LIB=""
    else
        echo "   ⚠️  警告: 未找到 JNI 绑定代码: $JNI_CPP"
        JNI_LIB=""
    fi
    
    # 构建 Rust 库
    # 检查是否使用 JNI 特性（直接 JNI 支持，不需要 C++ 层）
    # 默认使用 JNI 模式（推荐，无需 C++ 层和 CMake）
    USE_JNI_FEATURE=${USE_JNI_FEATURE:-true}
    if [ "$USE_JNI_FEATURE" = "true" ] || [ "$USE_JNI_FEATURE" = "1" ]; then
        echo "   🔨 使用 JNI 特性构建（直接 JNI 支持，无需 C++ 层）..."
        
        # 确定 JNI 库路径
        case "$target" in
            aarch64-linux-android)
                JNI_LIB_ARCH="aarch64-linux-android"
                ;;
            armv7-linux-androideabi)
                JNI_LIB_ARCH="arm-linux-androideabi"
                ;;
            i686-linux-android)
                JNI_LIB_ARCH="i686-linux-android"
                ;;
            x86_64-linux-android)
                JNI_LIB_ARCH="x86_64-linux-android"
                ;;
        esac
        
        JNI_LIB_PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/sysroot/usr/lib/$JNI_LIB_ARCH/$NDK_API_LEVEL"
        
        if [ -n "$CARGO_NDK_CMD" ]; then
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=-L$JNI_LIB_PATH -C link-arg=-ljni" \
            "$CARGO_NDK_CMD" --target "$target" --android-platform "$NDK_API_LEVEL" build --release --features jni
        else
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=-L$JNI_LIB_PATH -C link-arg=-ljni" \
            cargo build --release --target "$target" --features jni
        fi
    elif [ -n "$CARGO_NDK_CMD" ]; then
        # 使用 cargo-ndk 构建（简化模式，但使用 FFI）
        echo "   🔨 使用 cargo-ndk 构建（FFI 模式）..."
        if [ -f "$JNI_LIB" ]; then
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=$JNI_LIB" \
            "$CARGO_NDK_CMD" --target "$target" --android-platform "$NDK_API_LEVEL" build --release
        else
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so" \
            "$CARGO_NDK_CMD" --target "$target" --android-platform "$NDK_API_LEVEL" build --release
        fi
    else
        # 使用手动配置模式（原有方式，FFI 模式）
        if [ -f "$JNI_LIB" ]; then
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so -C link-arg=$JNI_LIB" \
            cargo build --release --target "$target"
        else
            RUSTFLAGS="-C link-arg=-Wl,-soname,libim_parse_core.so" \
            cargo build --release --target "$target"
        fi
    fi
    
    # 恢复配置（如果备份存在，仅在手动模式下）
    if [ -z "$CARGO_NDK_CMD" ]; then
        if [ -f "$CARGO_CONFIG.backup" ]; then
            mv "$CARGO_CONFIG.backup" "$CARGO_CONFIG"
        else
            rm -f "$CARGO_CONFIG"
        fi
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

