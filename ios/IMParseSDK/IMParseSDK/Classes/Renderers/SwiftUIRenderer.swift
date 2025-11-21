import SwiftUI

/// SwiftUI 渲染器
public struct SwiftUIRenderer {
    public init() {}
    
    public func render(ast: RootNode, context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: context.theme.paragraphSpacing) {
            ForEach(Array(ast.children.enumerated()), id: \.offset) { index, child in
                renderNodeWrapper(child, context: context)
            }
        }
    }
    
    private func renderNodeWrapper(_ wrapper: ASTNodeWrapper, context: RenderContext) -> AnyView {
        switch wrapper {
        case .root(let node):
            // Root 节点不应该在子节点中出现，但为了安全起见还是处理一下
            return AnyView(
                VStack(alignment: .leading, spacing: context.theme.paragraphSpacing) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { index, child in
                        renderNodeWrapper(child, context: context)
                    }
                }
            )
        case .paragraph(let node):
            return AnyView(renderParagraph(node, context: context))
        case .heading(let node):
            return AnyView(renderHeading(node, context: context))
        case .text(let node):
            return AnyView(renderText(node, context: context))
        case .strong(let node):
            return AnyView(renderStrong(node, context: context))
        case .em(let node):
            return AnyView(renderEm(node, context: context))
        case .underline(let node):
            return AnyView(renderUnderline(node, context: context))
        case .strike(let node):
            return AnyView(renderStrike(node, context: context))
        case .code(let node):
            return AnyView(renderCode(node, context: context))
        case .codeBlock(let node):
            return AnyView(renderCodeBlock(node, context: context))
        case .link(let node):
            return AnyView(renderLink(node, context: context))
        case .image(let node):
            return AnyView(renderImage(node, context: context))
        case .list(let node):
            return AnyView(renderList(node, context: context))
        case .listItem(_):
            // ListItem 在 renderList 中处理
            return AnyView(EmptyView())
        case .table(let node):
            return AnyView(renderTable(node, context: context))
        case .tableRow(_):
            // TableRow 在 renderTable 中处理
            return AnyView(EmptyView())
        case .tableCell(_):
            // TableCell 在 renderTable 中处理
            return AnyView(EmptyView())
        case .math(let node):
            return AnyView(renderMath(node, context: context))
        case .mermaid(let node):
            return AnyView(renderMermaid(node, context: context))
        case .mention(let node):
            return AnyView(renderMention(node, context: context))
        case .blockquote(let node):
            return AnyView(renderBlockquote(node, context: context))
        case .horizontalRule(_):
            return AnyView(renderHorizontalRule(context: context))
        }
    }
    
    @ViewBuilder
    private func renderParagraph(_ node: ParagraphNode, context: RenderContext) -> some View {
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 AttributedString 中，不需要单独处理
        let hasSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            renderParagraphWithSpecialNodes(node, context: context)
        } else {
            // 否则使用组合的 Text 视图，支持正确换行
            buildText(from: node.children, context: context)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// 渲染包含特殊节点的段落（混合布局）
    @ViewBuilder
    private func renderParagraphWithSpecialNodes(_ node: ParagraphNode, context: RenderContext) -> some View {
        let groupedNodes = groupInlineNodes(node.children)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedNodes.enumerated()), id: \.offset) { index, group in
                switch group {
                case .textNodes(let nodes):
                    buildText(from: nodes, context: context)
                        .fixedSize(horizontal: false, vertical: true)
                case .specialNode(let node):
                    renderInlineNodeWrapper(node, context: context)
                }
            }
        }
    }
    
    /// 行内节点分组类型
    private enum InlineNodeGroup {
        case textNodes([ASTNodeWrapper])
        case specialNode(ASTNodeWrapper)
    }
    
    /// 将行内节点分组：连续的文本节点合并，特殊节点单独处理
    private func groupInlineNodes(_ nodes: [ASTNodeWrapper]) -> [InlineNodeGroup] {
        var result: [InlineNodeGroup] = []
        var currentTextNodes: [ASTNodeWrapper] = []
        
        for node in nodes {
            switch node {
            case .image, .math, .mermaid:
                // 行内代码现在可以嵌入到 AttributedString 中，不需要单独处理
                if !currentTextNodes.isEmpty {
                    result.append(.textNodes(currentTextNodes))
                    currentTextNodes.removeAll()
                }
                result.append(.specialNode(node))
            default:
                // 包括 .code，因为行内代码现在可以嵌入到 AttributedString 中
                currentTextNodes.append(node)
            }
        }
        
        if !currentTextNodes.isEmpty {
            result.append(.textNodes(currentTextNodes))
        }
        
        return result
    }
    
    /// 从行内节点构建组合的 Text 视图（使用 AttributedString）
    @ViewBuilder
    private func buildText(from nodes: [ASTNodeWrapper], context: RenderContext) -> some View {
        if #available(iOS 15.0, *) {
            // iOS 15+ 使用 AttributedString
            let attributedString = buildAttributedString(from: nodes, context: context)
            Text(attributedString)
        } else {
            // iOS 14 及以下使用旧的 Text 组合方式（降级处理）
            buildTextLegacy(from: nodes, context: context)
        }
    }
    
    /// 从行内节点构建 AttributedString（iOS 15+）
    @available(iOS 15.0, *)
    private func buildAttributedString(from nodes: [ASTNodeWrapper], context: RenderContext) -> AttributedString {
        var result = AttributedString()
        
        for node in nodes {
            let nodeString = buildAttributedString(from: node, context: context)
            result.append(nodeString)
        }
        
        return result
    }
    
    /// 从单个行内节点构建 AttributedString（iOS 15+）
    @available(iOS 15.0, *)
    private func buildAttributedString(from node: ASTNodeWrapper, context: RenderContext) -> AttributedString {
        switch node {
        case .text(let textNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            
            var attributedString = AttributedString(textNode.content)
            // AttributedString 可以直接使用 Font
            attributedString.font = font
            attributedString.foregroundColor = colorToSwiftUIColor(color)
            return attributedString
            
        case .strong(let strongNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            var result = AttributedString()
            
            for child in strongNode.children {
                var childString = buildAttributedString(from: child, context: context)
                // 应用粗体：使用 fontWeight
                // 注意：需要保留子节点中可能已经应用的斜体（obliqueness）属性
                let fontSize = getFontSize(from: font, context: context)
                
                // 检查并保留已有的 obliqueness 属性（来自嵌套的 em 节点）
                var existingObliqueness: Double? = nil
                for run in childString.runs {
                    if let obliqueness = run.obliqueness, obliqueness != 0 {
                        existingObliqueness = obliqueness
                        break
                    }
                }
                
                // 应用粗体字体
                childString.font = .system(size: fontSize, weight: .bold)
                
                // 如果有斜体属性，需要重新应用（因为设置 font 可能会覆盖）
                if let obliqueness = existingObliqueness {
                    var attributes = AttributeContainer()
                    attributes.obliqueness = obliqueness
                    childString.mergeAttributes(attributes)
                }
                childString.foregroundColor = colorToSwiftUIColor(color)
                result.append(childString)
            }
            return result
            
        case .em(let emNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            var result = AttributedString()
            
            for child in emNode.children {
                var childString = buildAttributedString(from: child, context: context)
                // 应用斜体：使用 obliqueness 属性实现斜体效果
                let fontSize = getFontSize(from: font, context: context)
                childString.font = .system(size: fontSize)
                // 使用 obliqueness 属性实现斜体效果
                var attributes = AttributeContainer()
                attributes.obliqueness = 0.2
                childString.mergeAttributes(attributes)
                childString.foregroundColor = colorToSwiftUIColor(color)
                result.append(childString)
            }
            return result
            
        case .underline(let underlineNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            var result = AttributedString()
            for child in underlineNode.children {
                var childString = buildAttributedString(from: child, context: context)
                childString.underlineStyle = .single
                let fontSize = getFontSize(from: font, context: context)
                childString.font = .system(size: fontSize)
                childString.foregroundColor = colorToSwiftUIColor(color)
                result.append(childString)
            }
            return result
            
        case .strike(let strikeNode):
            let font = context.currentFont ?? context.theme.font
            let color = context.currentTextColor ?? context.theme.textColor
            var result = AttributedString()
            for child in strikeNode.children {
                var childString = buildAttributedString(from: child, context: context)
                // 应用删除线：使用 strikethroughStyle 和 strikethroughColor
                var attributes = AttributeContainer()
                attributes.strikethroughStyle = .single
                // strikethroughColor 需要 UIColor 类型
                if let uiColor = colorToUIKitColor(color) {
                    attributes.strikethroughColor = uiColor
                }
                childString.mergeAttributes(attributes)
                let fontSize = getFontSize(from: font, context: context)
                childString.font = .system(size: fontSize)
                childString.foregroundColor = colorToSwiftUIColor(color)
                result.append(childString)
            }
            return result
            
        case .link(let linkNode):
            let font = context.currentFont ?? context.theme.font
            var result = AttributedString()
            for child in linkNode.children {
                var childString = buildAttributedString(from: child, context: context)
                childString.foregroundColor = colorToSwiftUIColor(context.theme.linkColor)
                let fontSize = getFontSize(from: font, context: context)
                childString.font = .system(size: fontSize)
                if let url = URL(string: linkNode.url) {
                    childString.link = url
                }
                result.append(childString)
            }
            return result
            
        case .code(let codeNode):
            // 行内代码：使用等宽字体和背景色
            var attributedString = AttributedString(codeNode.content)
            // 使用 codeFontSize，如果没有则使用默认值
            let fontSize = context.theme.fontSize * 0.875 // 通常代码字体稍小
            attributedString.font = .system(size: fontSize, design: .monospaced)
            attributedString.foregroundColor = colorToSwiftUIColor(context.theme.codeTextColor)
            attributedString.backgroundColor = colorToSwiftUIColor(context.theme.codeBackgroundColor)
            return attributedString
            
        default:
            // 对于其他类型（图片、数学公式、Mermaid、提及），返回空字符串
            // 这些节点会在 renderParagraphWithSpecialNodes 中单独处理
            return AttributedString()
        }
    }
    
    /// 从 Font 和 Context 获取字体大小（用于 AttributedString）
    @available(iOS 15.0, *)
    private func getFontSize(from font: Font, context: RenderContext) -> CGFloat {
        // 优先使用 context 中的 fontSize
        // 注意：Font 类型无法直接提取大小，所以使用 theme.fontSize
        return context.theme.fontSize
    }
    
    /// 将 Color 转换为 SwiftUI Color（AttributedString 直接支持 Color）
    @available(iOS 15.0, *)
    private func colorToSwiftUIColor(_ color: Color?) -> Color? {
        return color
    }
    
    /// 将 Color 转换为 UIColor（用于 AttributedString 的 UIKit 属性）
    @available(iOS 15.0, *)
    private func colorToUIKitColor(_ color: Color?) -> UIColor? {
        guard let color = color else { return nil }
        return UIColor(color)
    }
    
    /// 旧版 Text 组合方式（iOS 14 及以下降级处理）
    @ViewBuilder
    private func buildTextLegacy(from nodes: [ASTNodeWrapper], context: RenderContext) -> some View {
        // 简化的降级实现
        let text = nodes.compactMap { node -> String? in
            switch node {
            case .text(let textNode):
                return textNode.content
            default:
                return nil
            }
        }.joined()
        Text(text)
            .font(context.currentFont ?? context.theme.font)
            .foregroundColor(context.currentTextColor ?? context.theme.textColor)
    }
    
    @ViewBuilder
    private func renderHeading(_ node: HeadingNode, context: RenderContext) -> some View {
        // 使用与 HTML 渲染器相同的相对大小计算
        let baseFontSize = context.theme.fontSize
        let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9] // h1-h6
        let multiplier = headingMultipliers[min(Int(node.level) - 1, headingMultipliers.count - 1)]
        let fontSize = baseFontSize * multiplier
        
        // 使用 semi-bold (600)，与 HTML 渲染器一致
        let font = Font.system(size: fontSize, weight: .semibold)
        let color = context.theme.headingColors[min(Int(node.level) - 1, context.theme.headingColors.count - 1)]
        
        // 创建带标题样式的上下文（在视图构建之前完成）
        let headingContext = createHeadingContext(from: context, font: font, color: color)
        
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 AttributedString 中，不需要单独处理
        let hasSpecialNodes = node.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            renderHeadingWithSpecialNodes(node, context: headingContext)
        } else {
            // 否则使用组合的 Text 视图
            buildText(from: node.children, context: headingContext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// 渲染包含特殊节点的标题（混合布局）
    @ViewBuilder
    private func renderHeadingWithSpecialNodes(_ node: HeadingNode, context: RenderContext) -> some View {
        let groupedNodes = groupInlineNodes(node.children)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedNodes.enumerated()), id: \.offset) { index, group in
                switch group {
                case .textNodes(let nodes):
                    buildText(from: nodes, context: context)
                        .fixedSize(horizontal: false, vertical: true)
                case .specialNode(let node):
                    renderInlineNodeWrapper(node, context: context)
                }
            }
        }
    }
    
    /// 创建带标题样式的上下文
    private func createHeadingContext(from context: RenderContext, font: Font, color: Color) -> RenderContext {
        var headingContext = context
        headingContext.currentFont = font
        headingContext.currentTextColor = color
        return headingContext
    }
    
    /// 创建带引用块样式的上下文
    private func createBlockquoteContext(from context: RenderContext) -> RenderContext {
        var blockquoteContext = context
        blockquoteContext.currentTextColor = context.theme.blockquoteTextColor
        return blockquoteContext
    }
    
    @ViewBuilder
    private func renderCodeBlock(_ node: CodeBlockNode, context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(node.content)
                    .font(context.theme.codeFont)
                    .foregroundColor(context.theme.codeTextColor)
                    .padding(context.theme.codeBlockPadding)
            }
        }
        .background(context.theme.codeBackgroundColor)
        .cornerRadius(context.theme.codeBlockBorderRadius)
    }
    
    @ViewBuilder
    private func renderList(_ node: ListNode, context: RenderContext, nestingLevel: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: context.theme.listItemSpacing) {
            ForEach(Array(node.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    if case .bullet = node.listType {
                        // 嵌套无序列表使用空心圈，第一层使用实心圆
                        if nestingLevel > 0 {
                            Circle()
                                .stroke(context.theme.textColor, lineWidth: 1.5)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                        } else {
                            Circle()
                                .fill(context.theme.textColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                        }
                    } else {
                        // 嵌套有序列表使用小写罗马数字，第一层使用数字
                        if nestingLevel > 0 {
                            Text("\(toRomanNumeral(index + 1)).")
                                .font(context.theme.font)
                                .foregroundColor(context.theme.textColor)
                        } else {
                            Text("\(index + 1).")
                                .font(context.theme.font)
                                .foregroundColor(context.theme.textColor)
                        }
                    }
                    
                    // 列表项内容：检查是否包含嵌套列表
                    renderListItemContent(item: item, listType: node.listType, listIndex: index, context: context, nestingLevel: nestingLevel)
                }
            }
        }
    }
    
    /// 将数字转换为小写罗马数字
    private func toRomanNumeral(_ number: Int) -> String {
        // 超出范围直接返回数字
        guard number > 0 && number < 4000 else {
            return "\(number)"
        }
        
        let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        
        var result = ""
        var num = number
        
        for (index, value) in values.enumerated() {
            let count = num / value
            if count > 0 {
                result += String(repeating: numerals[index], count: count)
                num -= value * count
            }
        }
        
        return result
    }
    
    /// 渲染列表项内容
    @ViewBuilder
    private func renderListItemContent(item: ListItemNode, listType: ListType, listIndex: Int, context: RenderContext, nestingLevel: Int = 0) -> some View {
        // 检查是否包含嵌套列表
        let hasNestedList = item.children.contains { wrapper in
            if case .list = wrapper {
                return true
            }
            return false
        }
        
        if hasNestedList {
            // 如果包含嵌套列表，需要特殊处理：换行+缩进
            renderListItemWithNestedList(item: item, context: context, nestingLevel: nestingLevel)
        } else {
            // 没有嵌套列表，正常渲染行内节点
            renderListItemInlineContent(nodes: item.children, context: context)
        }
    }
    
    /// 渲染包含嵌套列表的列表项
    @ViewBuilder
    private func renderListItemWithNestedList(item: ListItemNode, context: RenderContext, nestingLevel: Int = 0) -> some View {
        // 先渲染非列表节点
        let nonListNodes = item.children.filter { wrapper in
            if case .list = wrapper {
                return false
            }
            return true
        }
        
        // 提取所有列表节点
        let listNodes: [ListNode] = item.children.compactMap { child in
            if case .list(let nestedListNode) = child {
                return nestedListNode
            }
            return nil
        }
        
        VStack(alignment: .leading, spacing: 0) {
            if !nonListNodes.isEmpty {
                renderListItemInlineContent(nodes: nonListNodes, context: context)
            }
            
            // 然后渲染嵌套列表（换行+缩进）
            ForEach(Array(listNodes.enumerated()), id: \.offset) { _, listNode in
                AnyView(renderList(listNode, context: context, nestingLevel: nestingLevel + 1))
                    .padding(.leading, 20) // 缩进
                    .padding(.top, context.theme.listItemSpacing) // 换行间距
            }
        }
    }
    
    /// 渲染列表项的行内内容
    @ViewBuilder
    private func renderListItemInlineContent(nodes: [ASTNodeWrapper], context: RenderContext) -> some View {
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 AttributedString 中，不需要单独处理
        let hasSpecialNodes = nodes.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            let groupedNodes = groupInlineNodes(nodes)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groupedNodes.enumerated()), id: \.offset) { index, group in
                    switch group {
                    case .textNodes(let textNodes):
                        buildText(from: textNodes, context: context)
                            .fixedSize(horizontal: false, vertical: true)
                    case .specialNode(let node):
                        renderInlineNodeWrapper(node, context: context)
                    }
                }
            }
        } else {
            // 否则使用 AttributedString 渲染，支持正确换行
            buildText(from: nodes, context: context)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func renderTable(_ node: TableNode, context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(node.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { cellIndex, cell in
                        // 表格单元格内容：使用 AttributedString 组合所有行内节点
                        renderTableCellContent(cell: cell, context: context)
                        .frame(maxWidth: .infinity, alignment: cell.align?.alignment ?? .leading)
                        .padding(context.theme.tableCellPadding)
                        .background(rowIndex == 0 ? context.theme.tableHeaderBackground : Color.clear)
                    }
                }
                Divider()
                    .background(context.theme.tableBorderColor)
            }
        }
        .overlay(
            Rectangle()
                .stroke(context.theme.tableBorderColor, lineWidth: 1)
        )
    }
    
    /// 渲染表格单元格内容
    @ViewBuilder
    private func renderTableCellContent(cell: TableCell, context: RenderContext) -> some View {
        // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
        // 行内代码现在可以嵌入到 AttributedString 中，不需要单独处理
        let hasSpecialNodes = cell.children.contains { wrapper in
            switch wrapper {
            case .image, .math, .mermaid:
                return true
            default:
                return false
            }
        }
        
        if hasSpecialNodes {
            // 如果包含特殊节点，使用混合布局
            let groupedNodes = groupInlineNodes(cell.children)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groupedNodes.enumerated()), id: \.offset) { index, group in
                    switch group {
                    case .textNodes(let nodes):
                        buildText(from: nodes, context: context)
                            .fixedSize(horizontal: false, vertical: true)
                    case .specialNode(let node):
                        renderInlineNodeWrapper(node, context: context)
                    }
                }
            }
        } else {
            // 否则使用 AttributedString 渲染，支持正确换行
            buildText(from: cell.children, context: context)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func renderImage(_ node: ImageNode, context: RenderContext) -> some View {
        if let url = URL(string: node.url) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    VStack {
                        ProgressView()
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: min(context.width, 300), height: min(context.width * 0.75, 225))
                    .background(context.theme.codeBackgroundColor)
                    .cornerRadius(context.theme.imageBorderRadius)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: node.width != nil ? CGFloat(node.width!) : context.width,
                               maxHeight: node.height != nil ? CGFloat(node.height!) : nil)
                        .cornerRadius(context.theme.imageBorderRadius)
                        .padding(.vertical, context.theme.imageMargin)
                        .onTapGesture {
                            context.onImageTap?(node)
                        }
                case .failure(let error):
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("图片加载失败")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let error = error as? URLError {
                            Text(error.localizedDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(width: min(context.width, 300), height: 100)
                    .background(context.theme.codeBackgroundColor)
                    .cornerRadius(context.theme.imageBorderRadius)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            // URL 无效
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("无效的图片 URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: min(context.width, 300), height: 100)
            .background(context.theme.codeBackgroundColor)
            .cornerRadius(context.theme.imageBorderRadius)
        }
    }
    
    @ViewBuilder
    private func renderMath(_ node: MathNode, context: RenderContext) -> some View {
        // 使用 HTML 渲染数学公式（从 Rust Core 获取 HTML，然后渲染为图片）
        MathSVGView(mathContent: node.content, display: node.display, context: context)
            .padding(context.theme.codeBlockPadding)
            .background(context.theme.codeBackgroundColor)
            .cornerRadius(context.theme.codeBlockBorderRadius)
    }
    
    @ViewBuilder
    private func renderMermaid(_ node: MermaidNode, context: RenderContext) -> some View {
        // 使用 HTML 渲染 Mermaid 图表（使用 MermaidHTMLRenderer 渲染为图片）
        MermaidSVGView(mermaidContent: node.content, context: context)
            .padding(context.theme.codeBlockPadding)
            .background(context.theme.codeBackgroundColor)
            .cornerRadius(context.theme.codeBlockBorderRadius)
    }
    
    @ViewBuilder
    private func renderLink(_ node: LinkNode, context: RenderContext) -> some View {
        if let url = URL(string: node.url) {
            Link(destination: url) {
                HStack(spacing: 0) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                        renderInlineNodeWrapper(child, context: context)
                    }
                }
                .foregroundColor(context.currentTextColor ?? context.theme.linkColor)
                .font(context.currentFont)
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    renderInlineNodeWrapper(child, context: context)
                }
            }
            .font(context.currentFont)
            .foregroundColor(context.currentTextColor)
        }
    }
    
    @ViewBuilder
    private func renderMention(_ node: MentionNode, context: RenderContext) -> some View {
        Text("@\(node.name)")
            .font(context.theme.font)
            .foregroundColor(context.theme.mentionTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(context.theme.mentionBackground)
            .cornerRadius(4)
            .onTapGesture {
                context.onMentionTap?(node)
            }
    }
    
    @ViewBuilder
    private func renderBlockquote(_ node: BlockquoteNode, context: RenderContext) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(context.theme.blockquoteBorderColor)
                .frame(width: context.theme.blockquoteBorderWidth)
            
            // 引用块内容：使用 AttributedString 组合所有行内节点
            renderBlockquoteContent(node: node, context: context)
        }
        .padding(.leading, 16)
    }
    
    /// 渲染引用块内容
    @ViewBuilder
    private func renderBlockquoteContent(node: BlockquoteNode, context: RenderContext) -> some View {
        // 创建带引用块文本颜色的上下文（在 ViewBuilder 外部创建）
        let blockquoteContext = createBlockquoteContext(from: context)
        
        // 检查是否包含块级节点（段落、列表、代码块、标题等）
        let hasBlockLevelNodes = node.children.contains { wrapper in
            switch wrapper {
            case .paragraph, .heading, .codeBlock, .list, .table, .blockquote, .horizontalRule:
                return true
            default:
                return false
            }
        }
        
        if hasBlockLevelNodes {
            // 如果包含块级节点，使用块级渲染
            VStack(alignment: .leading, spacing: blockquoteContext.theme.paragraphSpacing) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { index, child in
                    renderNodeWrapper(child, context: blockquoteContext)
                }
            }
        } else {
            // 否则作为行内内容处理
            // 检查是否包含需要单独渲染的节点（图片、数学公式、Mermaid、提及）
            let hasSpecialNodes = node.children.contains { wrapper in
                switch wrapper {
                case .image, .math, .mermaid:
                    return true
                default:
                    return false
                }
            }
            
            if hasSpecialNodes {
                // 如果包含特殊节点，使用混合布局
                let groupedNodes = groupInlineNodes(node.children)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groupedNodes.enumerated()), id: \.offset) { index, group in
                        switch group {
                        case .textNodes(let nodes):
                            buildText(from: nodes, context: blockquoteContext)
                                .fixedSize(horizontal: false, vertical: true)
                        case .specialNode(let node):
                            renderInlineNodeWrapper(node, context: blockquoteContext)
                        }
                    }
                }
            } else {
                // 否则使用 AttributedString 渲染，支持正确换行
                buildText(from: node.children, context: blockquoteContext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private func renderHorizontalRule(context: RenderContext) -> some View {
        Divider()
            .background(context.theme.hrColor)
            .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func renderText(_ node: TextNode, context: RenderContext) -> some View {
        Text(node.content)
            .font(context.currentFont ?? context.theme.font)
            .foregroundColor(context.currentTextColor ?? context.theme.textColor)
    }
    
    @ViewBuilder
    private func renderStrong(_ node: StrongNode, context: RenderContext) -> some View {
        if #available(iOS 16.0, *) {
            HStack(spacing: 0) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    renderInlineNodeWrapper(child, context: context)
                }
            }
            .fontWeight(.bold)
            // 如果当前有自定义字体，保持字体大小但应用粗体
            .font(context.currentFont != nil ? context.currentFont : nil)
            .foregroundColor(context.currentTextColor)
        } else {
            // Fallback on earlier versions
        }
    }
    
    @ViewBuilder
    private func renderEm(_ node: EmNode, context: RenderContext) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                renderInlineNodeWrapper(child, context: context)
            }
        }
        .font(context.currentFont != nil ? context.currentFont : nil)
        .foregroundColor(context.currentTextColor)
        // 使用仿射变换实现斜体效果，对中英文都有效
        // 倾斜角度约为 -12 度（约 -0.21 弧度），这是标准的斜体倾斜角度
        // 在变换中添加水平偏移补偿，避免与后续文本重叠
        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.21, d: 1, tx: 2.5, ty: 0))
    }
    
    @ViewBuilder
    private func renderUnderline(_ node: UnderlineNode, context: RenderContext) -> some View {
        if #available(iOS 16.0, *) {
            HStack(spacing: 0) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    renderInlineNodeWrapper(child, context: context)
                }
            }
            .underline()
            .font(context.currentFont)
            .foregroundColor(context.currentTextColor)
        } else {
            // Fallback on earlier versions
        }
    }
    
    @ViewBuilder
    private func renderStrike(_ node: StrikeNode, context: RenderContext) -> some View {
        if #available(iOS 16.0, *) {
            HStack(spacing: 0) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    renderInlineNodeWrapper(child, context: context)
                }
            }
            .strikethrough()
            .font(context.currentFont)
            .foregroundColor(context.currentTextColor)
        } else {
            // Fallback on earlier versions
        }
    }
    
    @ViewBuilder
    private func renderCode(_ node: CodeNode, context: RenderContext) -> some View {
        Text(node.content)
            .font(context.theme.codeFont)
            .foregroundColor(context.theme.codeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(context.theme.codeBackgroundColor)
            .cornerRadius(3)
    }
    
    private func renderInlineNodeWrapper(_ wrapper: ASTNodeWrapper, context: RenderContext) -> AnyView {
        switch wrapper {
        case .text(let node):
            return AnyView(renderText(node, context: context))
        case .strong(let node):
            return AnyView(renderStrong(node, context: context))
        case .em(let node):
            return AnyView(renderEm(node, context: context))
        case .underline(let node):
            return AnyView(renderUnderline(node, context: context))
        case .strike(let node):
            return AnyView(renderStrike(node, context: context))
        case .code(let node):
            return AnyView(renderCode(node, context: context))
        case .link(let node):
            return AnyView(renderLink(node, context: context))
        case .mention(let node):
            return AnyView(renderMention(node, context: context))
        case .math(let node):
            // 行内数学公式
            return AnyView(renderMath(node, context: context))
        default:
            // 其他类型不应该出现在行内节点中
            return AnyView(EmptyView())
        }
    }
}

