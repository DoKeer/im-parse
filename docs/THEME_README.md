分析 Android 版本的间距计算方式，并与 iOS 版本对比。


[2 tools called]


对比 Android 与 iOS 的间距计算方式：

## Android 版本间距设置分析

### 1. 段落间距（Paragraph Spacing）

用于根节点子节点之间的垂直间距：

```83:104:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
    fun render(ast: RootNode, renderContext: AndroidRenderContext): View {
        val container = LinearLayout(renderContext.context)
        container.orientation = LinearLayout.VERTICAL
        container.setPadding(
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding,
            renderContext.theme.contentPadding
        )
        
        for ((index, child) in ast.children.withIndex()) {
            val childView = renderNode(child, renderContext)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 最后一个元素不需要底部间距
            if (index < ast.children.size - 1) {
                params.bottomMargin = renderContext.theme.paragraphSpacing
            }
            container.addView(childView, params)
        }
        
        return container
    }
```

要点：
- 使用 `LinearLayout.LayoutParams.bottomMargin` 设置间距
- 最后一个元素不设置底部间距（通过 `index < ast.children.size - 1` 判断）

### 2. 列表项间距（List Item Spacing）

用于列表项之间的垂直间距：

```485:500:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
    private fun renderList(node: ListNode, context: AndroidRenderContext): View {
        val container = LinearLayout(context.context)
        container.orientation = LinearLayout.VERTICAL
        
        for ((index, item) in node.items.withIndex()) {
            val itemView = renderListItem(item, context, node.listType, index)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            params.bottomMargin = context.theme.listItemSpacing
            container.addView(itemView, params)
        }
        
        return container
    }
```

要点：
- 所有列表项都设置 `bottomMargin`（包括最后一个）

### 3. 列表项内容间距

列表项内部段落/标题的间距：

```582:593:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
        for (child in node.children) {
            val childView = renderNode(child, context)
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            // 为段落等块级元素添加底部间距，避免换行时拥挤
            if (child is ParagraphNode || child is HeadingNode) {
                params.bottomMargin = (context.theme.paragraphSpacing * 0.5f).toInt()
            }
            contentContainer.addView(childView, params)
        }
```

要点：
- 列表项内的段落/标题使用 `paragraphSpacing * 0.5`（半间距）

### 4. 列表标记间距

列表标记与内容之间的间距：

```522:529:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
                marker.setPadding(
                    0, 0,
                    TypedValue.applyDimension(
                        TypedValue.COMPLEX_UNIT_DIP, 8f,
                        context.context.resources.displayMetrics
                    ).toInt(),
                    0
                )
```

要点：
- 硬编码 8dp 的右侧 padding

### 5. 代码块内边距（Code Block Padding）

```336:348:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
        textView.setPadding(context.theme.codeBlockPadding)
        
        // 计算代码内容的实际宽度
        val paint = textView.padding
        val lines = node.content.split("\n")
        var maxLineWidth = 0f
        for (line in lines) {
            val lineWidth = paint.measureText(line)
            maxLineWidth = maxOf(maxLineWidth, lineWidth)
        }
        
        val codePadding = context.theme.codeBlockPadding
        val minCodeWidth = maxLineWidth.toInt() + codePadding * 2
```

要点：
- 使用 `setPadding(padding)` 设置四个方向相同的内边距
- 计算最小宽度时使用 `codePadding * 2`

### 6. 表格单元格内边距（Table Cell Padding）

```659:667:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
            val titleLeftPadding = context.theme.tableCellPadding
            val tableTitle = context.theme.tableTitle ?: "表格"
            val titleLabel = TextView(context.context)
            titleLabel.text = tableTitle
            titleLabel.textSize = 16f
            titleLabel.setTypeface(null, android.graphics.Typeface.BOLD)
            titleLabel.setTextColor(context.theme.textColor)
            titleLabel.gravity = Gravity.START or Gravity.CENTER_VERTICAL
            titleLabel.setPadding(titleLeftPadding, 0, 0, 0)
```

