import SwiftUI
import WebKit

/// 渲染上下文
struct RenderContext {
    var theme: Theme
    var width: CGFloat
    var onLinkTap: ((URL) -> Void)?
    var onImageTap: ((ImageNode) -> Void)?
    var onMentionTap: ((MentionNode) -> Void)?
    // 当前文本样式（用于标题等需要特殊样式的场景）
    var currentFont: Font?
    var currentTextColor: Color?
}

/// 主题配置
struct Theme {
    var font: Font
    var fontSize: CGFloat  // 基础字体大小（用于计算标题大小）
    var codeFont: Font
    var textColor: Color
    var linkColor: Color
    var codeBackgroundColor: Color
    var codeTextColor: Color
    var headingColors: [Color]
    var paragraphSpacing: CGFloat
    var listItemSpacing: CGFloat
    var codeBlockPadding: CGFloat
    var codeBlockBorderRadius: CGFloat
    var tableCellPadding: CGFloat
    var tableBorderColor: Color
    var tableHeaderBackground: Color
    var blockquoteBorderWidth: CGFloat
    var blockquoteBorderColor: Color
    var blockquoteTextColor: Color
    var imageBorderRadius: CGFloat
    var imageMargin: CGFloat
    var mentionBackground: Color
    var mentionTextColor: Color
    var cardBackground: Color
    var cardBorderColor: Color
    var cardPadding: CGFloat
    var cardBorderRadius: CGFloat
    var hrColor: Color
    var lineHeight: CGFloat
    var maxContentWidth: CGFloat
    var contentPadding: CGFloat
}

extension Theme {
    /// 从 StyleConfig 创建 Theme
    init(from config: StyleConfig) {
        self.fontSize = CGFloat(config.fontSize)
        self.font = .system(size: self.fontSize)
        self.codeFont = .system(size: CGFloat(config.codeFontSize), design: .monospaced)
        self.textColor = Color(hex: config.textColor) ?? .primary
        self.linkColor = Color(hex: config.linkColor) ?? .blue
        self.codeBackgroundColor = Color(hex: config.codeBackgroundColor) ?? Color(white: 0.95)
        self.codeTextColor = Color(hex: config.codeTextColor) ?? .primary
        self.headingColors = config.headingColors.map { Color(hex: $0) ?? .primary }
        self.paragraphSpacing = CGFloat(config.paragraphSpacing)
        self.listItemSpacing = CGFloat(config.listItemSpacing)
        self.codeBlockPadding = CGFloat(config.codeBlockPadding)
        self.codeBlockBorderRadius = CGFloat(config.codeBlockBorderRadius)
        self.tableCellPadding = CGFloat(config.tableCellPadding)
        self.tableBorderColor = Color(hex: config.tableBorderColor) ?? Color.gray.opacity(0.3)
        self.tableHeaderBackground = Color(hex: config.tableHeaderBackground) ?? Color.gray.opacity(0.1)
        self.blockquoteBorderWidth = CGFloat(config.blockquoteBorderWidth)
        self.blockquoteBorderColor = Color(hex: config.blockquoteBorderColor) ?? Color.gray.opacity(0.3)
        self.blockquoteTextColor = Color(hex: config.blockquoteTextColor) ?? .secondary
        self.imageBorderRadius = CGFloat(config.imageBorderRadius)
        self.imageMargin = CGFloat(config.imageMargin)
        self.mentionBackground = Color(hex: config.mentionBackground) ?? Color.blue.opacity(0.1)
        self.mentionTextColor = Color(hex: config.mentionTextColor) ?? .blue
        self.cardBackground = Color(hex: config.cardBackground) ?? Color(white: 0.95)
        self.cardBorderColor = Color(hex: config.cardBorderColor) ?? Color.gray.opacity(0.3)
        self.cardPadding = CGFloat(config.cardPadding)
        self.cardBorderRadius = CGFloat(config.cardBorderRadius)
        self.hrColor = Color(hex: config.hrColor) ?? Color.gray.opacity(0.3)
        self.lineHeight = CGFloat(config.lineHeight)
        self.maxContentWidth = CGFloat(config.maxContentWidth)
        self.contentPadding = CGFloat(config.contentPadding)
    }
    