// MARK: - 辅助扩展

extension TextAlign {
    var alignment: Alignment {
        switch self {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

// MARK: - Math HTML View

/// 数学公式 HTML 渲染视图（使用 WebView 渲染为图片）
/// 从 Rust Core 获取 KaTeX HTML，然后使用 MathHTMLRenderer 渲染为图片
struct MathSVGView: View {
    let mathContent: String
    let display: Bool
    let context: RenderContext
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: context.width, alignment: display ? .center : .leading)
            } else if isLoading {
                ProgressView()
                    .frame(height: display ? 60 : 30)
            } else {
                // 回退：显示原始 LaTeX
                Text(mathContent)
                    .font(.system(size: display ? 16 : 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: context.width, alignment: display ? .center : .leading)
            }
        }
        .onAppear {
            loadMathHTML()
        }
    }
    
    private func loadMathHTML() {
        // 从 Rust Core 获取 KaTeX HTML
        let result = IMParseCore.mathToHTML(mathContent, display: display)
        
        guard result.success, let html = result.astJSON else {
            self.isLoading = false
            return
        }
        
        // 获取文本颜色
        let textColor = UIColor(context.theme.textColor)
        let components = textColor.cgColor.components ?? [0, 0, 0, 1]
        let colorHex = String(format: "#%02X%02X%02X",
            Int(components[0] * 255),
            Int(components[1] * 255),
            Int(components[2] * 255)
        )
        
        // 使用 MathHTMLRenderer 渲染为图片
        let fontSize = display ? 16.0 : 14.0
        MathHTMLRenderer.shared.render(
            html: html,
            display: display,
            textColor: colorHex,
            fontSize: fontSize
        ) { image in
            DispatchQueue.main.async {
                self.renderedImage = image
                self.isLoading = false
            }
        }
    }
}

