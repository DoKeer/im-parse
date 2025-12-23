# 表格布局算法技术文档

## 概述

本文档详细说明了 UIKitFrameAsyncCalculator 中表格布局算法的实现原理和设计思路。该算法负责计算表格的列宽、行高以及每个单元格的精确位置，确保表格在不同屏幕宽度下都能正确显示。

## 算法架构

表格布局算法采用**两阶段布局**策略：

1. **列宽计算阶段**：根据单元格内容计算每列的理想宽度
2. **行布局计算阶段**：根据确定的列宽计算每行的高度和单元格位置

## 核心函数

### 1. `calculateTableLayout` - 主布局函数

**位置**：`UIKitFrameAsyncCalculator.swift:688-737`

**功能**：表格布局的入口函数，协调整个布局过程。

**算法流程**：

```
1. 计算可用宽度
   - availableWidth = width - 2 (左右各留1点边框)
   
2. 计算列宽
   - 调用 calculateTableColumnWidths 获取每列宽度
   
3. 计算行布局
   - 遍历所有行，调用 calculateTableRow 计算每行布局
   - 累加行高，行之间添加1点分隔线
   
4. 计算总高度
   - totalHeight = headerBarHeight + tableContentHeight
   - headerBarHeight 仅在存在 toolbarActionDelegate 时显示
   
5. 返回 NodeLayout
   - 包含完整的 frame 和 children 布局信息
```

**关键参数**：
- `toolbarHeight`: 工具栏高度（来自 theme）
- `headerBarHeight`: 表头栏高度（0 或 toolbarHeight）
- `cellPadding`: 单元格内边距
- `maxCellWidth`: 单元格最大宽度
- `minCellWidth`: 单元格最小宽度

### 2. `calculateTableColumnWidths` - 列宽计算

**位置**：`UIKitFrameAsyncCalculator.swift:739-773`

**功能**：计算表格每列的宽度，这是表格布局的核心算法。

**算法流程**：

#### 阶段1：计算理想列宽

```swift
for row in node.rows {
    for (cellIndex, cell) in row.cells.enumerated() {
        // 1. 构建单元格的富文本
        let attrString = context.stringBuilder.buildAttributedString(
            from: cell.children, 
            context: context
        )
        
        // 2. 计算单元格内容的理想宽度
        let idealWidth = calculateIdealCellWidth(
            attrString, 
            maxWidth: maxCellWidth - cellPadding * 2
        )
        
        // 3. 加上内边距
        let cellContentWidth = idealWidth + cellPadding * 2
        
        // 4. 限制在 minCellWidth 和 maxCellWidth 之间
        let clampedWidth = min(max(cellContentWidth, minCellWidth), maxCellWidth)
        
        // 5. 取每列所有单元格的最大宽度
        if cellIndex >= idealCellWidths.count {
            idealCellWidths.append(clampedWidth)
        } else {
            idealCellWidths[cellIndex] = max(idealCellWidths[cellIndex], clampedWidth)
        }
    }
}
```

**设计要点**：
- 遍历所有行和单元格，确保每列宽度满足所有单元格的需求
- 使用 `max()` 确保列宽能容纳该列最宽的单元格

#### 阶段2：智能压缩

```swift
let compressedWidths = applyCompressionAlgorithm(
    idealCellWidths, 
    maxWidth: maxCellWidth, 
    minWidth: minCellWidth
)
```

**目的**：防止某些列过宽，影响整体布局美观。

#### 阶段3：宽度分配

```swift
let totalIdealWidth = compressedWidths.reduce(0, +)

if totalIdealWidth < availableWidth {
    // 如果总宽度小于可用宽度，按比例拉伸
    return stretchCellWidthsProportionally(
        compressedWidths, 
        targetWidth: availableWidth, 
        maxWidth: maxCellWidth
    )
} else {
    // 如果总宽度大于可用宽度，使用压缩后的宽度
    return compressedWidths
}
```

**设计思路**：
- **空间充足**：按比例拉伸各列，充分利用可用空间
- **空间不足**：使用压缩后的宽度，确保表格不超出边界

### 3. `calculateTableRow` - 行布局计算

**位置**：`UIKitFrameAsyncCalculator.swift:775-822`

**功能**：计算单行的布局，包括每个单元格的位置和高度。

**算法流程**：