    /// 默认主题（从 StyleConfig.default() 创建）
    static var `default`: Theme {
        if let config = StyleConfig.default() {
            return Theme(from: config)
        }
        // 回退到硬编码值
        return Theme(
        font: .system(size: 16),
            fontSize: 16,
            codeFont: .system(size: 14, design: .monospaced),
        textColor: .primary,
        linkColor: .blue,
        codeBackgroundColor: Color(white: 0.95),
        codeTextColor: .primary,
            headingColors: [.primary, .primary, .primary, .primary, .primary, .primary],
            paragraphSpacing: 16,
            listItemSpacing: 8,
            codeBlockPadding: 16,
            codeBlockBorderRadius: 8,
            tableCellPadding: 8,
            tableBorderColor: Color.gray.opacity(0.3),
            tableHeaderBackground: Color.gray.opacity(0.1),
            blockquoteBorderWidth: 4,
            blockquoteBorderColor: Color.gray.opacity(0.3),
            blockquoteTextColor: .secondary,
            imageBorderRadius: 8,
            imageMargin: 16,
            mentionBackground: Color.blue.opacity(0.1),
            mentionTextColor: .blue,
            cardBackground: Color(white: 0.95),
            cardBorderColor: Color.gray.opacity(0.3),
            cardPadding: 16,
            cardBorderRadius: 8,
            hrColor: Color.gray.opacity(0.3),
            lineHeight: 1.6,
            maxContentWidth: 800,
            contentPadding: 20
        )
    }
}

/// AST 节点协议
protocol ASTNode {
    func render(context: RenderContext) -> AnyView
}

/// SwiftUI 渲染器
struct SwiftUIRenderer {
    func render(ast: RootNode, context: RenderContext) -> some View {
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
        case .listItem(let node):
            // ListItem 在 renderList 中处理
            return AnyView(EmptyView())
        case .table(let node):
            return AnyView(renderTable(node, context: context))
        case .tableRow(let node):
            // TableRow 在 renderTable 中处理
            return AnyView(EmptyView())
        case .tableCell(let node):
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
        case .horizontalRule(let node):
            return AnyView(renderHorizontalRule(context: context))
        }
    }
    
    @ViewBuilder
    private func renderParagraph(_ node: ParagraphNode, context: RenderContext) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { index, child in
                renderInlineNodeWrapper(child, context: context)
            }
            Spacer(minLength: 0)
        }
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
        
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { index, child in
                renderInlineNodeWrapper(child, context: headingContext)
            }
            Spacer(minLength: 0)
        }
    }
    
    /// 创建带标题样式的上下文
    private func createHeadingContext(from context: RenderContext, font: Font, color: Color) -> RenderContext {
        var headingContext = context
        headingContext.currentFont = font
        headingContext.currentTextColor = color
        return headingContext
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
    private func renderList(_ node: ListNode, context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: context.theme.listItemSpacing) {
            ForEach(Array(node.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    if case .bullet = node.listType {
                        Circle()
                            .fill(context.theme.textColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                    } else {
                        Text("\(index + 1).")
                            .font(context.theme.font)
                            .foregroundColor(context.theme.textColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                            renderInlineNodeWrapper(child, context: context)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderTable(_ node: TableNode, context: RenderContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(node.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { cellIndex, cell in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(cell.children.enumerated()), id: \.offset) { _, child in
                                renderInlineNodeWrapper(child, context: context)
                            }
                        }
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
        // 使用 SVG 渲染数学公式（从 Rust Core 获取 SVG）
        MathSVGView(mathContent: node.content, display: node.display, context: context)
            .padding(context.theme.codeBlockPadding)
            .background(context.theme.codeBackgroundColor)
            .cornerRadius(context.theme.codeBlockBorderRadius)
    }
    
    @ViewBuilder
    private func renderMermaid(_ node: MermaidNode, context: RenderContext) -> some View {
        // 使用 WebView 或 SVG 渲染 Mermaid
        Text("Mermaid: \(node.content)")
            .font(context.theme.codeFont)
            .foregroundColor(context.theme.codeTextColor)
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
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    renderInlineNodeWrapper(child, context: context)
                        .foregroundColor(context.theme.blockquoteTextColor)
                }
            }
        }
        .padding(.leading, 16)
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
        HStack(spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                renderInlineNodeWrapper(child, context: context)
            }
        }
        .fontWeight(.bold)
        // 如果当前有自定义字体，保持字体大小但应用粗体
        .font(context.currentFont != nil ? context.currentFont : nil)
        .foregroundColor(context.currentTextColor)
    }
    
    @ViewBuilder
    private func renderEm(_ node: EmNode, context: RenderContext) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                renderInlineNodeWrapper(child, context: context)
            }
        }
        .italic()
        // 如果当前有自定义字体，保持字体大小但应用斜体
        .font(context.currentFont != nil ? context.currentFont : nil)
        .foregroundColor(context.currentTextColor)
    }
    
    @ViewBuilder
    private func renderUnderline(_ node: UnderlineNode, context: RenderContext) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                renderInlineNodeWrapper(child, context: context)
            }
        }
        .underline()
        .font(context.currentFont)
        .foregroundColor(context.currentTextColor)
    }
    
    @ViewBuilder
    private func renderStrike(_ node: StrikeNode, context: RenderContext) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                renderInlineNodeWrapper(child, context: context)
            }
        }
        .strikethrough()
        .font(context.currentFont)
        .foregroundColor(context.currentTextColor)
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