/// Mermaid 图表 HTML 渲染视图（使用 WebView 渲染为图片）
/// 使用 MermaidHTMLRenderer 将 Mermaid 代码渲染为图片
struct MermaidSVGView: View {
    let mermaidContent: String
    let context: RenderContext
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: context.width, alignment: .center)
            } else if isLoading {
                ProgressView()
                    .frame(height: 300)
            } else {
                // 回退：显示原始 Mermaid 代码
                Text(mermaidContent)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: context.width, alignment: .center)
            }
        }
        .onAppear {
            loadMermaidHTML()
        }
    }
    
    private func loadMermaidHTML() {
        // 获取文本颜色和背景颜色
        let textColor = UIColor(context.theme.textColor)
        let backgroundColor = UIColor(context.theme.codeBackgroundColor)
        
        let textComponents = textColor.cgColor.components ?? [0, 0, 0, 1]
        let textColorHex = String(format: "#%02X%02X%02X",
            Int(textComponents[0] * 255),
            Int(textComponents[1] * 255),
            Int(textComponents[2] * 255)
        )
        
        let bgComponents = backgroundColor.cgColor.components ?? [1, 1, 1, 1]
        let backgroundColorHex = String(format: "#%02X%02X%02X",
            Int(bgComponents[0] * 255),
            Int(bgComponents[1] * 255),
            Int(bgComponents[2] * 255)
        )
        
        // 使用 MermaidHTMLRenderer 渲染为图片
        MermaidHTMLRenderer.shared.render(
            mermaidCode: mermaidContent,
            textColor: textColorHex,
            backgroundColor: backgroundColorHex
        ) { image in
            DispatchQueue.main.async {
                self.renderedImage = image
                self.isLoading = false
            }
        }
    }
}

