#!/bin/bash

# 构建 IMParseSDK AAR 用于发布
# 使用方法: ./build-aar.sh [debug|release]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$SCRIPT_DIR/Android-demo"
SDK_DIR="$SCRIPT_DIR/IMParseSDK"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BUILD_TYPE=${1:-debug}

echo -e "${BLUE}📦 构建 IMParseSDK AAR (${BUILD_TYPE})...${NC}"

# 确保 settings.gradle 包含 IMParseSDK 模块（用于构建）
cd "$DEMO_DIR"

# 检查是否已包含模块
if ! grep -q "^[^/]*include ':IMParseSDK'" settings.gradle; then
    echo -e "${YELLOW}⚠️  临时添加 IMParseSDK 模块到 settings.gradle${NC}"
    echo "" >> settings.gradle
    echo "include ':IMParseSDK'" >> settings.gradle
    echo "project(':IMParseSDK').projectDir = new File('../IMParseSDK')" >> settings.gradle
    TEMP_ADDED=true
else
    TEMP_ADDED=false
fi

# 构建 AAR
echo -e "${BLUE}执行构建...${NC}"
if [ "$BUILD_TYPE" = "release" ]; then
    ./gradlew :IMParseSDK:assembleRelease
    AAR_FILE="$SDK_DIR/build/outputs/aar/IMParseSDK-release.aar"
else
    ./gradlew :IMParseSDK:assembleDebug
    AAR_FILE="$SDK_DIR/build/outputs/aar/IMParseSDK-debug.aar"
fi

# 恢复 settings.gradle（如果临时添加了）
if [ "$TEMP_ADDED" = true ]; then
    # 移除最后 3 行
    local total_lines=$(wc -l < settings.gradle | tr -d ' ')
    local keep_lines=$((total_lines - 3))
    head -n "$keep_lines" settings.gradle > settings.gradle.tmp
    mv settings.gradle.tmp settings.gradle
    echo -e "${BLUE}已恢复 settings.gradle${NC}"
fi

# 验证 AAR
if [ -f "$AAR_FILE" ]; then
    SIZE=$(du -h "$AAR_FILE" | cut -f1)
    echo -e "${GREEN}✅ AAR 构建成功: $AAR_FILE ($SIZE)${NC}"
    
    # 检查是否包含 native 库
    if unzip -l "$AAR_FILE" 2>/dev/null | grep -q "jni/.*/libim_parse_core.so"; then
        echo -e "${GREEN}✅ AAR 包含 native 库${NC}"
        unzip -l "$AAR_FILE" 2>/dev/null | grep "jni/.*/libim_parse_core.so" | while read line; do
            echo -e "${BLUE}  $line${NC}"
        done
    else
        echo -e "${YELLOW}⚠️  AAR 中未找到 native 库${NC}"
    fi
    
    # 复制到 app/libs（可选）
    APP_LIBS_DIR="$DEMO_DIR/app/libs"
    mkdir -p "$APP_LIBS_DIR"
    cp "$AAR_FILE" "$APP_LIBS_DIR/"
    echo -e "${GREEN}✅ AAR 已复制到 app/libs${NC}"
    
    echo ""
    echo -e "${GREEN}📦 AAR 位置:${NC}"
    echo "  - $AAR_FILE"
    echo "  - $APP_LIBS_DIR/$(basename $AAR_FILE)"
else
    echo -e "${YELLOW}❌ AAR 文件未找到: $AAR_FILE${NC}"
    exit 1
fi

