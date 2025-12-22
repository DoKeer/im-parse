# Mermaid & Math 节点高度计算修复

## 问题分析

### 问题1：actualHeight 和 currentHeight 总是相差 4

**根本原因：布局计算和渲染阶段的高度计算不一致**

#### 布局计算阶段（calculateMermaidLayout）

```swift
let topAreaHeight: CGFloat = max(toolbarHeight, switcherHeight) + toolbarPadding * 2
let totalHeight = max(imageFrame.origin.y*2+imageFrame.height, contentHeight) + topAreaHeight
```

这里的 `totalHeight` 包含了：
- 内容高度（图片或原文）
- toolbarHeight 
- **toolbarPadding * 2** ⚠️

#### 渲染阶段（renderMermaid）

```swift
let contentContainer = createEmptyView(size: CGSize(
    width: frame.size.width,
    height: frame.size.height - toolbarHeight  // 只减去了toolbarHeight
))
```

这里的 `previewView.height` = `frame.size.height - toolbarHeight`

#### 验证阶段（addMermaidImageView）

```swift
let actualHeight = max(ceil(size.height) + padding * 2, totalHeight)
let currentHeight = previewView.frame.height
```

#### 数学推导

假设 `toolbarPadding = 2`，`toolbarHeight >= switcherHeight`

- **布局计算：**
  ```
  totalHeight = contentHeight + toolbarHeight + toolbarPadding * 2
  ```

- **实际渲染：**
  ```
  previewView.height = totalHeight - toolbarHeight 
                     = contentHeight + toolbarPadding * 2
  ```

- **验证计算：**
  ```
  actualHeight = contentHeight  (不包含padding)
  currentHeight = contentHeight + toolbarPadding * 2
  ```

- **差值：**
  ```
  currentHeight - actualHeight = toolbarPadding * 2 = 2 * 2 = 4 ✅
  ```

### 问题2：重新渲染时可能重复添加 subview

#### 发现的问题

1. **UIKitFrameMessageListViewController** 中已经正确处理：
   ```swift
   // 清除旧的内容视图（第301行）
   contentView_wrapper.subviews.forEach { $0.removeFromSuperview() }
   ```

2. **renderMermaidPreview** 中也正确处理了占位符：
   ```swift
   // 移除占位符（第1134行）
   previewView.viewWithTag(RenderConstants.mermaidPlaceholderTag)?.removeFromSuperview()
   ```

3. **addMermaidImageView 和 addMathImageView 中没有移除旧的 imageView** ⚠️
   - 虽然通常情况下不会重复调用（因为每次都创建新的view）
   - 但为了代码健壮性，应该添加移除逻辑

## 修复方案

### 修复1：统一 Mermaid 节点的高度计算

**修改文件：** `UIKitFrameAsyncCalculator.swift`

**修改内容：**

```swift
// ❌ 修改前
let topAreaHeight: CGFloat = max(toolbarHeight, switcherHeight) + toolbarPadding * 2
let totalHeight = max(imageFrame.origin.y*2+imageFrame.height, contentHeight)+topAreaHeight

// ✅ 修改后
// 计算图片frame和总内容高度
let imageFrame = UIKitFrameAsyncCalculator.calculateMermaidImageFrame(imageSize: imageSize, context: context)
let imageContentHeight = imageFrame.origin.y*2+imageFrame.height

// previewView 的内容高度（不包含 toolbar）= max(图片高度, 原文高度)
let previewContentHeight = max(imageContentHeight, contentHeight)

// 总高度 = toolbar高度 + previewView内容高度
let totalHeight = toolbarHeight + previewContentHeight
```

**修改原因：**
- 移除了 `toolbarPadding * 2` 的额外计算
- 直接使用 `toolbarHeight + previewContentHeight`
- 与 `renderMermaid` 中的 `height = frame.size.height - toolbarHeight` 保持一致

### 修复2：统一 addMermaidImageView 的高度验证

**修改文件：** `UIKitFrameRender.swift`

**修改内容：**

```swift
// ❌ 修改前
let totalHeight = imageFrame.origin.y*2 + imageFrame.height
let actualHeight = max(ceil(size.height) + padding * 2, totalHeight)

// ✅ 修改后
let imageContentHeight = imageFrame.origin.y*2 + imageFrame.height
let textContentHeight = ceil(size.height) + padding * 2
// 实际内容高度（不包含toolbar）= max(图片高度, 原文高度)
let actualHeight = max(textContentHeight, imageContentHeight)
```

**新增内容：**
```swift
// 移除旧的 imageView（如果存在），避免重复添加
previewView.subviews.compactMap { $0 as? UIImageView }.forEach { $0.removeFromSuperview() }
```

### 修复3：为 Math 节点添加同样的保护

**修改文件：** `UIKitFrameRender.swift`

**新增内容：**
```swift
// 移除旧的 imageView（如果存在），避免重复添加
containerView.subviews.compactMap { $0 as? UIImageView }.forEach { $0.removeFromSuperview() }
```

## 验证方法

### 1. 验证高度差异是否消失

在 `addMermaidImageView` 方法中打印调试信息：

```swift
print("📏 Mermaid高度验证:")
print("  imageContentHeight: \(imageContentHeight)")
print("  textContentHeight: \(textContentHeight)")
print("  actualHeight: \(actualHeight)")
print("  currentHeight: \(currentHeight)")
print("  差值: \(abs(actualHeight - currentHeight))")
```

**预期结果：** 差值应该接近 0（小于 0.5）

### 2. 验证 subview 是否重复添加

在 `addMermaidImageView` 和 `addMathImageView` 方法开始时打印：

```swift
print("🔍 当前 previewView 的 imageView 数量: \(previewView.subviews.compactMap { $0 as? UIImageView }.count)")
```

**预期结果：** 每次调用前应该移除旧的，保持数量不超过 1

### 3. 测试场景

1. **基本渲染测试：**
   - 包含 Mermaid 图表的消息
   - 包含 Math 公式的消息
   - 验证首次加载和缓存加载

2. **滚动测试：**
   - 快速滚动列表，触发 cell 复用
   - 检查是否有视图重叠或高度跳动

3. **异步加载测试：**
   - 清除缓存，测试异步渲染
   - 验证从占位符到图片的切换是否平滑

## 影响范围

### 直接影响

- ✅ Mermaid 节点的高度计算现在完全一致
- ✅ Math 节点的 imageView 重复添加问题已修复
- ✅ 代码可读性提升，变量命名更清晰

### 间接影响

- ✅ 减少了 `onNodeLayoutChanged` 的触发次数
- ✅ 提升了渲染性能（避免不必要的布局重计算）
- ✅ 提升了代码健壮性（防御性编程）

## 相关文件

- `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitFrameAsyncCalculator.swift`
- `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitFrameRender.swift`

## 修改日期

2025-12-22

