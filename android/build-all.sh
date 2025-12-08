#!/bin/bash

# 完整的 Android 构建脚本
# 1. 构建 Rust 核心库
# 2. 使用 CMake/Gradle 构建完整 JNI 库
# 3. 更新 Android-demo 依赖
# 使用方法: ./build-all.sh [clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_CORE_DIR="$PROJECT_ROOT/rust-core"
ANDROID_DIR="$SCRIPT_DIR"
SDK_DIR="$ANDROID_DIR/IMParseSDK"
DEMO_DIR="$ANDROID_DIR/Android-demo"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 检查必要工具
check_requirements() {
    log_step "检查构建环境"
    
    local missing_tools=()
    
    # 检查 Rust
    if ! command -v rustc &> /dev/null; then
        missing_tools+=("rustc (Rust)")
    else
        log_info "Rust: $(rustc --version)"
    fi
    
    # 检查 Cargo
    if ! command -v cargo &> /dev/null; then
        missing_tools+=("cargo")
    else
        log_info "Cargo: $(cargo --version)"
    fi
    
    # 检查 Gradle
    if ! command -v "$DEMO_DIR/gradlew" &> /dev/null && ! command -v gradle &> /dev/null; then
        missing_tools+=("gradle 或 gradlew")
    else
        if [ -f "$DEMO_DIR/gradlew" ]; then
            log_info "Gradle: 使用项目 gradlew"
        else
            log_info "Gradle: $(gradle --version | head -1)"
        fi
    fi
    
    # 检查 Android NDK
    if [ -z "$ANDROID_NDK_HOME" ]; then
        if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
            NDK_VERSION=$(ls -1 "$HOME/Library/Android/sdk/ndk" | head -1)
            export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/$NDK_VERSION"
            log_info "Android NDK: $ANDROID_NDK_HOME (自动检测)"
        elif [ -d "$HOME/Android/Sdk/ndk" ]; then
            NDK_VERSION=$(ls -1 "$HOME/Android/Sdk/ndk" | head -1)
            export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$NDK_VERSION"
            log_info "Android NDK: $ANDROID_NDK_HOME (自动检测)"
        else
            missing_tools+=("Android NDK (设置 ANDROID_NDK_HOME)")
        fi
    else
        log_info "Android NDK: $ANDROID_NDK_HOME"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必要工具:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 步骤 1: 构建 Rust 核心库
build_rust_library() {
    log_step "步骤 1: 构建 Rust 核心库"
    
    if [ ! -f "$ANDROID_DIR/build-rust-lib.sh" ]; then
        log_error "未找到 build-rust-lib.sh"
        exit 1
    fi
    
    cd "$ANDROID_DIR"
    
    # 检查是否使用 JNI 模式
    # 默认使用 JNI 模式（推荐，无需 C++ 层和 CMake）
    local use_jni=${USE_JNI_FEATURE:-true}
    if [ "$use_jni" = "true" ] || [ "$use_jni" = "1" ]; then
        log_info "使用 JNI 模式构建（直接 JNI 支持，无需 C++ 层）（默认）..."
        export USE_JNI_FEATURE=true
    else
        log_info "使用 FFI 模式构建（需要 C++ JNI 层）..."
    fi
    
    log_info "执行 Rust 库构建..."
    if ./build-rust-lib.sh; then
        log_success "Rust 核心库构建完成"
        
        # 验证生成的库文件
        local lib_count=0
        for arch in arm64-v8a armeabi-v7a; do
            local lib_path="$SDK_DIR/src/main/jniLibs.backup/$arch/libim_parse_core.so"
            if [ -f "$lib_path" ]; then
                local size=$(du -h "$lib_path" | cut -f1)
                log_info "  $arch: $size"
                ((lib_count++))
            else
                log_warning "  $arch: 库文件不存在 ($lib_path)"
            fi
        done
        
        if [ $lib_count -eq 4 ]; then
            log_success "所有架构的 Rust 库已生成"
        else
            log_warning "部分架构的库可能缺失 ($lib_count/4)"
        fi
    else
        log_error "Rust 库构建失败"
        exit 1
    fi
}

# 步骤 2: 使用 CMake/Gradle 构建完整 JNI 库（仅在 FFI 模式下需要）
build_jni_library() {
    # 默认使用 JNI 模式（推荐，无需 C++ 层和 CMake）
    local use_jni=${USE_JNI_FEATURE:-true}
    
    # 如果使用 JNI 模式，跳过 CMake 构建
    if [ "$use_jni" = "true" ] || [ "$use_jni" = "1" ]; then
        log_step "步骤 2: 跳过 CMake 构建（JNI 模式，无需 C++ 层）"
        log_info "JNI 模式：Rust 库已包含所有 JNI 函数，无需额外构建"
        return 0
    fi
    
    log_step "步骤 2: 构建完整 JNI 库 (CMake + Gradle)"
    
    cd "$DEMO_DIR"
    
    # 清理之前的构建（如果指定了 clean 参数）
    if [ "$1" == "clean" ]; then
        log_info "清理之前的构建..."
        ./gradlew clean
    fi
    
    log_info "构建 IMParseSDK (包含 JNI 包装层)..."
    
    # 构建 SDK
    if ./gradlew :IMParseSDK:assembleDebug :IMParseSDK:assembleRelease; then
        log_success "IMParseSDK 构建完成"
        
        # 验证生成的库
        local debug_lib="$SDK_DIR/build/intermediates/cxx/Debug"
        local release_lib="$SDK_DIR/build/intermediates/cxx/Release"
        
        if [ -d "$debug_lib" ] || [ -d "$release_lib" ]; then
            log_info "检查生成的 JNI 库..."
            
            # 检查 Debug 库
            for arch in arm64-v8a armeabi-v7a; do
                local lib_path=$(find "$debug_lib" -name "libim_parse_core.so" -path "*/$arch/*" 2>/dev/null | head -1)
                if [ -n "$lib_path" ]; then
                    # 检查是否包含 JNI 符号
                    if nm -D "$lib_path" 2>/dev/null | grep -q "Java_com_imparse_core_IMParseCore"; then
                        log_success "  Debug $arch: 包含 JNI 符号"
                    else
                        log_warning "  Debug $arch: JNI 符号可能被剥离"
                    fi
                fi
            done
        fi
    else
        log_error "IMParseSDK 构建失败"
        exit 1
    fi
}

# 步骤 3: 验证和更新依赖
verify_and_update_dependencies() {
    log_step "步骤 3: 验证依赖配置"
    
    cd "$DEMO_DIR"
    
    # 检查 settings.gradle
    if grep -q "IMParseSDK" "$DEMO_DIR/settings.gradle"; then
        log_success "settings.gradle 已包含 IMParseSDK 模块"
    else
        log_warning "settings.gradle 中未找到 IMParseSDK，正在添加..."
        if ! grep -q "include ':IMParseSDK'" "$DEMO_DIR/settings.gradle"; then
            echo "" >> "$DEMO_DIR/settings.gradle"
            echo "include ':IMParseSDK'" >> "$DEMO_DIR/settings.gradle"
            echo "project(':IMParseSDK').projectDir = new File('../IMParseSDK')" >> "$DEMO_DIR/settings.gradle"
            log_success "已添加 IMParseSDK 到 settings.gradle"
        fi
    fi
    
    # 检查 app/build.gradle
    if grep -q "implementation project(':IMParseSDK')" "$DEMO_DIR/app/build.gradle"; then
        log_success "app/build.gradle 已包含 IMParseSDK 依赖"
    else
        log_warning "app/build.gradle 中未找到 IMParseSDK 依赖，正在添加..."
        if ! grep -q "dependencies" "$DEMO_DIR/app/build.gradle"; then
            echo "" >> "$DEMO_DIR/app/build.gradle"
            echo "dependencies {" >> "$DEMO_DIR/app/build.gradle"
            echo "    implementation project(':IMParseSDK')" >> "$DEMO_DIR/app/build.gradle"
            echo "}" >> "$DEMO_DIR/app/build.gradle"
        else
            # 在 dependencies 块中添加
            sed -i.bak '/dependencies {/a\
    implementation project('\'':IMParseSDK'\'')
' "$DEMO_DIR/app/build.gradle"
        fi
        log_success "已添加 IMParseSDK 依赖到 app/build.gradle"
    fi
    
    # 同步 Gradle
    log_info "同步 Gradle 项目..."
    if ./gradlew tasks --no-daemon > /dev/null 2>&1; then
        log_success "Gradle 项目同步成功"
    else
        log_warning "Gradle 同步时出现警告（可能正常）"
    fi
}

