#!/bin/bash

# 构建 Rust 核心库并创建 XCFramework
# 使用方法: ./build-rust-lib.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUST_CORE_DIR="$PROJECT_ROOT/rust-core"
SDK_LIB_DIR="$SCRIPT_DIR/IMParseSDK/Libraries"
BUILD_DIR="$SCRIPT_DIR/build"
XCFRAMEWORK_NAME="im_parse_core"
XCFRAMEWORK_OUTPUT="$SDK_LIB_DIR/${XCFRAMEWORK_NAME}.xcframework"

echo "🔨 开始构建 Rust 核心库..."

cd "$RUST_CORE_DIR"

# 清理之前的构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$SDK_LIB_DIR"

# 构建 iOS 设备版本 (arm64)
echo "📱 构建 iOS 设备版本 (arm64)..."
cargo build --release --target aarch64-apple-ios

# 构建 iOS 模拟器版本 (arm64)
echo "📱 构建 iOS 模拟器版本 (arm64)..."
cargo build --release --target aarch64-apple-ios-sim

# 构建 iOS 模拟器版本 (x86_64) - 如果需要支持 Intel Mac
HAS_X86_64=false
if [ -d "$HOME/.rustup/toolchains" ]; then
    echo "📱 构建 iOS 模拟器版本 (x86_64)..."
    if cargo build --release --target x86_64-apple-ios 2>/dev/null; then
        HAS_X86_64=true
        echo "✅ x86_64 构建成功"
    else
        echo "⚠️  x86_64 目标未安装，跳过"
    fi
fi

echo "📦 创建 Framework 和 XCFramework..."

# 创建临时目录用于构建 frameworks
TEMP_FRAMEWORKS_DIR="$BUILD_DIR/frameworks"
mkdir -p "$TEMP_FRAMEWORKS_DIR"

# 函数：从静态库创建 Framework
create_framework() {
    local target=$1
    local platform=$2
    local variant=$3
    local static_lib="$RUST_CORE_DIR/target/$target/release/libim_parse_core.a"
    
    if [ ! -f "$static_lib" ]; then
        echo "⚠️  警告: 未找到 $static_lib，跳过"
        return 1
    fi
    
    local framework_name="${XCFRAMEWORK_NAME}.framework"
    local framework_dir="$TEMP_FRAMEWORKS_DIR/$platform${variant:+-$variant}/$framework_name"
    local framework_binary="$framework_dir/$XCFRAMEWORK_NAME"
    
    # 创建 framework 目录结构
    mkdir -p "$framework_dir/Headers"
    
    # 复制静态库作为 framework 的二进制文件
    cp "$static_lib" "$framework_binary"
    
    # 创建 Headers 目录（如果需要头文件，可以在这里添加）
    # 目前 Rust FFI 通过 C 头文件访问，不需要在这里添加
    
    # 创建 Info.plist
    cat > "$framework_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${XCFRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.imparse.${XCFRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${XCFRAMEWORK_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF
    
    # 创建 Modules 目录和 module.modulemap（如果需要）
    mkdir -p "$framework_dir/Modules"
    cat > "$framework_dir/Modules/module.modulemap" <<EOF
framework module ${XCFRAMEWORK_NAME} {
    umbrella header "${XCFRAMEWORK_NAME}.h"
    export *
    module * { export * }
}
EOF
    
    # 创建空的 umbrella header（如果需要）
    touch "$framework_dir/Headers/${XCFRAMEWORK_NAME}.h"
    
    echo "✅ 已创建 Framework: $framework_dir"
    return 0
}

# 创建各个平台的 Framework
echo "📱 创建 iOS 真机 Framework (arm64)..."
create_framework "aarch64-apple-ios" "ios" "arm64"

# 创建模拟器 Framework（需要合并 arm64 和 x86_64）
echo "📱 创建 iOS 模拟器 Framework..."

# 先创建临时 Framework
SIM_ARM64_FRAMEWORK=""
SIM_X86_64_FRAMEWORK=""

if [ -f "$RUST_CORE_DIR/target/aarch64-apple-ios-sim/release/libim_parse_core.a" ]; then
    create_framework "aarch64-apple-ios-sim" "ios" "simulator-temp-arm64"
    SIM_ARM64_FRAMEWORK="$TEMP_FRAMEWORKS_DIR/ios-simulator-temp-arm64/${XCFRAMEWORK_NAME}.framework/${XCFRAMEWORK_NAME}"
fi

if [ "$HAS_X86_64" = true ] && [ -f "$RUST_CORE_DIR/target/x86_64-apple-ios/release/libim_parse_core.a" ]; then
    create_framework "x86_64-apple-ios" "ios" "simulator-temp-x86_64"
    SIM_X86_64_FRAMEWORK="$TEMP_FRAMEWORKS_DIR/ios-simulator-temp-x86_64/${XCFRAMEWORK_NAME}.framework/${XCFRAMEWORK_NAME}"
fi

# 合并模拟器 Framework（如果有多个架构）
SIM_FRAMEWORK_DIR="$TEMP_FRAMEWORKS_DIR/ios-simulator/${XCFRAMEWORK_NAME}.framework"
mkdir -p "$SIM_FRAMEWORK_DIR/Headers"
mkdir -p "$SIM_FRAMEWORK_DIR/Modules"

