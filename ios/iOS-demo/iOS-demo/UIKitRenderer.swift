//
//  UIKitRenderer.swift
//  IMParseDemo
//
//  UIKit 版本的 AST 渲染器
//

import UIKit
import WebKit

/// UIKit 渲染上下文
struct UIKitRenderContext {
    var theme: UIKitTheme
    var width: CGFloat
    var onLinkTap: ((URL) -> Void)?
    var onImageTap: ((ImageNode) -> Void)?
    var onMentionTap: ((MentionNode) -> Void)?
    // 当前文本样式（用于标题等需要特殊样式的场景）
    var currentFont: UIFont?
    var currentTextColor: UIColor?
}

/// UIKit 主题配置
struct UIKitTheme {
    var font: UIFont
    var fontSize: CGFloat  // 基础字体大小（用于计算标题大小）
    var codeFont: UIFont
    var textColor: UIColor
    var linkColor: UIColor
    var codeBackgroundColor: UIColor
    var codeTextColor: UIColor
    var headingColors: [UIColor]
    var paragraphSpacing: CGFloat
    var listItemSpacing: CGFloat
    var codeBlockPadding: CGFloat
    var codeBlockBorderRadius: CGFloat
    var tableCellPadding: CGFloat
    var tableBorderColor: UIColor
    var tableHeaderBackground: UIColor
    var blockquoteBorderWidth: CGFloat
    var blockquoteBorderColor: UIColor
    var blockquoteTextColor: UIColor
    var imageBorderRadius: CGFloat
    var imageMargin: CGFloat
    var mentionBackground: UIColor
    var mentionTextColor: UIColor
    var cardBackground: UIColor
    var cardBorderColor: UIColor
    var cardPadding: CGFloat
    var cardBorderRadius: CGFloat
    var hrColor: UIColor
    var lineHeight: CGFloat
    var maxContentWidth: CGFloat
    var contentPadding: CGFloat
}

