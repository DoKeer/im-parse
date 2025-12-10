#!/bin/bash

# 设置本地 Web 资源脚本
# 下载 Mermaid.js 和 KaTeX CSS 到本地，提升加载速度和离线支持

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 版本定义
MERMAID_VERSION="10.6.1"
KATEX_VERSION="0.16.9"

# 资源目录（相对于脚本所在目录）
RESOURCES_DIR="IMParseSDK/Resources"

echo "========================================="
echo "IMParseSDK Web Resources Setup"
echo "========================================="
echo ""

# 创建资源目录
if [ ! -d "$RESOURCES_DIR" ]; then
    echo "Creating resources directory..."
    mkdir -p "$RESOURCES_DIR"
fi

# 下载 Mermaid.js
echo -e "${YELLOW}📦 Downloading Mermaid.js v${MERMAID_VERSION}...${NC}"
MERMAID_URL="https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js"
MERMAID_FILE="$RESOURCES_DIR/mermaid.min.js"

if curl -L -f -o "$MERMAID_FILE" "$MERMAID_URL"; then
    MERMAID_SIZE=$(du -h "$MERMAID_FILE" | cut -f1)
    echo -e "${GREEN}✅ Mermaid.js downloaded successfully ($MERMAID_SIZE)${NC}"
else
    echo -e "${RED}❌ Failed to download Mermaid.js${NC}"
    exit 1
fi

# 下载 KaTeX CSS
echo ""
echo -e "${YELLOW}📦 Downloading KaTeX CSS v${KATEX_VERSION}...${NC}"
KATEX_URL="https://cdn.jsdelivr.net/npm/katex@${KATEX_VERSION}/dist/katex.min.css"
KATEX_FILE="$RESOURCES_DIR/katex.min.css"

if curl -L -f -o "$KATEX_FILE" "$KATEX_URL"; then
    KATEX_SIZE=$(du -h "$KATEX_FILE" | cut -f1)
    echo -e "${GREEN}✅ KaTeX CSS downloaded successfully ($KATEX_SIZE)${NC}"
else
    echo -e "${RED}❌ Failed to download KaTeX CSS${NC}"
    exit 1
fi

# 询问是否下载字体文件
echo ""
echo -e "${YELLOW}Do you want to download KaTeX fonts? (optional, ~1.5MB)${NC}"
read -p "Download fonts? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    FONTS_DIR="$RESOURCES_DIR/fonts"
    mkdir -p "$FONTS_DIR"
    
    echo -e "${YELLOW}📦 Downloading KaTeX fonts...${NC}"
    
    # 主要字体文件列表
    FONTS=(
        "KaTeX_Main-Regular.woff2"
        "KaTeX_Math-Italic.woff2"
        "KaTeX_Size1-Regular.woff2"
        "KaTeX_Size2-Regular.woff2"
    )
    
    FONT_COUNT=0
    for FONT in "${FONTS[@]}"; do
        FONT_URL="https://cdn.jsdelivr.net/npm/katex@${KATEX_VERSION}/dist/fonts/${FONT}"
        FONT_FILE="$FONTS_DIR/$FONT"
        
        if curl -L -f -o "$FONT_FILE" "$FONT_URL" 2>/dev/null; then
            ((FONT_COUNT++))
        else
            echo -e "${YELLOW}⚠️  Skipped: $FONT${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Downloaded $FONT_COUNT font files${NC}"
else
    echo -e "${YELLOW}⏭️  Skipped font download (will use CDN for fonts)${NC}"
fi

# 显示摘要
echo ""
echo "========================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Downloaded files:"
echo "  📄 $MERMAID_FILE"
echo "  📄 $KATEX_FILE"
if [ -d "$RESOURCES_DIR/fonts" ]; then
    FONT_FILES=$(find "$RESOURCES_DIR/fonts" -type f | wc -l | tr -d ' ')
    echo "  📁 fonts/ ($FONT_FILES files)"
fi
echo ""
echo "Next steps:"
echo "1. 资源文件已下载到: $RESOURCES_DIR"
echo "2. podspec 已配置 resources，资源会自动打包进 SDK"
echo "3. 运行 pod install 重新安装即可使用"
echo ""
echo "详细说明请查看: LOCAL_RESOURCES_SETUP.md"
echo ""

# 提示信息
echo -e "${GREEN}✅ 资源文件已准备就绪，podspec 已配置自动打包${NC}"
echo -e "${YELLOW}💡 运行 'pod install' 后，资源文件会自动包含在 SDK 中${NC}"
echo ""