// MARK: - Color 扩展（用于解析十六进制颜色）

extension Color {
    /// 从十六进制字符串创建 Color
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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

// MARK: - Math SVG View

/// 使用 SVG 渲染数学公式（从 Rust Core 获取 SVG）
struct MathSVGView: View {
    let mathContent: String
    let display: Bool
    let context: RenderContext
    @State private var svgString: String?
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: display ? .center : .leading)
            } else if isLoading {
                ProgressView()
                    .frame(height: display ? 60 : 30)
            } else {
                Text("数学公式渲染失败")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: display ? 60 : 30)
            }
        }
        .onAppear {
            print("数学公式："+mathContent)
            loadSVG()
        }
    }
    
    private func loadSVG() {
        // 从 Rust Core 获取 SVG
        let result = IMParseCore.mathToSVG(mathContent, display: display)
        if result.success, let svg = result.astJSON {
            self.svgString = svg
            // 将 SVG 转换为 UIImage（带缓存）
            self.image = MathSVGCache.shared.image(for: svg, size: CGSize(width: context.width, height: display ? 60 : 30))
        }
        self.isLoading = false
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
        // 使用 SwiftSVG 或 Core Graphics 渲染 SVG
        // 这里先使用占位符实现，后续需要集成 SwiftSVG
        return nil
    }
    
    func clearCache() {
        cacheQueue.async {
            self.cache.removeAll()
        }
    }
}

// MARK: - AST 节点类型定义（简化版，实际应从 Rust 绑定生成）

struct RootNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
    
    enum CodingKeys: String, CodingKey {
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // RootNode 直接包含 children，没有 type 字段
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
    }
    
    init(children: [ASTNodeWrapper]) {
        self.children = children
    }
}

struct ParagraphNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView()) // 由渲染器处理
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "paragraph" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'paragraph', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("paragraph", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct HeadingNode: ASTNode, Codable {
    var level: UInt8
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case level
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "heading" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'heading', got '\(typeString)'"
            ))
        }
        level = try container.decode(UInt8.self, forKey: .level)
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("heading", forKey: .type)
        try container.encode(level, forKey: .level)
        try container.encode(children, forKey: .children)
    }
}

struct TextNode: ASTNode, Codable {
    var content: String
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "text" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'text', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

struct StrongNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "strong" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'strong', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("strong", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct EmNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "em" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'em', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("em", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct UnderlineNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "underline" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'underline', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("underline", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct StrikeNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "strike" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'strike', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("strike", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct CodeNode: ASTNode, Codable {
    var content: String
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "code" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'code', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("code", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

struct CodeBlockNode: ASTNode, Codable {
    var language: String?
    var content: String
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case language
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "codeBlock" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'codeBlock', got '\(typeString)'"
            ))
        }
        language = try container.decodeIfPresent(String.self, forKey: .language)
        content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("codeBlock", forKey: .type)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(content, forKey: .content)
    }
}

struct LinkNode: ASTNode, Codable {
    var url: String
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "link" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'link', got '\(typeString)'"
            ))
        }
        url = try container.decode(String.self, forKey: .url)
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("link", forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encode(children, forKey: .children)
    }
}

