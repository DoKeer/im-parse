#!/bin/bash

# 完整的 Android 开发构建脚本（使用模块依赖）
# 1. 构建 Rust 核心库
# 2. 构建 Demo 应用（直接依赖 IMParseSDK 模块，方便调试）
# 
# 使用方法: 
#   ./build-all.sh          # 开发模式（使用模块依赖）
#   ./build-all.sh clean    # 清理后构建
#
# 注意：如需构建 AAR 用于发布，请使用: ./build-aar.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# 步骤 1: 构建 Rust 核心库
build_rust_library() {
    log_step "步骤 1: 构建 Rust 核心库"
    
    cd "$ANDROID_DIR"
    
    log_info "使用 JNI 模式构建（直接 JNI 支持，无需 C++ 层）"
    export USE_JNI_FEATURE=true
    
    if ./build-rust-lib.sh; then
        log_success "Rust 核心库构建完成"
        
        # 验证生成的库文件
        local lib_count=0
        for arch in arm64-v8a armeabi-v7a; do
            local lib_path="$SDK_DIR/src/main/jniLibs/$arch/libim_parse_core.so"
            if [ -f "$lib_path" ]; then
                local size=$(du -h "$lib_path" | cut -f1)
                log_info "  $arch: $size"
                ((lib_count++))
            fi
        done
        
        if [ $lib_count -eq 2 ]; then
            log_success "所有架构的 Rust 库已生成"
        fi
    else
        log_error "Rust 库构建失败"
        exit 1
    fi
}

# 步骤 2: 验证模块依赖配置
verify_module_dependency() {
    log_step "步骤 2: 验证模块依赖配置"
    
    cd "$DEMO_DIR"
    
    # 检查 settings.gradle 是否包含 IMParseSDK
    if grep -q "^[^/]*include ':IMParseSDK'" settings.gradle; then
        log_success "settings.gradle 已配置 IMParseSDK 模块"
    else
        log_error "settings.gradle 中未找到 IMParseSDK 模块"
        log_info "请确保 settings.gradle 包含："
        log_info "  include ':IMParseSDK'"
        log_info "  project(':IMParseSDK').projectDir = new File('../IMParseSDK')"
        exit 1
    fi
    
    # 检查 app/build.gradle 是否使用模块依赖
    if grep -q "implementation project(':IMParseSDK')" app/build.gradle; then
        log_success "app/build.gradle 使用模块依赖（开发模式）"
    else
        log_warning "app/build.gradle 可能未使用模块依赖"
        log_info "请确保 dependencies 中包含：implementation project(':IMParseSDK')"
    fi
}

# 步骤 3: 构建 Demo 应用
build_demo_app() {
    log_step "步骤 3: 构建 Demo 应用（使用模块依赖）"
    
    cd "$DEMO_DIR"
    
    # 清理之前的构建（如果指定了 clean 参数）
    if [ "$1" == "clean" ]; then
        log_info "清理之前的构建..."
        ./gradlew clean :IMParseSDK:clean
    fi
    
    log_info "使用模块依赖构建 Demo 应用（方便调试 SDK）..."
    
    if ./gradlew :app:assembleDebug; then
        log_success "Demo 应用构建完成"
        
        local apk_path="$DEMO_DIR/app/build/outputs/apk/debug/app-debug.apk"
        if [ -f "$apk_path" ]; then
            local apk_size=$(du -h "$apk_path" | cut -f1)
            log_info "APK 位置: $apk_path"
            log_info "APK 大小: $apk_size"
            
            # 检查 APK 中的 native 库
            if unzip -l "$apk_path" 2>/dev/null | grep -q "lib/.*/libim_parse_core.so"; then
                log_success "APK 包含 libim_parse_core.so"
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
    echo -e "${GREEN}║     Android 开发构建脚本 (模块依赖模式)          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local clean_flag=""
    if [ "$1" == "clean" ]; then
        clean_flag="clean"
        log_info "将执行清理构建"
    fi
    
    log_info "开发模式：使用模块依赖，方便调试和修改 SDK"
    log_info "如需构建 AAR 用于发布，请运行: ./build-aar.sh"
    echo ""
    
    # 执行构建步骤
    build_rust_library
    verify_module_dependency
    build_demo_app "$clean_flag"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               🎉 构建完成！                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "所有构建步骤已完成"
    echo ""
    log_info "下一步："
    echo "  1. 安装: cd Android-demo && ./gradlew :app:installDebug"
    echo "  2. 运行: adb shell am start -n com.imparse.demo/.ui.MainActivity"
    echo ""
    log_info "💡 提示："
    echo "  - 修改 IMParseSDK 代码后，直接重新构建即可生效（无需重新构建 AAR）"
    echo "  - 如需发布 AAR，运行: ./build-aar.sh"
    echo ""
}

# 运行主函数
main "$@"
