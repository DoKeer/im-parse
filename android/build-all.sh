#!/bin/bash

# 完整的 Android 构建脚本
# 1. 构建 Rust 核心库
# 2. 构建 IMParseSDK AAR
# 3. 构建 Demo 应用
# 使用方法: ./build-all.sh [clean]

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

# 步骤 2: 构建 IMParseSDK AAR
build_sdk_aar() {
    log_step "步骤 2: 构建 IMParseSDK AAR"
    
    local settings_file="$DEMO_DIR/settings.gradle"
    local has_sdk_module=false
    
    # 检查是否已有 IMParseSDK 模块配置
    if ! grep -q "^[^/]*include ':IMParseSDK'" "$settings_file"; then
        # 临时添加模块
        echo "" >> "$settings_file"
        echo "include ':IMParseSDK'" >> "$settings_file"
        echo "project(':IMParseSDK').projectDir = new File('../IMParseSDK')" >> "$settings_file"
        log_info "已临时添加 IMParseSDK 模块"
        has_sdk_module=true
    fi
    
    cd "$DEMO_DIR"
    
    # 清理之前的构建（如果指定了 clean 参数）
    if [ "$1" == "clean" ]; then
        log_info "清理之前的构建..."
        ./gradlew clean :IMParseSDK:clean
    fi
    
    log_info "构建 IMParseSDK AAR..."
    
    if ./gradlew :IMParseSDK:assembleDebug; then
        log_success "IMParseSDK AAR 构建完成"
        
        # 复制 AAR 到 app/libs
        local aar_debug="$SDK_DIR/build/outputs/aar/IMParseSDK-debug.aar"
        local app_libs_dir="$DEMO_DIR/app/libs"
        
        mkdir -p "$app_libs_dir"
        
        if [ -f "$aar_debug" ]; then
            cp "$aar_debug" "$app_libs_dir/"
            local size=$(du -h "$aar_debug" | cut -f1)
            log_success "Debug AAR 已复制到 app/libs ($size)"
            
            # 验证 AAR 是否包含 .so 文件
            if unzip -l "$aar_debug" 2>/dev/null | grep -q "jni/.*/libim_parse_core.so"; then
                log_success "AAR 包含 native 库"
            else
                log_warning "AAR 中未找到 native 库"
            fi
        fi
    else
        log_error "IMParseSDK AAR 构建失败"
        exit 1
    fi
    
    # 恢复 settings.gradle
    if [ "$has_sdk_module" = true ]; then
        # 移除最后 3 行（空行 + 两行 IMParseSDK 配置）
        # 使用兼容 macOS 的方式
        local total_lines=$(wc -l < "$settings_file" | tr -d ' ')
        local keep_lines=$((total_lines - 3))
        head -n "$keep_lines" "$settings_file" > "$settings_file.tmp"
        mv "$settings_file.tmp" "$settings_file"
        log_info "已恢复 settings.gradle"
    fi
}

# 步骤 3: 构建 Demo 应用
build_demo_app() {
    log_step "步骤 3: 构建 Demo 应用"
    
    cd "$DEMO_DIR"
    
    log_info "使用 AAR 依赖构建 Demo 应用..."
    
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
    echo -e "${GREEN}║        Android 构建脚本 (Rust + JNI + AAR)        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local clean_flag=""
    if [ "$1" == "clean" ]; then
        clean_flag="clean"
        log_info "将执行清理构建"
    fi
    
    # 执行构建步骤
    build_rust_library
    build_sdk_aar "$clean_flag"
    build_demo_app
    
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
}

# 运行主函数
main "$@"
