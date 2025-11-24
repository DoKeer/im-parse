# UIKitLayoutCalculator 与 UIKitTheme 配置使用分析

## 概述

本文档分析了 `UIKitLayoutCalculator.swift` 中的高度计算和渲染布局是否使用了 `UIKitTheme.swift` 中定义的各种间距和行高等配置。

## 已使用的配置项 ✅

### 1. 间距配置
- **paragraphSpacing** ✅
  - 使用位置：
    - `calculateLayout` (第278行)：根节点垂直堆栈的间距
    - `calculateVerticalStackLayout` (第460行)：引用块内部内容的间距
  
- **listItemSpacing** ✅
  - 使用位置：
    - `calculateListLayout` (第788行)：列表项之间的间距

### 2. 代码块配置
- **codeBlockPadding** ✅
  - 使用位置：
    - `calculateNodeLayout` (第396行)：代码块内边距
    - `estimateMermaidSize` (第547行)：Mermaid 图表的内边距

- **codeBlockBorderRadius** ✅
  - 使用位置：
    - `calculateNodeLayout` (第421行)：代码块圆角

### 3. 表格配置
- **tableCellPadding** ✅
  - 使用位置：
    - `calculateTableLayout` (第721行)：表格单元格内边距

- **tableBorderColor** ✅
  - 使用位置：
    - `NodeLayout.render` (第132行)：表格边框颜色
    - `calculateTableLayout` (第779行)：表格边框颜色

- **tableHeaderBackground** ✅
  - 使用位置：
    - `calculateTableLayout` (第764行)：表头背景色

### 4. 引用块配置
- **blockquoteBorderWidth** ✅
  - 使用位置：
    - `calculateNodeLayout` (第448行)：引用块边框宽度

- **blockquoteBorderColor** ✅
  - 使用位置：
    - `calculateNodeLayout` (第466行)：引用块边框颜色

- **blockquoteTextColor** ✅
  - 使用位置：
    - `calculateNodeLayout` (第452行)：引用块文本颜色

### 5. 字体和颜色配置
- **fontSize** ✅
  - 使用位置：
    - `calculateNodeLayout` (第361行)：计算标题字体大小

- **headingColors** ✅
  - 使用位置：
    - `calculateNodeLayout` (第366行)：标题颜色数组

- **codeFont** ✅
  - 使用位置：
    - `calculateNodeLayout` (第399行)：代码块字体

- **codeBackgroundColor** ✅
  - 使用位置：
    - `calculateNodeLayout` (第420行)：代码块背景色
    - `estimateMermaidSize` (第551行)：Mermaid 图表背景色

- **font** ✅
  - 使用位置：
    - `calculateListLayout` (第877行)：列表标记字体

- **textColor** ✅
  - 使用位置：
    - `calculateListLayout` (第877行)：列表标记文本颜色
    - `estimateMermaidSize` (第550行)：Mermaid 图表文本颜色

- **hrColor** ✅
  - 使用位置：
    - `calculateNodeLayout` (第478行)：分割线颜色

## 未使用的配置项 ❌

### 1. **lineHeight** ❌
**问题描述：**
- `UIKitTheme` 中定义了 `lineHeight: CGFloat`（行高倍数，默认 1.6）
- 但在 `UIKitLayoutCalculator` 和 `UIKitAttributedStringBuilder` 中都没有使用
- 文本布局计算时没有应用行高倍数，导致文本行间距可能不符合主题配置

**影响：**
- 文本行间距可能过紧，影响可读性
- 无法通过主题配置调整行高

**建议修复：**
- 在 `UIKitAttributedStringBuilder.buildAttributedString` 中为 NSAttributedString 添加 `NSParagraphStyle`
- 设置 `lineHeightMultiple` 或 `minimumLineHeight`/`maximumLineHeight` 来应用 `context.theme.lineHeight`

### 2. **maxContentWidth** ❌
**问题描述：**
- `UIKitTheme` 中定义了 `maxContentWidth: CGFloat`（最大内容宽度，默认 800）
- 在布局计算中没有使用，所有内容都使用传入的 `width` 参数

**影响：**
- 无法限制内容的最大宽度
- 在宽屏设备上，文本行可能过长，影响阅读体验

**建议修复：**
- 在 `calculateLayout` 或 `calculateNodeLayout` 中，使用 `min(context.width, context.theme.maxContentWidth)` 来限制内容宽度

### 3. **contentPadding** ❌
**问题描述：**
- `UIKitTheme` 中定义了 `contentPadding: CGFloat`（内容内边距，默认 20）
- 在布局计算中没有使用

**影响：**
- 无法通过主题配置统一设置内容的内边距
- 可能需要手动在每个布局计算中添加内边距

**建议修复：**
- 在根布局计算时，考虑使用 `contentPadding` 来设置整体内容的内边距
- 或者在 `calculateLayout` 中应用内容内边距

### 4. **imageMargin** ❌
**问题描述：**
- `UIKitTheme` 中定义了 `imageMargin: CGFloat`（图片边距，默认 16）
- 在图片布局计算中没有使用（第424-440行）

**影响：**
- 图片没有上下边距，可能与其他元素贴得太近
- 无法通过主题配置调整图片间距

**建议修复：**
- 在 `calculateNodeLayout` 的 `.image` 分支中，考虑在图片上下添加 `imageMargin` 间距
- 或者在垂直堆栈布局中，为图片节点添加额外的间距

## 总结

### 使用情况统计
- **已使用：** 17 个配置项 ✅
- **未使用：** 4 个配置项 ❌
- **使用率：** 81%

### 主要问题
1. **行高未应用** - 这是最严重的问题，影响文本可读性
2. **内容宽度未限制** - 在宽屏设备上可能影响阅读体验
3. **内容内边距未使用** - 无法统一控制内容边距
4. **图片边距未使用** - 图片与其他元素间距可能不合适

### 建议优先级
1. **高优先级：** 修复 `lineHeight` 未使用的问题
2. **中优先级：** 应用 `maxContentWidth` 和 `contentPadding`
3. **低优先级：** 应用 `imageMargin`