extension UIKitTheme {
    /// 从 StyleConfig 创建 UIKitTheme
    init(from config: StyleConfig) {
        self.fontSize = CGFloat(config.fontSize)
        self.font = .systemFont(ofSize: self.fontSize)
        self.codeFont = .monospacedSystemFont(ofSize: CGFloat(config.codeFontSize), weight: .regular)
        self.textColor = UIColor(hex: config.textColor) ?? .label
        self.linkColor = UIColor(hex: config.linkColor) ?? .systemBlue
        self.codeBackgroundColor = UIColor(hex: config.codeBackgroundColor) ?? UIColor(white: 0.95, alpha: 1.0)
        self.codeTextColor = UIColor(hex: config.codeTextColor) ?? .label
        self.headingColors = config.headingColors.map { UIColor(hex: $0) ?? .label }
        self.paragraphSpacing = CGFloat(config.paragraphSpacing)
        self.listItemSpacing = CGFloat(config.listItemSpacing)
        self.codeBlockPadding = CGFloat(config.codeBlockPadding)
        self.codeBlockBorderRadius = CGFloat(config.codeBlockBorderRadius)
        self.tableCellPadding = CGFloat(config.tableCellPadding)
        self.tableBorderColor = UIColor(hex: config.tableBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.tableHeaderBackground = UIColor(hex: config.tableHeaderBackground) ?? UIColor.gray.withAlphaComponent(0.1)
        self.blockquoteBorderWidth = CGFloat(config.blockquoteBorderWidth)
        self.blockquoteBorderColor = UIColor(hex: config.blockquoteBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.blockquoteTextColor = UIColor(hex: config.blockquoteTextColor) ?? .secondaryLabel
        self.imageBorderRadius = CGFloat(config.imageBorderRadius)
        self.imageMargin = CGFloat(config.imageMargin)
        self.mentionBackground = UIColor(hex: config.mentionBackground) ?? UIColor.systemBlue.withAlphaComponent(0.1)
        self.mentionTextColor = UIColor(hex: config.mentionTextColor) ?? .systemBlue
        self.cardBackground = UIColor(hex: config.cardBackground) ?? UIColor.systemGray6
        self.cardBorderColor = UIColor(hex: config.cardBorderColor) ?? UIColor.gray.withAlphaComponent(0.3)
        self.cardPadding = CGFloat(config.cardPadding)
        self.cardBorderRadius = CGFloat(config.cardBorderRadius)
        self.hrColor = UIColor(hex: config.hrColor) ?? .separator
        self.lineHeight = CGFloat(config.lineHeight)
        self.maxContentWidth = CGFloat(config.maxContentWidth)
        self.contentPadding = CGFloat(config.contentPadding)
    }
    
    /// 默认主题（从 StyleConfig.default() 创建）
    static var `default`: UIKitTheme {
        if let config = StyleConfig.default() {
            return UIKitTheme(from: config)
        }
        // 回退到硬编码值
        return UIKitTheme(
        font: .systemFont(ofSize: 16),
            fontSize: 16,
            codeFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
        textColor: .label,
        linkColor: .systemBlue,
        codeBackgroundColor: UIColor(white: 0.95, alpha: 1.0),
        codeTextColor: .label,
            headingColors: [.label, .label, .label, .label, .label, .label],
            paragraphSpacing: 16,
            listItemSpacing: 8,
            codeBlockPadding: 16,
            codeBlockBorderRadius: 8,
            tableCellPadding: 8,
            tableBorderColor: UIColor.gray.withAlphaComponent(0.3),
            tableHeaderBackground: UIColor.gray.withAlphaComponent(0.1),
            blockquoteBorderWidth: 4,
            blockquoteBorderColor: UIColor.gray.withAlphaComponent(0.3),
            blockquoteTextColor: .secondaryLabel,
            imageBorderRadius: 8,
            imageMargin: 16,
            mentionBackground: UIColor.systemBlue.withAlphaComponent(0.1),
            mentionTextColor: .systemBlue,
            cardBackground: UIColor.systemGray6,
            cardBorderColor: UIColor.gray.withAlphaComponent(0.3),
            cardPadding: 16,
            cardBorderRadius: 8,
            hrColor: .separator,
            lineHeight: 1.6,
            maxContentWidth: 800,
            contentPadding: 20
        )
    }
}

/// UIKit AST 渲染器
class UIKitRenderer {
    
    /// 渲染 AST 根节点
    func render(ast: RootNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .leading
        containerView.spacing = context.theme.paragraphSpacing
        containerView.distribution = .fill
        
        for child in ast.children {
            let childView = renderNodeWrapper(child, context: context)
            containerView.addArrangedSubview(childView)
        }
        
        return containerView
    }
    
    /// 渲染节点包装器
    private func renderNodeWrapper(_ wrapper: ASTNodeWrapper, context: UIKitRenderContext) -> UIView {
        switch wrapper {
        case .root(let node):
            // Root 节点不应该在子节点中出现，但为了安全起见还是处理一下
            let containerView = UIStackView()
            containerView.axis = .vertical
            containerView.alignment = .leading
            containerView.spacing = context.theme.paragraphSpacing
            containerView.distribution = .fill
            
            for child in node.children {
                let childView = renderNodeWrapper(child, context: context)
                containerView.addArrangedSubview(childView)
            }
            return containerView
            
        case .paragraph(let node):
            return renderParagraph(node, context: context)
        case .heading(let node):
            return renderHeading(node, context: context)
        case .text(let node):
            return renderText(node, context: context)
        case .strong(let node):
            return renderStrong(node, context: context)
        case .em(let node):
            return renderEm(node, context: context)
        case .underline(let node):
            return renderUnderline(node, context: context)
        case .strike(let node):
            return renderStrike(node, context: context)
        case .code(let node):
            return renderCode(node, context: context)
        case .codeBlock(let node):
            return renderCodeBlock(node, context: context)
        case .link(let node):
            return renderLink(node, context: context)
        case .image(let node):
            return renderImage(node, context: context)
        case .list(let node):
            return renderList(node, context: context)
        case .listItem(let node):
            // ListItem 在 renderList 中处理
            return UIView()
        case .table(let node):
            return renderTable(node, context: context)
        case .tableRow(let node):
            // TableRow 在 renderTable 中处理
            return UIView()
        case .tableCell(let node):
            // TableCell 在 renderTable 中处理
            return UIView()
        case .math(let node):
            return renderMath(node, context: context)
        case .mermaid(let node):
            return renderMermaid(node, context: context)
        case .mention(let node):
            return renderMention(node, context: context)
        case .blockquote(let node):
            return renderBlockquote(node, context: context)
        case .horizontalRule(let node):
            return renderHorizontalRule(context: context)
        }
    }
    
    /// 渲染段落
    private func renderParagraph(_ node: ParagraphNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            stackView.addArrangedSubview(childView)
        }
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
        
        return stackView
    }
    
    /// 渲染标题
    private func renderHeading(_ node: HeadingNode, context: UIKitRenderContext) -> UIView {
        // 使用与 HTML 渲染器相同的相对大小计算
        let baseFontSize = context.theme.fontSize
        let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9] // h1-h6
        let multiplier = headingMultipliers[min(Int(node.level) - 1, headingMultipliers.count - 1)]
        let fontSize = baseFontSize * multiplier
        
        // 使用 semi-bold (600)，与 HTML 渲染器一致
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let color = context.theme.headingColors[min(Int(node.level) - 1, context.theme.headingColors.count - 1)]
        
        // 创建带标题样式的上下文，让子节点使用标题的字体和颜色
        var headingContext = context
        headingContext.currentFont = font
        headingContext.currentTextColor = color
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: headingContext)
            // 递归设置所有子视图的字体和颜色
            applyFontAndColor(to: childView, font: font, color: color)
            stackView.addArrangedSubview(childView)
        }
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
        
        return stackView
    }
    
    /// 递归应用字体和颜色到视图及其子视图
    private func applyFontAndColor(to view: UIView, font: UIFont, color: UIColor) {
        if let label = view as? UILabel {
            label.font = font
            label.textColor = color
        }
        
        // 递归处理子视图
        for subview in view.subviews {
            applyFontAndColor(to: subview, font: font, color: color)
        }
        
        // 处理 UIStackView 的 arrangedSubviews
        if let stackView = view as? UIStackView {
            for arrangedSubview in stackView.arrangedSubviews {
                applyFontAndColor(to: arrangedSubview, font: font, color: color)
            }
        }
    }
    
    /// 渲染文本
    private func renderText(_ node: TextNode, context: UIKitRenderContext) -> UILabel {
        let label = UILabel()
        label.text = node.content
        label.font = context.currentFont ?? context.theme.font
        label.textColor = context.currentTextColor ?? context.theme.textColor
        label.numberOfLines = 0
        return label
    }
    
    /// 渲染粗体
    private func renderStrong(_ node: StrongNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.font = UIFont.boldSystemFont(ofSize: context.theme.font.pointSize)
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染斜体
    private func renderEm(_ node: EmNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                let descriptor = context.theme.font.fontDescriptor.withSymbolicTraits(.traitItalic)
                label.font = UIFont(descriptor: descriptor ?? context.theme.font.fontDescriptor, size: context.theme.font.pointSize)
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染下划线
    private func renderUnderline(_ node: UnderlineNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.attributedText = NSAttributedString(
                    string: label.text ?? "",
                    attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
                )
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染删除线
    private func renderStrike(_ node: StrikeNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.attributedText = NSAttributedString(
                    string: label.text ?? "",
                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
                )
            }
            stackView.addArrangedSubview(childView)
        }
        return stackView
    }
    
    /// 渲染行内代码
    private func renderCode(_ node: CodeNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = 3
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
        ])
        
        return containerView
    }
    
    /// 渲染代码块
    private func renderCodeBlock(_ node: CodeBlockNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = node.content
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        
        let padding = context.theme.codeBlockPadding
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
        ])
        
        return containerView
    }
    
    /// 渲染链接
    private func renderLink(_ node: LinkNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            if let label = childView as? UILabel {
                label.textColor = context.theme.linkColor
            }
            stackView.addArrangedSubview(childView)
        }
        
        // 添加点击手势
        if let url = URL(string: node.url) {
            let tapGesture = UITapGestureRecognizer(target: nil, action: nil)
            tapGesture.addTarget(self, action: #selector(handleLinkTap(_:)))
            stackView.addGestureRecognizer(tapGesture)
            stackView.isUserInteractionEnabled = true
            objc_setAssociatedObject(stackView, &AssociatedKeys.url, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stackView
    }
    
    @objc private func handleLinkTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view,
              let url = objc_getAssociatedObject(view, &AssociatedKeys.url) as? URL else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    /// 渲染图片
    private func renderImage(_ node: ImageNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.systemGray6
        
        // 添加加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        // 设置加载指示器约束
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // 设置图片约束
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 设置容器约束
        if let width = node.width, let height = node.height {
            // 如果指定了尺寸，使用固定尺寸
            containerView.widthAnchor.constraint(equalToConstant: CGFloat(width)).isActive = true
            containerView.heightAnchor.constraint(equalToConstant: CGFloat(height)).isActive = true
        } else {
            // 如果没有指定尺寸，设置最大宽度，高度根据宽高比自适应
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: context.width).isActive = true
            // 设置默认宽高比约束（4:3），图片加载后会更新
            let defaultAspectRatio = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 4.0/3.0)
            defaultAspectRatio.priority = UILayoutPriority(750)
            defaultAspectRatio.isActive = true
            
            // 设置最小高度，避免容器高度为0
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        }
        
        // 加载图片
        guard let url = URL(string: node.url) else {
            // URL 无效，显示错误
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.showImageError(in: containerView, message: "无效的图片 URL")
            }
            return containerView
        }
        
        // 使用 URLSession 加载图片
        let task = URLSession.shared.dataTask(with: url) { [weak imageView, weak containerView, weak activityIndicator] data, response, error in
            DispatchQueue.main.async {
                activityIndicator?.stopAnimating()
                activityIndicator?.removeFromSuperview()
                
                guard let containerView = containerView,
                      let imageView = imageView else { return }
                
                if let error = error {
                    print("图片加载错误: \(error.localizedDescription)")
                    self.showImageError(in: containerView, message: "加载失败")
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("无法解析图片数据")
                    self.showImageError(in: containerView, message: "无法解析图片")
                    return
                }
                
                // 图片加载成功
                imageView.image = image
                
                // 如果图片加载成功且没有指定尺寸，更新宽高比约束
                if node.width == nil || node.height == nil {
                    let imageAspectRatio = image.size.width / image.size.height
                    guard imageAspectRatio > 0 && imageAspectRatio.isFinite else {
                        return
                    }
                    
                    // 移除旧的宽高比约束
                    imageView.constraints.forEach { constraint in
                        if constraint.firstAttribute == .width && 
                           constraint.secondAttribute == .height &&
                           constraint.priority.rawValue < 1000 {
                            constraint.isActive = false
                        }
                    }
                    
                    // 添加新的宽高比约束
                    let aspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageAspectRatio)
                    aspectRatioConstraint.priority = UILayoutPriority(750)
                    aspectRatioConstraint.isActive = true
                    
                    // 触发布局更新
                    containerView.setNeedsLayout()
                    containerView.layoutIfNeeded()
                }
            }
        }
        task.resume()
        
        return containerView
    }
    
    /// 显示图片错误
    private func showImageError(in containerView: UIView, message: String) {
        // 清除可能存在的旧错误视图
        containerView.subviews.forEach { subview in
            if subview is UILabel {
                subview.removeFromSuperview()
            }
        }
        
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8)
        ])
        
        // 设置容器最小高度
        containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
    }
    
    /// 渲染列表
    private func renderList(_ node: ListNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .leading
        containerView.spacing = context.theme.listItemSpacing
        containerView.distribution = .fill
        
        for (index, item) in node.items.enumerated() {
            let itemView = renderListItem(item, index: index, listType: node.listType, context: context)
            containerView.addArrangedSubview(itemView)
        }
        
        return containerView
    }
    
    /// 渲染列表项
    private func renderListItem(_ item: ListItemNode, index: Int, listType: ListType, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 8
        stackView.distribution = .fill
        
        // 列表标记
        let markerView: UIView
        if case .bullet = listType {
            let circle = UIView()
            circle.backgroundColor = context.theme.textColor
            circle.layer.cornerRadius = 3
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: 6),
                circle.heightAnchor.constraint(equalToConstant: 6)
            ])
            markerView = circle
        } else {
            let label = UILabel()
            label.text = "\(index + 1)."
            label.font = context.theme.font
            label.textColor = context.theme.textColor
            markerView = label
        }
        
        stackView.addArrangedSubview(markerView)
        
        // 列表项内容
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 0
        contentStackView.distribution = .fill
        
        for child in item.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            contentStackView.addArrangedSubview(childView)
        }
        
        stackView.addArrangedSubview(contentStackView)
        
        return stackView
    }
    
    /// 渲染表格
    private func renderTable(_ node: TableNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.layer.borderColor = context.theme.tableBorderColor.cgColor
        containerView.layer.borderWidth = 1
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        
        for (rowIndex, row) in node.rows.enumerated() {
            let rowView = renderTableRow(row, isHeader: rowIndex == 0, context: context)
            stackView.addArrangedSubview(rowView)
            
            if rowIndex < node.rows.count - 1 {
                let divider = UIView()
                divider.backgroundColor = context.theme.tableBorderColor
                divider.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    divider.heightAnchor.constraint(equalToConstant: 1)
                ])
                stackView.addArrangedSubview(divider)
            }
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    /// 渲染表格行
    private func renderTableRow(_ row: TableRow, isHeader: Bool, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        
        for cell in row.cells {
            let cellView = renderTableCell(cell, isHeader: isHeader, context: context)
            stackView.addArrangedSubview(cellView)
        }
        
        return stackView
    }
    
    /// 渲染表格单元格
    private func renderTableCell(_ cell: TableCell, isHeader: Bool, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = isHeader ? context.theme.tableHeaderBackground : .clear
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = cell.align?.uiAlignment ?? .leading
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(stackView)
        
        for child in cell.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            stackView.addArrangedSubview(childView)
        }
        
        let padding = context.theme.tableCellPadding
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
        ])
        
        return containerView
    }
    
    /// 渲染数学公式
    private func renderMath(_ node: MathNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        // 从 Rust Core 获取 KaTeX HTML
        let result = IMParseCore.mathToHTML(node.content, display: node.display)
        
        guard result.success, let html = result.astJSON else {
            showMathError(in: containerView, message: "无法获取数学公式 HTML")
            return containerView
        }
        
        // 获取文本颜色
        let textColor = context.theme.textColor
        let components = textColor.cgColor.components ?? [0, 0, 0, 1]
        let colorHex = String(format: "#%02X%02X%02X",
            Int(components[0] * 255),
            Int(components[1] * 255),
            Int(components[2] * 255)
        )
        
        // 创建图片视图
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        containerView.addSubview(imageView)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: node.display ? 60 : 30),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // 使用 MathHTMLRenderer 渲染为图片
        let fontSize = node.display ? 16.0 : 14.0
        MathHTMLRenderer.shared.render(
            html: html,
            display: node.display,
            textColor: colorHex,
            fontSize: fontSize
        ) { image in
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                
                if let image = image {
                    imageView.image = image
                } else {
                    // 渲染失败，显示错误
                    self.showMathError(in: containerView, message: "数学公式渲染失败")
                    imageView.removeFromSuperview()
                }
            }
        }
        
        return containerView
    }
    
    /// 显示数学公式错误
    private func showMathError(in containerView: UIView, message: String) {
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 8),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }
    
    /// 渲染 Mermaid 图表
    private func renderMermaid(_ node: MermaidNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.codeBackgroundColor
        containerView.layer.cornerRadius = context.theme.codeBlockBorderRadius
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = "Mermaid: \(node.content)"
        label.font = context.theme.codeFont
        label.textColor = context.theme.codeTextColor
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        let padding = context.theme.codeBlockPadding
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding)
        ])
        
        return containerView
    }
    
    /// 渲染提及
    private func renderMention(_ node: MentionNode, context: UIKitRenderContext) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = context.theme.mentionBackground
        containerView.layer.cornerRadius = 4
        containerView.clipsToBounds = true
        
        let label = UILabel()
        label.text = "@\(node.name)"
        label.font = context.theme.font
        label.textColor = context.theme.mentionTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
        ])
        
        return containerView
    }
    
    /// 渲染引用块
    private func renderBlockquote(_ node: BlockquoteNode, context: UIKitRenderContext) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 8
        stackView.distribution = .fill
        
        // 左侧竖线
        let lineView = UIView()
        lineView.backgroundColor = context.theme.blockquoteBorderColor
        lineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lineView.widthAnchor.constraint(equalToConstant: context.theme.blockquoteBorderWidth)
        ])
        stackView.addArrangedSubview(lineView)
        
        // 内容
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 0
        contentStackView.distribution = .fill
        
        for child in node.children {
            let childView = renderInlineNodeWrapper(child, context: context)
            // 设置引用块文本颜色
            if let label = childView as? UILabel {
                label.textColor = context.theme.blockquoteTextColor
            }
            contentStackView.addArrangedSubview(childView)
        }
        
        stackView.addArrangedSubview(contentStackView)
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        
        return stackView
    }
    
    /// 渲染水平分割线
    private func renderHorizontalRule(context: UIKitRenderContext) -> UIView {
        let view = UIView()
        view.backgroundColor = context.theme.hrColor
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1)
        ])
        return view
    }
    
    /// 渲染行内节点包装器
    private func renderInlineNodeWrapper(_ wrapper: ASTNodeWrapper, context: UIKitRenderContext) -> UIView {
        switch wrapper {
        case .text(let node):
            return renderText(node, context: context)
        case .strong(let node):
            return renderStrong(node, context: context)
        case .em(let node):
            return renderEm(node, context: context)
        case .underline(let node):
            return renderUnderline(node, context: context)
        case .strike(let node):
            return renderStrike(node, context: context)
        case .code(let node):
            return renderCode(node, context: context)
        case .link(let node):
            return renderLink(node, context: context)
        case .mention(let node):
            return renderMention(node, context: context)
        case .math(let node):
            // 行内数学公式
            return renderMath(node, context: context)
        default:
            return UIView()
        }
    }
}

// MARK: - Math HTML Cache

/// HTML 渲染图片缓存管理器（与 SwiftUIRenderer 共享）
/// 注意：MathSVGCache 是旧名称，实际用于缓存 HTML 渲染的图片
extension MathSVGCache {
    // 已在 SwiftUIRenderer.swift 中定义
}

// MARK: - 辅助扩展

extension TextAlign {
    var uiAlignment: UIStackView.Alignment {
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

// MARK: - 关联对象键

private struct AssociatedKeys {
    static var url = "url"
}

// MARK: - UILabel 扩展（用于内边距）

class PaddedLabel: UILabel {
    var padding: UIEdgeInsets = .zero
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + padding.left + padding.right,
            height: size.height + padding.top + padding.bottom
        )
    }
}

// MARK: - UIColor 扩展（用于解析十六进制颜色）

extension UIColor {
    /// 从十六进制字符串创建 UIColor
    convenience init?(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