struct ImageNode: ASTNode, Codable {
    var url: String
    var width: Float?
    var height: Float?
    var alt: String?
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case url
        case width
        case height
        case alt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "image" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'image', got '\(typeString)'"
            ))
        }
        url = try container.decode(String.self, forKey: .url)
        width = try container.decodeIfPresent(Float.self, forKey: .width)
        height = try container.decodeIfPresent(Float.self, forKey: .height)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("image", forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(alt, forKey: .alt)
    }
}

enum ListType: String, Codable {
    case bullet = "bullet"
    case ordered = "ordered"
}

struct ListItemNode: Codable {
    var children: [ASTNodeWrapper]
    var checked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case children
        case checked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ListItemNode 在 items 数组中时没有 type 字段，直接解码
        // 如果作为 ASTNode 枚举的一部分，ASTNodeWrapper 会处理 type 字段
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
        checked = try container.decodeIfPresent(Bool.self, forKey: .checked)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(checked, forKey: .checked)
    }
}

struct ListNode: ASTNode, Codable {
    var listType: ListType
    var items: [ListItemNode]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case listType
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "list" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'list', got '\(typeString)'"
            ))
        }
        listType = try container.decode(ListType.self, forKey: .listType)
        items = try container.decode([ListItemNode].self, forKey: .items)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("list", forKey: .type)
        try container.encode(listType, forKey: .listType)
        try container.encode(items, forKey: .items)
    }
}

struct TableNode: ASTNode, Codable {
    var rows: [TableRow]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case rows
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "table" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'table', got '\(typeString)'"
            ))
        }
        rows = try container.decode([TableRow].self, forKey: .rows)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("table", forKey: .type)
        try container.encode(rows, forKey: .rows)
    }
}

struct TableRow: Codable {
    var cells: [TableCell]
    
    enum CodingKeys: String, CodingKey {
        case cells
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // TableRow 直接包含 cells，没有 type 字段（因为它不是 ASTNode 枚举）
        cells = try container.decode([TableCell].self, forKey: .cells)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cells, forKey: .cells)
    }
}

struct TableCell: Codable {
    var children: [ASTNodeWrapper]
    var align: TextAlign?
    
    enum CodingKeys: String, CodingKey {
        case children
        case align
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // TableCell 直接包含 children 和 align，没有 type 字段（因为它不是 ASTNode 枚举）
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
        align = try container.decodeIfPresent(TextAlign.self, forKey: .align)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(align, forKey: .align)
    }
}

enum TextAlign: String, Codable {
    case left
    case center
    case right
}

struct MathNode: ASTNode, Codable {
    var content: String
    var display: Bool
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
        case display
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "math" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'math', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
        display = try container.decode(Bool.self, forKey: .display)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("math", forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(display, forKey: .display)
    }
}

struct MermaidNode: ASTNode, Codable {
    var content: String
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "mermaid" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'mermaid', got '\(typeString)'"
            ))
        }
        content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("mermaid", forKey: .type)
        try container.encode(content, forKey: .content)
    }
}

struct MentionNode: ASTNode, Codable {
    var id: String
    var name: String
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "mention" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'mention', got '\(typeString)'"
            ))
        }
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("mention", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

struct BlockquoteNode: ASTNode, Codable {
    var children: [ASTNodeWrapper]
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "blockquote" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'blockquote', got '\(typeString)'"
            ))
        }
        children = try container.decode([ASTNodeWrapper].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("blockquote", forKey: .type)
        try container.encode(children, forKey: .children)
    }
}

struct HorizontalRuleNode: ASTNode, Codable {
    func render(context: RenderContext) -> AnyView {
        AnyView(EmptyView())
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard typeString == "horizontalRule" else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected type 'horizontalRule', got '\(typeString)'"
            ))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("horizontalRule", forKey: .type)
    }
}

// MARK: - ASTNodeWrapper

