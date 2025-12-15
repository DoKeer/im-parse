# Math 渲染优化说明

## 优化时间
2025-12-15

## 问题描述
数学公式渲染时生成的图片存在以下问题：
1. **图片模糊** - 在 Retina 屏幕（2x/3x）上显示不清晰
2. **内容不完整** - 高度可能差几个像素，导致公式被裁剪

## 优化方案

### 1. 字体完整性 ✅
**问题**：原本只有 4 个 KaTeX 字体文件，不支持某些特殊符号
**解决**：下载了 KaTeX 0.16.9 的全部 20 个字体文件

完整字体列表：
- KaTeX_Main-Regular.woff2 (26KB) - 主字体
- KaTeX_Main-Bold.woff2 (25KB) - 粗体
- KaTeX_Main-Italic.woff2 (17KB) - 斜体
- KaTeX_Main-BoldItalic.woff2 (16KB) - 粗斜体
- KaTeX_Math-Italic.woff2 (16KB) - 数学斜体
- KaTeX_Math-BoldItalic.woff2 (16KB) - 数学粗斜体
- KaTeX_AMS-Regular.woff2 (28KB) - AMS 符号
- KaTeX_Caligraphic-Regular.woff2 (7KB) - 花体
- KaTeX_Caligraphic-Bold.woff2 (7KB) - 粗花体
- KaTeX_Fraktur-Regular.woff2 (11KB) - 哥特体
- KaTeX_Fraktur-Bold.woff2 (11KB) - 粗哥特体
- KaTeX_SansSerif-Regular.woff2 (10KB) - 无衬线
- KaTeX_SansSerif-Bold.woff2 (12KB) - 粗无衬线
- KaTeX_SansSerif-Italic.woff2 (12KB) - 斜无衬线
- KaTeX_Script-Regular.woff2 (9KB) - 手写体
- KaTeX_Typewriter-Regular.woff2 (13KB) - 打字机字体
- KaTeX_Size1-Regular.woff2 (5KB) - 大尺寸符号
- KaTeX_Size2-Regular.woff2 (5KB) - 超大尺寸符号
- KaTeX_Size3-Regular.woff2 (3KB) - 特大尺寸符号
- KaTeX_Size4-Regular.woff2 (5KB) - 极大尺寸符号

**字体路径**：`ios/IMParseSDK/IMParseSDK/Resources/fonts/`

### 2. 高清图片生成 ✅
**问题**：截图时没有考虑屏幕 scale（Retina 屏）
**解决**：
- 使用 `UIScreen.main.scale` 获取屏幕倍率（2x/3x）
- 设置 `WKSnapshotConfiguration.snapshotWidth` 为实际像素宽度（点数 × scale）
- 生成的图片像素密度匹配设备屏幕，避免模糊

**关键代码修改**：
```swift
let scale = UIScreen.main.scale
config.snapshotWidth = NSNumber(value: Double(targetRect.width * scale))
```

### 3. 内容完整性优化 ✅
**问题**：截图区域计算不精确，导致高度被裁剪
**解决**：
- 同时检查 `getBoundingClientRect()` 和 `scrollWidth/scrollHeight`，取最大值
- 为截图区域上下增加 2pt padding，避免边界裁剪
- 增大 WebView 初始尺寸（宽 2000pt，高 200-500pt），确保内容能完全渲染

**JavaScript 尺寸计算优化**：
```javascript
// 使用 Math.max() 确保不会遗漏溢出内容
return {
    width: Math.ceil(Math.max(rect.width, scrollWidth)),
    height: Math.ceil(Math.max(rect.height, scrollHeight))
};
```

**截图区域 padding**：
```swift
let padding: CGFloat = 2.0
targetRect = CGRect(
    x: max(0, rect.origin.x),
    y: max(0, rect.origin.y - padding),
    width: rect.width,
    height: rect.height + padding * 2
)
```

### 4. 图片质量验证 ✅
**新增功能**：在截图完成后验证生成的图片尺寸
- 检查实际像素是否与预期匹配
- 如果差异超过 5%，打印警告日志
- 帮助开发者快速发现问题

## 预期效果

### 渲染质量
- ✅ 图片在 Retina 屏幕上清晰锐利
- ✅ 支持所有 KaTeX 特殊符号（AMS、花体、哥特体等）
- ✅ 公式高度完整，不会被裁剪

### 性能影响
- ⚠️ 图片尺寸增大（2x/3x），内存占用增加
- ✅ 已有缓存机制（`imageCache`），避免重复渲染
- ✅ 已有内存警告处理（`handleMemoryWarning`），自动清理缓存

## 测试建议

### 1. 视觉测试
在不同设备上测试数学公式渲染效果：
- iPhone SE (2x) - 验证 2x 渲染
- iPhone 15 Pro (3x) - 验证 3x 渲染
- iPad Pro - 验证大屏幕场景

### 2. 内容完整性测试
测试各种公式类型：
```latex
// 分数（高度较大）
\frac{a+b}{c+d}

// 矩阵（宽度较大）
\begin{pmatrix} 1 & 2 & 3 \\ 4 & 5 & 6 \end{pmatrix}

// 根式（上下都有延伸）
\sqrt[3]{x^2 + y^2}

// 求和（需要 Size1-4 字体）
\sum_{i=1}^{n} x_i

// AMS 符号
\mathbb{R}, \mathcal{L}, \mathfrak{g}
```

### 3. 性能测试
- 测试 100+ 公式的渲染性能
- 监控内存占用
- 验证缓存机制有效性

## 相关文件

### 修改的文件
- `ios/IMParseSDK/IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift`
  - `captureWebView()` - 添加 scale 支持
  - `renderHTML()` - 增大 WebView 初始尺寸
  - JavaScript 代码 - 优化尺寸计算

### 新增的文件
- `ios/IMParseSDK/IMParseSDK/Resources/fonts/*.woff2` (16 个新字体)

### 相关文件
- `ios/IMParseSDK/IMParseSDK/Classes/Utils/LocalResourceSchemeHandler.swift`
  - 字体自动加载机制（无需修改，已支持）

## 后续改进建议

### 1. 图片压缩
如果内存占用成为问题，可以考虑：
- 使用 JPEG 格式（有损压缩，但文件更小）
- 降低 PNG 压缩质量
- 设置最大图片尺寸限制

### 2. 缓存策略
- 考虑使用 LRU（Least Recently Used）缓存
- 设置缓存大小上限
- 支持持久化缓存（写入磁盘）

### 3. 懒加载优化
- 只在公式进入可视区域时才渲染
- 使用低分辨率占位符
- 支持渐进式加载

## 注意事项

1. **Xcode 项目配置**  
   确保所有新增的字体文件已添加到 Xcode 项目中（Target Membership）

2. **Bundle 资源**  
   运行前检查：所有字体文件都在 App Bundle 的 Resources 目录下

3. **iOS 版本兼容性**  
   自定义 Scheme（app-resource://）需要 iOS 11+  
   iOS 10 及以下会自动降级到 CDN

4. **网络回退**  
   如果本地字体加载失败，KaTeX CSS 会自动从 CDN 加载字体

