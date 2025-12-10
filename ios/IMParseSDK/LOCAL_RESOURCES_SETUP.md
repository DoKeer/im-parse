# 本地资源设置指南

## 概述

为了提升加载速度和离线兼容性，SDK 支持将 Mermaid.js 和 KaTeX CSS 文件打包到 App 中。

**加载策略**：
1. 优先尝试加载本地 Bundle 中的资源（iOS 11+）
2. 如果本地加载失败，自动降级到 CDN
3. iOS 10 及以下直接使用 CDN

## 资源文件准备

### 1. 下载 Mermaid.js

```bash
# 下载 mermaid.min.js
curl -o mermaid.min.js https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js
```

### 2. 下载 KaTeX CSS 和字体

```bash
# 下载 katex.min.css
curl -o katex.min.css https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css

# 可选：下载 KaTeX 字体文件（如果需要离线支持）
# 注意：字体文件较大，如果网络可用，建议让 CSS 从 CDN 加载字体
mkdir -p fonts
curl -o fonts/KaTeX_Main-Regular.woff2 https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/fonts/KaTeX_Main-Regular.woff2
```

## 添加资源到 SDK

### 方式 1：通过 Xcode

1. 将下载的文件拖入 Xcode 项目
2. 选择 `IMParseSDK` 目标
3. 确保 "Copy items if needed" **未选中**（使用引用）
4. 确保 "Add to targets" 选中 `IMParseSDK`
5. 推荐放置位置：`IMParseSDK/Resources/`

### 方式 2：通过 CocoaPods（推荐）

编辑 `IMParseSDK.podspec`：

```ruby
Pod::Spec.new do |s|
  # ... 其他配置 ...
  
  # 添加资源文件
  s.resources = [
    'IMParseSDK/Resources/mermaid.min.js',
    'IMParseSDK/Resources/katex.min.css'
  ]
  
  # 如果包含字体文件
  # s.resources = [
  #   'IMParseSDK/Resources/mermaid.min.js',
  #   'IMParseSDK/Resources/katex.min.css',
  #   'IMParseSDK/Resources/fonts/*.woff2'
  # ]
end
```

然后创建资源目录并添加文件：

```bash
mkdir -p IMParseSDK/Resources
mv mermaid.min.js IMParseSDK/Resources/
mv katex.min.css IMParseSDK/Resources/
```

### 方式 3：通过构建脚本

创建 `setup-web-resources.sh`：

```bash
#!/bin/bash

RESOURCES_DIR="IMParseSDK/Resources"
mkdir -p "$RESOURCES_DIR"

echo "Downloading Mermaid.js..."
curl -L -o "$RESOURCES_DIR/mermaid.min.js" \
  https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js

echo "Downloading KaTeX CSS..."
curl -L -o "$RESOURCES_DIR/katex.min.css" \
  https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css

echo "Done! Resources downloaded to $RESOURCES_DIR"
```

运行脚本：

```bash
chmod +x setup-web-resources.sh
./setup-web-resources.sh
```

## 验证安装

运行以下测试代码验证资源是否正确加载：

```swift
import IMParseSDK

// 检查本地资源是否存在
let hasLocal = LocalResourceManager.shared.hasLocalResources()
print("Local resources available: \(hasLocal)")

// 测试 Mermaid 渲染
MermaidHTMLRenderer.shared.render(
    mermaidCode: "graph TD\nA-->B",
    textColor: "#000000",
    backgroundColor: "#ffffff"
) { image in
    if let image = image {
        print("✅ Mermaid rendered successfully: \(image.size)")
    } else {
        print("❌ Mermaid rendering failed")
    }
}
```

## 文件大小参考

- `mermaid.min.js`: ~900 KB
- `katex.min.css`: ~30 KB
- KaTeX 字体（可选）: ~1.5 MB（包含所有字体文件）

**建议**：
- 必须包含：`mermaid.min.js` 和 `katex.min.css`
- 可选：KaTeX 字体文件（如果需要完全离线支持）

## 更新资源文件

定期更新资源文件以获取最新功能和修复：

```bash
# 查看当前版本
# Mermaid: 10.6.1
# KaTeX: 0.16.9

# 更新到新版本，修改 URL 中的版本号：
curl -L -o IMParseSDK/Resources/mermaid.min.js \
  https://cdn.jsdelivr.net/npm/mermaid@10.9.0/dist/mermaid.min.js
```

## 降级行为

系统会按以下顺序尝试加载资源：

1. **iOS 11+**:
   - 尝试从 Bundle 加载（`app-resource://` scheme）
   - 失败时自动降级到 CDN
   - 控制台会输出加载日志

2. **iOS 10**:
   - 直接使用 CDN
   - 不支持自定义 URL Scheme

## iOS 14 兼容性

已针对 iOS 14 进行以下优化：

1. ✅ 显式启用 JavaScript
2. ✅ 配置 `WKWebsiteDataStore` 允许网络访问
3. ✅ 使用轮询机制等待资源加载（替代固定延迟）
4. ✅ 详细的加载日志，便于调试
5. ✅ 本地资源优先，CDN 降级

## 故障排查

### 问题：iOS 14 设备无法渲染 Mermaid

**检查清单**：
- [ ] 确认已添加 `mermaid.min.js` 到 Bundle
- [ ] 查看 Xcode 控制台日志，搜索 "MermaidHTMLRenderer"
- [ ] 检查网络连接（降级到 CDN 时需要）
- [ ] 确认 JavaScript 已启用（检查日志）

**调试命令**：
```swift
// 启用详细日志
print("Mermaid Local URL: \(LocalResourceManager.mermaidLocalURL)")
print("Has local resources: \(LocalResourceManager.shared.hasLocalResources())")
```

### 问题：资源文件无法加载

1. 检查文件是否正确添加到 target：
   - Xcode → 选择文件 → File Inspector → Target Membership

2. 检查 Bundle 中是否包含文件：
   ```swift
   let bundle = Bundle(for: LocalResourceSchemeHandler.self)
   let mermaidPath = bundle.url(forResource: "mermaid.min.js", withExtension: nil)
   print("Mermaid path: \(String(describing: mermaidPath))")
   ```

3. 查看控制台日志（搜索关键词）：
   - "LocalResourceSchemeHandler"
   - "Failed to load"
   - "falling back to CDN"

## 性能对比

| 场景 | 无本地资源 | 有本地资源 |
|------|-----------|-----------|
| 首次加载 | ~2-5 秒 | ~0.5 秒 |
| 缓存后 | ~1-2 秒 | ~0.3 秒 |
| 离线 | ❌ 失败 | ✅ 成功 |

## 注意事项

1. **版本同步**：确保 iOS 和 Android 使用相同版本的 Mermaid/KaTeX
2. **文件名**：严格匹配 `mermaid.min.js` 和 `katex.min.css`（区分大小写）
3. **Scheme 限制**：自定义 URL Scheme 仅支持 iOS 11+
4. **字体文件**：KaTeX 字体文件较大，建议优先使用 CDN 加载

## 参考链接

- [Mermaid.js 官网](https://mermaid.js.org/)
- [KaTeX 官网](https://katex.org/)
- [jsDelivr CDN](https://www.jsdelivr.com/)