要点：
- 表格标题使用 `tableCellPadding` 作为左侧内边距

### 7. 引用块内边距

```794:800:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
        contentContainer.setPadding(
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 8f,
                context.context.resources.displayMetrics
            ).toInt(),
            0, 0, 0
        )
```

要点：
- 硬编码 8dp 的左侧内边距

### 8. 行内图片间距

```2018:2026:android/IMParseSDK/src/main/java/com/imparse/renderers/AndroidViewRenderer.kt
                val imageHeight = rect.height()
                // 增加上下间距（呼吸感）：上下各 10% 的图片高度
                val extraSpacing = (imageHeight * 0.1f).toInt()

                // 图片顶部对齐字体顶部（参考 iOS：font.ascender - targetHeight）
                // pfm.ascent 是从基线到字体顶部的距离（负数，在基线上方）
                // 图片顶部应该对齐字体顶部，所以图片顶部位置 = pfm.ascent
                // 图片底部位置 = pfm.ascent + imageHeight
                fm.ascent = pfm.ascent-extraSpacing
                fm.descent = pfm.ascent + imageHeight+extraSpacing
```

要点：
- 行内图片上下各增加 10% 高度的间距（动态计算）

## iOS vs Android 对比

| 间距类型 | iOS 实现方式 | Android 实现方式 | 差异 |
|---------|------------|----------------|------|
| 段落间距 | `calculateVerticalStackLayout` 中累加 `spacing`，最后减去最后一个的间距 | `LinearLayout.LayoutParams.bottomMargin`，最后一个不设置 | 实现方式不同，效果相同 |
| 列表项间距 | 所有项都加间距，最后减去 | `bottomMargin`，最后一个不设置 | 已统一，效果相同 |
| 列表项内容间距 | `paragraphSpacing * 0.5` | `paragraphSpacing * 0.5` | 已统一，都使用主题配置 |
| 列表标记间距 | `theme.listMarkerSpacing`（默认 8） | `theme.listMarkerSpacing`（默认 8dp） | 已统一，都使用主题配置 |
| 代码块内边距 | `padding * 2` 计算上下内边距 | `setPadding(padding)` 设置四个方向 | Android 更简单 |
| 表格单元格内边距 | `cellPadding * 2` | 在 `CustomTableLayout` 中处理 | 实现位置不同 |
| 引用块内边距 | `borderWidth + theme.blockquotePadding`（默认 16） | `theme.blockquotePadding`（默认 16dp） | 已统一，都使用主题配置 |
| 图片边距 | `imageMargin * 2` | `imageMargin` 默认为 0 | Android 默认无边距 |
| 行内图片间距 | 无额外间距 | 上下各 10% 图片高度 | Android 有动态间距 |

## 主要差异总结

1. 实现机制：
   - iOS：通过计算 `currentY` 累加高度和间距
   - Android：使用 `LayoutParams` 的 `margin` 和 `padding`

2. 最后一个元素间距：
   - iOS：明确减去最后一个元素的间距
   - Android：通过条件判断不设置最后一个元素的 `bottomMargin`

3. 列表项间距：
   - iOS：最后减去间距
   - Android：最后一个列表项不设置 `bottomMargin`（已对齐 iOS）

4. 硬编码值：
   - 已全部移除，统一使用主题配置：
     - 列表标记间距：`listMarkerSpacing`（默认 8）
     - 列表项内容间距：`paragraphSpacing * 0.5`
     - 引用块内边距：`blockquotePadding`（默认 16）

5. 行内图片：
   - iOS：无额外间距
   - Android：上下各 10% 图片高度的动态间距

6. 图片边距：
   - iOS：使用 `imageMargin * 2`
   - Android：`imageMargin` 默认为 0，实际未使用

建议统一两端的间距计算逻辑，确保视觉效果一致。