```
1. 初始化
   - currentX = 0 (当前列的水平位置)
   - cellLayouts = [] (单元格布局数组)

2. 遍历单元格
   for (cellIndex, cell) in row.cells.enumerated() {
       // a. 获取列宽
       let cellWidth = columnWidths[cellIndex]
       let cellContentWidth = cellWidth - cellPadding * 2
       
       // b. 构建富文本并计算高度
       let attrString = context.stringBuilder.buildAttributedString(...)
       let size = calculateAttributedStringSize(attrString, width: cellContentWidth)
       let cellHeight = ceil(size.height) + cellPadding * 2
       
       // c. 创建单元格布局
       let cellLayout = NodeLayout(
           frame: CGRect(x: currentX, y: 0, width: cellWidth, height: cellHeight),
           content: attrString
       )
       
       // d. 更新位置
       currentX += cellWidth
   }

3. 统一行高
   - 取所有单元格的最大高度作为行高
   - 更新所有单元格的高度为行高（确保同一行单元格高度一致）

4. 创建行布局
   - frame: (x: 0, y: currentY, width: currentX, height: rowHeight)
   - children: cellLayouts
```

**关键设计**：
- **统一行高**：同一行的所有单元格高度必须相同，取最大值
- **相对定位**：单元格的 y 坐标相对于行（设为 0），行的 y 坐标相对于表格
- **水平累加**：单元格按列宽顺序水平排列

### 4. `calculateIdealCellWidth` - 单元格理想宽度计算

**位置**：`UIKitFrameAsyncCalculator.swift:824-849`

**功能**：计算单元格内容的理想宽度，用于列宽计算。

**算法**：

```swift
// 1. 检查是否包含附件（图片等）
var hasAttachment = false
attrString.enumerateAttribute(.attachment, ...) { value, _, stop in
    if value != nil {
        hasAttachment = true
        stop.pointee = true
    }
}

// 2. 根据是否包含附件选择计算方法
if hasAttachment {
    // 使用 NSLayoutManager 精确计算（支持附件）
    let textStorage = NSTextStorage(attributedString: attrString)
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(size: CGSize(
        width: maxWidth, 
        height: .greatestFiniteMagnitude
    ))
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    
    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    return min(ceil(usedRect.width), maxWidth)
} else {
    // 使用 boundingRect 快速计算（纯文本）
    let size = calculateTextSize(attrString, width: maxWidth)
    return min(ceil(size.width), maxWidth)
}
```

**设计要点**：
- **附件检测**：区分纯文本和包含图片等附件的单元格
- **精确计算**：包含附件时使用 `NSLayoutManager` 进行精确布局计算
- **性能优化**：纯文本时使用更快的 `boundingRect` 方法

### 5. `applyCompressionAlgorithm` - 智能压缩算法

**位置**：`UIKitFrameAsyncCalculator.swift:851-865`

**功能**：防止某些列过宽，保持表格布局的平衡。

**算法**：

```swift
var result = widths
let totalWidth = widths.reduce(0, +)
let averageWidth = totalWidth / CGFloat(widths.count)

// 压缩阈值：平均宽度的1.5倍，但不超过最大宽度
let compressionThreshold = min(averageWidth * 1.5, maxWidth)

for (index, width) in widths.enumerated() {
    if width > compressionThreshold {
        // 超过阈值的列被压缩到阈值或最小宽度
        result[index] = max(compressionThreshold, minWidth)
    }
}
```

**设计思路**：
- **阈值计算**：基于平均宽度的1.5倍，避免单列过宽
- **压缩策略**：只压缩超过阈值的列，保持相对平衡
- **边界保护**：确保压缩后的宽度不小于 `minCellWidth`

**示例**：
```
假设有4列，宽度为 [100, 100, 100, 400]
平均宽度 = 175
压缩阈值 = min(175 * 1.5, maxWidth) = 262.5
结果 = [100, 100, 100, 262.5]  // 第4列被压缩
```

### 6. `stretchCellWidthsProportionally` - 按比例拉伸

**位置**：`UIKitFrameAsyncCalculator.swift:867-901`

**功能**：当总宽度小于可用宽度时，按比例拉伸各列以填满可用空间。

**算法流程**：

#### 阶段1：按比例拉伸

```swift
let currentTotal = widths.reduce(0, +)
let scale = targetWidth / currentTotal

for width in widths {
    let stretched = min(width * scale, maxWidth)
    result.append(stretched)
    actualTotal += stretched
}
```

**说明**：按比例拉伸，但不超过 `maxWidth`。

#### 阶段2：分配剩余空间

```swift
if actualTotal < targetWidth {
    let remaining = targetWidth - actualTotal
    var eligibleIndices: [Int] = []
    
    // 找出未达到最大宽度的列
    for (index, width) in result.enumerated() {
        if width < maxWidth {
            eligibleIndices.append(index)
        }
    }
    
    // 平均分配剩余空间
    if !eligibleIndices.isEmpty {
        let extraPerColumn = remaining / CGFloat(eligibleIndices.count)
        for index in eligibleIndices {
            result[index] = min(result[index] + extraPerColumn, maxWidth)
        }
    }
}
```