/// ASTNode 包装器，用于 JSON 序列化/反序列化
enum ASTNodeWrapper: Codable {
    case root(RootNode)
    case paragraph(ParagraphNode)
    case heading(HeadingNode)
    case text(TextNode)
    case strong(StrongNode)
    case em(EmNode)
    case underline(UnderlineNode)
    case strike(StrikeNode)
    case code(CodeNode)
    case codeBlock(CodeBlockNode)
    case link(LinkNode)
    case image(ImageNode)
    case list(ListNode)
    case listItem(ListItemNode)
    case table(TableNode)
    case tableRow(TableRow)
    case tableCell(TableCell)
    case math(MathNode)
    case mermaid(MermaidNode)
    case mention(MentionNode)
    case blockquote(BlockquoteNode)
    case horizontalRule(HorizontalRuleNode)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        
        switch typeString {
        case "root":
            self = .root(try RootNode(from: decoder))
        case "paragraph":
            self = .paragraph(try ParagraphNode(from: decoder))
        case "heading":
            self = .heading(try HeadingNode(from: decoder))
        case "text":
            self = .text(try TextNode(from: decoder))
        case "strong":
            self = .strong(try StrongNode(from: decoder))
        case "em":
            self = .em(try EmNode(from: decoder))
        case "underline":
            self = .underline(try UnderlineNode(from: decoder))
        case "strike":
            self = .strike(try StrikeNode(from: decoder))
        case "code":
            self = .code(try CodeNode(from: decoder))
        case "codeBlock":
            self = .codeBlock(try CodeBlockNode(from: decoder))
        case "link":
            self = .link(try LinkNode(from: decoder))
        case "image":
            self = .image(try ImageNode(from: decoder))
        case "list":
            self = .list(try ListNode(from: decoder))
        case "listItem":
            self = .listItem(try ListItemNode(from: decoder))
        case "table":
            self = .table(try TableNode(from: decoder))
        case "tableRow":
            self = .tableRow(try TableRow(from: decoder))
        case "tableCell":
            self = .tableCell(try TableCell(from: decoder))
        case "math":
            self = .math(try MathNode(from: decoder))
        case "mermaid":
            self = .mermaid(try MermaidNode(from: decoder))
        case "mention":
            self = .mention(try MentionNode(from: decoder))
        case "blockquote":
            self = .blockquote(try BlockquoteNode(from: decoder))
        case "horizontalRule":
            self = .horizontalRule(try HorizontalRuleNode(from: decoder))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown node type: \(typeString)"
            ))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .root(let node):
            try node.encode(to: encoder)
        case .paragraph(let node):
            try node.encode(to: encoder)
        case .heading(let node):
            try node.encode(to: encoder)
        case .text(let node):
            try node.encode(to: encoder)
        case .strong(let node):
            try node.encode(to: encoder)
        case .em(let node):
            try node.encode(to: encoder)
        case .underline(let node):
            try node.encode(to: encoder)
        case .strike(let node):
            try node.encode(to: encoder)
        case .code(let node):
            try node.encode(to: encoder)
        case .codeBlock(let node):
            try node.encode(to: encoder)
        case .link(let node):
            try node.encode(to: encoder)
        case .image(let node):
            try node.encode(to: encoder)
        case .list(let node):
            try node.encode(to: encoder)
        case .listItem(let node):
            try node.encode(to: encoder)
        case .table(let node):
            try node.encode(to: encoder)
        case .tableRow(let node):
            try node.encode(to: encoder)
        case .tableCell(let node):
            try node.encode(to: encoder)
        case .math(let node):
            try node.encode(to: encoder)
        case .mermaid(let node):
            try node.encode(to: encoder)
        case .mention(let node):
            try node.encode(to: encoder)
        case .blockquote(let node):
            try node.encode(to: encoder)
        case .horizontalRule(let node):
            try node.encode(to: encoder)
        }
    }
    
    var asASTNode: ASTNode {
        switch self {
        case .root(let node):
            return node
        case .paragraph(let node):
            return node
        case .heading(let node):
            return node
        case .text(let node):
            return node
        case .strong(let node):
            return node
        case .em(let node):
            return node
        case .underline(let node):
            return node
        case .strike(let node):
            return node
        case .code(let node):
            return node
        case .codeBlock(let node):
            return node
        case .link(let node):
            return node
        case .image(let node):
            return node
        case .list(let node):
            return node
        case .listItem:
            // ListItemNode 不是 ASTNode，需要特殊处理
            fatalError("ListItemNode cannot be converted to ASTNode")
        case .table(let node):
            return node
        case .tableRow:
            // TableRow 不是 ASTNode
            fatalError("TableRow cannot be converted to ASTNode")
        case .tableCell:
            // TableCell 不是 ASTNode
            fatalError("TableCell cannot be converted to ASTNode")
        case .math(let node):
            return node
        case .mermaid(let node):
            return node
        case .mention(let node):
            return node
        case .blockquote(let node):
            return node
        case .horizontalRule(let node):
            return node
        }
    }
}