if [ -n "$SIM_ARM64_FRAMEWORK" ] && [ -n "$SIM_X86_64_FRAMEWORK" ]; then
    # 合并 arm64 和 x86_64 模拟器
    echo "   🔗 合并 arm64 和 x86_64 模拟器架构..."
    lipo -create \
        "$SIM_ARM64_FRAMEWORK" \
        "$SIM_X86_64_FRAMEWORK" \
        -output "$SIM_FRAMEWORK_DIR/${XCFRAMEWORK_NAME}"
    echo "   ✅ 已合并模拟器架构（arm64 + x86_64）"
elif [ -n "$SIM_ARM64_FRAMEWORK" ]; then
    # 只有 arm64 模拟器
    cp "$SIM_ARM64_FRAMEWORK" "$SIM_FRAMEWORK_DIR/${XCFRAMEWORK_NAME}"
    echo "   ✅ 使用 arm64 模拟器"
elif [ -n "$SIM_X86_64_FRAMEWORK" ]; then
    # 只有 x86_64 模拟器
    cp "$SIM_X86_64_FRAMEWORK" "$SIM_FRAMEWORK_DIR/${XCFRAMEWORK_NAME}"
    echo "   ✅ 使用 x86_64 模拟器"
else
    echo "   ⚠️  警告: 没有找到任何模拟器库"
fi

# 复制 Framework 元数据（从第一个模拟器 Framework）
if [ -n "$SIM_ARM64_FRAMEWORK" ]; then
    TEMP_SIM_FRAMEWORK_DIR="$TEMP_FRAMEWORKS_DIR/ios-simulator-temp-arm64/${XCFRAMEWORK_NAME}.framework"
    cp "$TEMP_SIM_FRAMEWORK_DIR/Info.plist" "$SIM_FRAMEWORK_DIR/Info.plist"
    cp "$TEMP_SIM_FRAMEWORK_DIR/Modules/module.modulemap" "$SIM_FRAMEWORK_DIR/Modules/module.modulemap" 2>/dev/null || true
    touch "$SIM_FRAMEWORK_DIR/Headers/${XCFRAMEWORK_NAME}.h"
elif [ -n "$SIM_X86_64_FRAMEWORK" ]; then
    TEMP_SIM_FRAMEWORK_DIR="$TEMP_FRAMEWORKS_DIR/ios-simulator-temp-x86_64/${XCFRAMEWORK_NAME}.framework"
    cp "$TEMP_SIM_FRAMEWORK_DIR/Info.plist" "$SIM_FRAMEWORK_DIR/Info.plist"
    cp "$TEMP_SIM_FRAMEWORK_DIR/Modules/module.modulemap" "$SIM_FRAMEWORK_DIR/Modules/module.modulemap" 2>/dev/null || true
    touch "$SIM_FRAMEWORK_DIR/Headers/${XCFRAMEWORK_NAME}.h"
fi

# 使用 xcodebuild 创建 XCFramework
echo "🔗 创建 XCFramework..."

# 构建 xcodebuild 命令
XCODEBUILD_ARGS=()

# iOS 真机
if [ -d "$TEMP_FRAMEWORKS_DIR/ios-arm64/${XCFRAMEWORK_NAME}.framework" ]; then
    XCODEBUILD_ARGS+=(-framework "$TEMP_FRAMEWORKS_DIR/ios-arm64/${XCFRAMEWORK_NAME}.framework")
fi

# iOS 模拟器（合并后的）
if [ -d "$SIM_FRAMEWORK_DIR" ] && [ -f "$SIM_FRAMEWORK_DIR/${XCFRAMEWORK_NAME}" ]; then
    XCODEBUILD_ARGS+=(-framework "$SIM_FRAMEWORK_DIR")
fi

# 检查是否有足够的 frameworks
if [ ${#XCODEBUILD_ARGS[@]} -eq 0 ]; then
    echo "❌ 错误: 没有找到任何 framework"
    exit 1
fi

# 删除旧的 XCFramework
rm -rf "$XCFRAMEWORK_OUTPUT"

# 创建 XCFramework
xcodebuild -create-xcframework \
    "${XCODEBUILD_ARGS[@]}" \
    -output "$XCFRAMEWORK_OUTPUT"

if [ $? -eq 0 ]; then
    echo "✅ 已创建 XCFramework: $XCFRAMEWORK_OUTPUT"
    
    # 显示 XCFramework 信息
    echo ""
    echo "📊 XCFramework 信息:"
    echo "   包含的平台:"
    for platform_dir in "$XCFRAMEWORK_OUTPUT"/*; do
        if [ -d "$platform_dir" ]; then
            framework_path="$platform_dir/${XCFRAMEWORK_NAME}.framework/${XCFRAMEWORK_NAME}"
            if [ -f "$framework_path" ]; then
                arch_info=$(file "$framework_path" 2>/dev/null | grep -o 'architecture: [^,]*' || echo 'unknown')
                echo "   - $(basename "$platform_dir"): $arch_info"
            else
                echo "   - $(basename "$platform_dir"): framework found"
            fi
        fi
    done
else
    echo "❌ 错误: 创建 XCFramework 失败"
    exit 1
fi

# 清理临时文件
rm -rf "$BUILD_DIR"

echo ""
echo "✨ 构建完成！"
echo "📁 XCFramework 位置: $XCFRAMEWORK_OUTPUT"
echo "💡 现在可以在 podspec 中使用此 XCFramework"