**设计思路**：
- **两阶段拉伸**：先按比例拉伸，再分配剩余空间
- **边界保护**：确保不超过 `maxWidth`
- **公平分配**：剩余空间平均分配给未达到最大宽度的列

**示例**：
```
初始宽度: [100, 100, 100]
目标宽度: 400
最大宽度: 150

阶段1（按比例拉伸）:
  scale = 400 / 300 = 1.33
  result = [133, 133, 133]  // 都未超过150
  actualTotal = 399

阶段2（分配剩余）:
  remaining = 400 - 399 = 1
  eligibleIndices = [0, 1, 2]
  extraPerColumn = 1 / 3 = 0.33
  result = [133.33, 133.33, 133.33]
```

## 数据结构

### TableNode

```swift
public struct TableNode: Codable {
    public var rows: [TableRow]
}
```

### TableRow

```swift
public struct TableRow: Codable {
    public var cells: [TableCell]
}
```

### TableCell

```swift
public struct TableCell: Codable {
    public var children: [ASTNodeWrapper]
    public var align: Option<TextAlign>  // 可选的对齐方式
}
```

### NodeLayout

```swift
public class NodeLayout {
    public let frame: CGRect           // 布局框架
    public let children: [NodeLayout]  // 子布局（行包含单元格）
    public let node: ASTNodeWrapper?   // 关联的AST节点
    public let content: Any?           // 内容（如富文本）
    public let backgroundColor: UIColor?
    public let borderColor: UIColor?
    public let borderWidth: CGFloat
}
```

## 主题配置参数

表格布局依赖以下主题配置：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `toolbarHeight` | 工具栏高度 | - |
| `tableCellPadding` | 单元格内边距 | - |
| `tableMaxCellWidth` | 单元格最大宽度 | - |
| `tableMinCellWidth` | 单元格最小宽度 | - |
| `tableBorderColor` | 表格边框颜色 | - |

## 算法特点

### 1. 自适应性

- **列宽自适应**：根据内容自动调整列宽
- **空间利用**：充分利用可用宽度，避免浪费
- **边界保护**：确保不超出最小/最大宽度限制

### 2. 性能优化

- **分离计算**：列宽和行高分开计算，便于优化
- **快速路径**：纯文本单元格使用快速计算方法
- **精确计算**：包含附件的单元格使用精确布局管理器

### 3. 布局平衡

- **智能压缩**：防止单列过宽影响整体美观
- **比例拉伸**：空间充足时按比例分配，保持视觉平衡
- **统一行高**：同一行单元格高度一致，视觉整齐

### 4. 边界处理

- **最小宽度保护**：确保单元格不小于 `minCellWidth`
- **最大宽度限制**：防止单元格过宽
- **剩余空间分配**：合理分配剩余空间

## 算法复杂度

- **时间复杂度**：O(R × C × N)
  - R: 行数
  - C: 列数
  - N: 单元格平均子节点数
  
- **空间复杂度**：O(R × C)
  - 存储所有单元格的布局信息

## 使用示例

```swift
let tableNode = TableNode(rows: [
    TableRow(cells: [
        TableCell(children: [/* AST nodes */]),
        TableCell(children: [/* AST nodes */])
    ]),
    // ... more rows
])

let layout = UIKitFrameAsyncCalculator.calculateTableLayout(
    tableNode,
    context: renderContext,
    origin: CGPoint(x: 0, y: 0),
    width: 375
)

// layout.frame 包含表格的完整框架
// layout.children 包含所有行的布局
```

## 注意事项

1. **列数一致性**：算法假设所有行的列数相同，如果不同可能导致布局错误
2. **内容类型**：支持文本、图片、数学公式等多种内容类型
3. **异步计算**：该算法设计用于异步预计算，避免阻塞主线程
4. **内存管理**：富文本对象可能占用较多内存，注意及时释放

## 未来优化方向

1. **列对齐支持**：根据 `TableCell.align` 实现文本对齐
2. **合并单元格**：支持跨行跨列的单元格合并
3. **固定列宽**：支持用户指定固定列宽
4. **响应式布局**：根据屏幕方向动态调整布局
5. **缓存优化**：缓存列宽计算结果，避免重复计算

## 相关文档

- [UIKit布局系统与配置说明](../../../docs/UIKit布局系统与配置说明.md)
- [UIKit配置项快速参考表](../../../docs/UIKit配置项快速参考表.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)

