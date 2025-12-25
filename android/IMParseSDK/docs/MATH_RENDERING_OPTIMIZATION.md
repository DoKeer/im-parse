# 数学公式高清渲染优化

## 问题描述
之前的数学公式图片虽然大但是不清晰，在高密度屏幕（视网膜屏幕）上显示效果不佳。

## 优化方案

### 1. 提高 WebView 渲染分辨率
**文件**: `android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidMathHTMLRenderer.kt`

**修改位置**: 第 503 行

**修改内容**:
- 将 html2canvas 的 scale 参数从 `window.devicePixelRatio || 2` 提升到 `Math.max(window.devicePixelRatio || 2, 2) * 1.5`
- 这样可以生成更高分辨率的图片（3x-4.5x），特别适合高密度屏幕

```javascript
// 使用更高的 scale 以支持高密度屏幕（视网膜屏幕）
const renderScale = Math.max(window.devicePixelRatio || 2, 2) * 1.5;
html2canvas(mathElement, {
    backgroundColor: null,
    scale: renderScale,  // 提高渲染分辨率
    // ... 其他配置
})
```

### 2. 设置 Bitmap 的 Density
**文件**: `android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidMathHTMLRenderer.kt`

**修改位置**: 第 561-574 行

**修改内容**:
- 使用 `BitmapFactory.Options` 解码图片时设置合适的 density
- 将 `inDensity` 设置为 `DENSITY_MEDIUM` (160 dpi)
- 将 `inTargetDensity` 设置为设备屏幕的实际 dpi
- 使用 `ARGB_8888` 配置以获得最佳质量

```kotlin
// 使用 BitmapFactory.Options 设置适合高密度屏幕的 density
val options = BitmapFactory.Options()
options.inDensity = android.util.DisplayMetrics.DENSITY_MEDIUM // 160 dpi (基准)
options.inTargetDensity = task.webView.context.resources.displayMetrics.densityDpi
options.inScaled = true
options.inPreferredConfig = Bitmap.Config.ARGB_8888 // 使用高质量配置

val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
```

### 3. 使用高质量缩放算法
**文件**: `android/IMParseSDK/src/main/java/com/imparse/renderers/MathFormulaRenderer.kt`

**修改位置**: 第 318-341 行（createInlineImageSpan 方法）

**修改内容**:
- 将 `image.scale()` 改为 `Bitmap.createScaledBitmap()` 并启用过滤
- 使用双线性插值（filter=true）产生更平滑、更清晰的结果
- 保持原图的 density 设置

```kotlin
// 使用高质量缩放算法
// filter=true 会使用双线性插值，产生更平滑、更清晰的结果
val scaledBitmap = Bitmap.createScaledBitmap(
    image,
    targetWidth.toInt(),
    targetHeight.toInt(),
    true  // 使用高质量过滤（双线性插值）
)

// 保持原图的 density 设置
scaledBitmap.density = image.density
```

## 优化效果

1. **更高的渲染分辨率**: 原始图片生成时就使用 3x-4.5x 的分辨率，确保在高密度屏幕上显示清晰
2. **正确的 Density 设置**: Bitmap 的 density 根据设备屏幕密度自动调整，确保图片按正确的尺寸显示
3. **高质量缩放**: 使用双线性插值算法，避免缩放时产生锯齿和模糊
4. **自适应**: 自动根据设备的屏幕密度 (devicePixelRatio) 调整渲染质量

## 技术细节

### 渲染分辨率计算
- 2x 屏幕 (XHDPI): renderScale = 2 * 1.5 = 3x
- 3x 屏幕 (XXHDPI): renderScale = 3 * 1.5 = 4.5x
- 更高密度屏幕会获得更高的渲染分辨率

### Density 转换
通过设置 `inDensity` 和 `inTargetDensity`，系统会自动按比例缩放：
- inDensity = 160 (基准)
- inTargetDensity = 设备实际 dpi (例如 480 for XXHDPI)
- 缩放比例 = 480 / 160 = 3x

### 缩放质量
`Bitmap.createScaledBitmap()` 的 filter 参数：
- true: 使用双线性插值，产生平滑结果（推荐）
- false: 使用最近邻插值，可能产生锯齿

## 注意事项

1. 更高的渲染分辨率会增加内存占用和渲染时间
2. 图片缓存仍然有效，只需渲染一次
3. ImageView 默认已启用过滤，无需额外配置
4. density 设置确保图片在不同密度屏幕上显示正确的物理尺寸

## 测试建议

1. 在不同密度的设备上测试（HDPI, XHDPI, XXHDPI, XXXHDPI）
2. 测试复杂的数学公式（分数、矩阵、积分等）
3. 检查内存使用情况
4. 验证缓存机制正常工作