/// SVG 缓存管理器
class MathSVGCache {
    static let shared = MathSVGCache()
    private var cache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "math.svg.cache")
    
    private init() {}
    
    func image(for svg: String, size: CGSize) -> UIImage? {
        let key = "\(svg.hashValue)_\(size.width)_\(size.height)"
        
        return cacheQueue.sync {
            if let cached = cache[key] {
                return cached
            }
            
            // 将 SVG 转换为 UIImage
            if let image = renderSVG(svg, size: size) {
                cache[key] = image
                return image
            }
            
            return nil
        }
    }
    
    private func renderSVG(_ svg: String, size: CGSize) -> UIImage? {
        // 提取数学公式内容（从 SVG 中）
        guard let mathContent = extractMathFromSVG(svg) else {
            return renderPlaceholderImage(text: "[Math]", size: size)
        }
        
        // 渲染为纯文本图片
        return renderPlaceholderImage(text: mathContent, size: size)
    }
    
    private func extractMathFromSVG(_ svg: String) -> String? {
        // 简单提取：查找 SVG 中的文本内容
        // 这只是临时方案，无法正确渲染复杂公式
        if let range = svg.range(of: "class=\"katex\"") {
            // 这是一个非常简化的实现
            return nil
        }
        return nil
    }
    
    private func renderPlaceholderImage(text: String, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // 绘制背景
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 绘制文本
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedText.draw(in: textRect)
        }
    }
    
    func clearCache() {
        cacheQueue.async {
            self.cache.removeAll()
        }
    }
}
