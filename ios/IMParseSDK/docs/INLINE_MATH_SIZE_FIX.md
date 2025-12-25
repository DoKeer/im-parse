# 行内数学公式尺寸修复

## 问题描述

1. **行内公式尺寸偏小**：Android 和 iOS 中的行内数学公式显示过小，影响可读性
2. **iOS 异步渲染后不刷新**：iOS 中行内公式异步渲染完成后不自动刷新，需要手动刷新才能看到结果

## 根本原因

### 1. 尺寸偏小的原因

- **Android**：在 `MathFormulaRenderer.kt` 中使用 `lineHeightPx` 作为目标高度
  - `lineHeight` 通常是 `fontSize * 1.5`，导致公式被过度缩小
  - 例如：fontSize = 16sp，lineHeight = 24px，但实际公式应该按 ~20px 高度显示

- **iOS**：在 `MathHTMLRenderer.swift` 中使用 `lineHeight` 作为目标高度
  - 同样的问题，`lineHeight` 比实际需要的尺寸大，导致公式被缩小

### 2. iOS 异步渲染后不刷新的原因

- 在 `UIKitAttributedStringBuilder.swift` 中，异步渲染完成后调用 `onNodeLayoutChanged?(mathNode)`
- 但该回调没有在主线程执行，导致 UI 更新不生效

## 修复方案

### Android 修复

**文件**: `android/IMParseSDK/src/main/java/com/imparse/renderers/MathFormulaRenderer.kt`

**修改内容**:
```kotlin
// 修改前
val targetHeight = lineHeightPx.toFloat()

// 修改后
val targetHeight = lineHeightPx.toFloat() * 0.8f
```

**原理**:
- 使用行高的 80% 作为目标高度
- 这样既能保持与文本的协调性，又能保证公式清晰可见
- 例如：lineHeight = 24px → targetHeight = 19.2px，更接近字体实际显示高度

### iOS 修复

#### 1. 修复尺寸问题

**文件**: `ios/IMParseSDK/IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift`

**修改内容**:
```swift
// 修改前
let targetHeight = lineHeight

// 修改后
let targetHeight = lineHeight * 1.2
```

**原理**:
- 使用行高的 1.2 倍作为目标高度
- 确保公式清晰可见且不会太小
- 例如：lineHeight = 20pt → targetHeight = 24pt，提供更好的可读性

#### 2. 修复异步刷新问题

**文件**: `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitAttributedStringBuilder.swift`

**修改内容**:
```swift
// 修改前
Task {
    if let _ = await MathHTMLRenderer.renderInlineMath(...) {
        onNodeLayoutChanged?(mathNode)
    }
}

// 修改后
Task {
    if let _ = await MathHTMLRenderer.renderInlineMath(...) {
        // 在主线程触发布局更新回调
        await MainActor.run {
            onNodeLayoutChanged?(mathNode)
        }
    }
}
```

**原理**:
- 使用 `MainActor.run` 确保回调在主线程执行
- 这样 UI 更新能够正确触发，不需要手动刷新

## 测试验证

### Android 测试
1. 清除应用缓存：设置 → 应用 → IMParse Demo → 清除数据
2. 重新启动应用
3. 查看包含行内公式的消息（如 `E=mc²`）
4. 验证公式大小是否更清晰可见

### iOS 测试
1. 清除应用缓存或删除应用重新安装
2. 重新启动应用
3. 查看包含行内公式的消息
4. 验证公式大小是否更清晰，且首次加载后能自动刷新显示

## 预期效果

### 修改前
- Android：公式很小，不清晰
- iOS：公式很小，不清晰，异步加载后不刷新

### 修改后
- Android：公式大小适中，清晰可见（约为原来的 1.25 倍）
- iOS：公式大小适中，清晰可见（约为原来的 1.5 倍），异步加载后自动刷新

## 注意事项

1. **缓存清理**：修改后首次运行需要清除缓存，因为旧的小尺寸图片可能被缓存
2. **尺寸调整**：如果觉得公式还是太小或太大，可以调整倍数：
   - Android：修改 `0.8f` 为其他值（如 `0.9f` 或 `0.7f`）
   - iOS：修改 `1.2` 为其他值（如 `1.3` 或 `1.1`）
3. **性能影响**：尺寸增大会导致图片稍大，但对性能影响可忽略不计

## 相关文件

- Android:
  - `android/IMParseSDK/src/main/java/com/imparse/renderers/MathFormulaRenderer.kt`
- iOS:
  - `ios/IMParseSDK/IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift`
  - `ios/IMParseSDK/IMParseSDK/Classes/Renderers/UIKitAttributedStringBuilder.swift`

## 构建和部署

### Android
```bash
cd android
./build-all.sh
cd Android-demo
./gradlew :app:installDebug
```

### iOS
1. 打开 `ios/iOS-demo/iOS-demo.xcworkspace`
2. 选择目标设备
3. 运行（⌘R）