# 步骤 4: 构建 Demo 应用
build_demo_app() {
    log_step "步骤 4: 构建 Demo 应用"
    
    cd "$DEMO_DIR"
    
    log_info "构建 Android Demo 应用..."
    
    if ./gradlew :app:assembleDebug; then
        log_success "Demo 应用构建完成"
        
        # 显示 APK 信息
        local apk_path="$DEMO_DIR/app/build/outputs/apk/debug/app-debug.apk"
        if [ -f "$apk_path" ]; then
            local apk_size=$(du -h "$apk_path" | cut -f1)
            log_info "APK 位置: $apk_path"
            log_info "APK 大小: $apk_size"
            
            # 检查 APK 中的 native 库
            log_info "检查 APK 中的 native 库..."
            if unzip -l "$apk_path" 2>/dev/null | grep -q "lib/.*/libim_parse_core.so"; then
                log_success "APK 包含 libim_parse_core.so"
                unzip -l "$apk_path" 2>/dev/null | grep "lib/.*/libim_parse_core.so" | while read line; do
                    log_info "  $line"
                done
            else
                log_warning "APK 中未找到 libim_parse_core.so"
            fi
        fi
    else
        log_error "Demo 应用构建失败"
        exit 1
    fi
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Android 完整构建脚本 (Rust + JNI + Gradle)    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local clean_flag=""
    if [ "$1" == "clean" ]; then
        clean_flag="clean"
        log_info "将执行清理构建"
    fi
    
    # 检查是否使用 JNI 模式
    # 默认使用 JNI 模式（推荐，无需 C++ 层和 CMake）
    local use_jni=${USE_JNI_FEATURE:-true}
    if [ "$use_jni" = "true" ] || [ "$use_jni" = "1" ]; then
        export USE_JNI_FEATURE=true
        log_info "使用 JNI 模式：直接在 Rust 中实现 JNI，无需 C++ 层和 CMake（默认）"
    else
        export USE_JNI_FEATURE=false
        log_info "使用 FFI 模式：Rust FFI + C++ JNI 层 + CMake"
    fi
    
    # 执行构建步骤
    check_requirements
    build_rust_library
    build_jni_library "$clean_flag"
    verify_and_update_dependencies
    build_demo_app
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               🎉 构建完成！                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "所有构建步骤已完成"
    echo ""
    log_info "下一步："
    echo "  1. 安装到设备: cd Android-demo && ./gradlew :app:installDebug"
    echo "  2. 运行应用: adb shell am start -n com.imparse.demo/.MainActivity"
    echo ""
}

# 运行主函数
main "$@"

