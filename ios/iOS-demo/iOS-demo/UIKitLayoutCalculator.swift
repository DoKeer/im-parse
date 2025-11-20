//
//  UIKitLayoutCalculator.swift
//  IMParseDemo
//
//  UIKit 布局计算器 - 用于异步预计算布局
//

import UIKit

/// 布局节点（保存异步计算的结果）
class NodeLayout {
    let frame: CGRect
    let children: [NodeLayout]
    let node: ASTNodeWrapper? // 关联的 AST 节点
    
    // 预计算的内容（如 NSAttributedString）
    let content: Any?
    
    // 额外的样式信息
    let backgroundColor: UIColor?
    let cornerRadius: CGFloat
    let borderColor: UIColor?
    let borderWidth: CGFloat
    
    init(frame: CGRect, 
         children: [NodeLayout] = [], 
         node: ASTNodeWrapper? = nil, 
         content: Any? = nil,
         backgroundColor: UIColor? = nil,
         cornerRadius: CGFloat = 0,
         borderColor: UIColor? = nil,
         borderWidth: CGFloat = 0) {
        self.frame = frame
        self.children = children
        self.node = node
        self.content = content
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    /// 渲染为 UIView（在主线程调用）
    /// 注意：返回的视图使用固定 frame，但在 Auto Layout 环境中会被约束覆盖
    func render(context: UIKitRenderContext) -> UIView {
        let view: UIView
        
        // 根据内容类型创建视图
        if let attributedString = content as? NSAttributedString {
            // 文本节点
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            view = label
        } else if let nodeWrapper = node {
            switch nodeWrapper {
            case .image(let imgNode):
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.backgroundColor = .systemGray6
                imageView.clipsToBounds = true
                imageView.translatesAutoresizingMaskIntoConstraints = false
                if let url = URL(string: imgNode.url) {
                    // 这里仍然需要异步加载图片，但占位符大小已确定
                    loadAsyncImage(url: url, into: imageView)
                }
                view = imageView
                
            case .codeBlock(_):
                 // 代码块容器
                view = UIView()
                view.translatesAutoresizingMaskIntoConstraints = false
                
            case .table(_):
                view = UIView()
                view.translatesAutoresizingMaskIntoConstraints = false
                // 绘制边框
                view.layer.borderWidth = 1
                view.layer.borderColor = context.theme.tableBorderColor.cgColor
                
            default:
                view = UIView()
                view.translatesAutoresizingMaskIntoConstraints = false
            }
        } else {
            view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // 应用通用样式
        if let bgColor = backgroundColor {
            view.backgroundColor = bgColor
        }
        if cornerRadius > 0 {
            view.layer.cornerRadius = cornerRadius
            view.clipsToBounds = true
        }
        if let borderColor = borderColor, borderWidth > 0 {
            view.layer.borderColor = borderColor.cgColor
            view.layer.borderWidth = borderWidth
        }
        
        // 递归添加子视图
        // 注意：子视图使用 Auto Layout 约束，frame 仅作为初始估算
        for childLayout in children {
            let childView = childLayout.render(context: context)
            view.addSubview(childView)
            
            // 设置 Auto Layout 约束（相对于父视图）
            NSLayoutConstraint.activate([
                childView.topAnchor.constraint(equalTo: view.topAnchor, constant: childLayout.frame.origin.y),
                childView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: childLayout.frame.origin.x),
                childView.widthAnchor.constraint(equalToConstant: childLayout.frame.width),
                childView.heightAnchor.constraint(equalToConstant: childLayout.frame.height)
            ])
        }
        
        return view
    }
    
    private func loadAsyncImage(url: URL, into imageView: UIImageView) {
         // 简化的图片加载
         URLSession.shared.dataTask(with: url) { data, _, _ in
             if let data = data, let image = UIImage(data: data) {
                 DispatchQueue.main.async {
                     imageView.image = image
                 }
             }
         }.resume()
    }
}

/// UIKit 布局计算器
/// 负责在后台线程预计算 AST 的布局信息
class UIKitLayoutCalculator {
    
    /// 计算 AST 的布局
    static func calculateLayout(ast: RootNode, context: UIKitRenderContext) -> NodeLayout {
        // 根节点是一个垂直堆栈
        return calculateVerticalStackLayout(
            children: ast.children,
            context: context,
            origin: .zero,
            width: context.width,
            spacing: context.theme.paragraphSpacing
        )
    }
    
    // MARK: - Private Layout Helpers
    
    /// 计算垂直堆栈布局
    private static func calculateVerticalStackLayout(children: [ASTNodeWrapper], 
                                                   context: UIKitRenderContext, 
                                                   origin: CGPoint, 
                                                   width: CGFloat,
                                                   spacing: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var childLayouts: [NodeLayout] = []
        
        for child in children {
            let childLayout = calculateNodeLayout(child, context: context, origin: CGPoint(x: 0, y: currentY), width: width)
            childLayouts.append(childLayout)
            currentY += childLayout.frame.height + spacing
        }
        
        // 去掉最后一个多余的间距
        if !children.isEmpty {
            currentY -= spacing
        }
        
        // 确保高度不为负
        let totalHeight = max(0, currentY)
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: totalHeight)),
            children: childLayouts
        )
    }
    
    /// 计算单个节点的布局
    private static func calculateNodeLayout(_ node: ASTNodeWrapper, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        switch node {
        case .paragraph(let pNode):
            // 段落布局：文本计算
            // 使用 NSAttributedString 计算高度
            let renderer = UIKitRenderer()
            let attrString = renderer.buildAttributedString(from: pNode.children, context: context)
            
            let size = attrString.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            // 向上取整
            let height = ceil(size.height)
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                node: node,
                content: attrString
            )
            
        case .heading(let hNode):
            let renderer = UIKitRenderer()
            // 模拟 renderHeading 中的字体计算
            let baseFontSize = context.theme.fontSize
            let headingMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9]
            let multiplier = headingMultipliers[min(Int(hNode.level) - 1, headingMultipliers.count - 1)]
            let fontSize = baseFontSize * multiplier
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let color = context.theme.headingColors[min(Int(hNode.level) - 1, context.theme.headingColors.count - 1)]
            
            var headingContext = context
            headingContext.currentFont = font
            headingContext.currentTextColor = color
            
            let attrString = renderer.buildAttributedString(from: hNode.children, context: headingContext)
            
            let size = attrString.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height)
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                node: node,
                content: attrString
            )
            
        case .codeBlock(let cNode):
            // 代码块布局
            let padding = context.theme.codeBlockPadding
            let contentWidth = width - padding * 2
            
            let font = context.theme.codeFont
            let attrString = NSAttributedString(string: cNode.content, attributes: [.font: font])
            
            let size = attrString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size
            
            let height = ceil(size.height) + padding * 2
            
            // 创建内部文本的 layout
            let textLayout = NodeLayout(
                frame: CGRect(x: padding, y: padding, width: contentWidth, height: ceil(size.height)),
                content: attrString
            )
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                children: [textLayout],
                node: node,
                backgroundColor: context.theme.codeBackgroundColor,
                cornerRadius: context.theme.codeBlockBorderRadius
            )
            
        case .image(let imgNode):
            // 图片布局
            var height: CGFloat = 200 // 默认高度
            
            if let h = imgNode.height, let w = imgNode.width {
                // 如果有尺寸，按比例计算
                let ratio = CGFloat(h) / CGFloat(w)
                height = width * ratio
            } else {
                // 默认 4:3
                height = width * 0.75
            }
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                node: node
            )
            
        case .list(let listNode):
            // 列表布局
            return calculateListLayout(listNode, context: context, origin: origin, width: width)
            
        case .blockquote(let bNode):
            // 引用块布局
            let borderWidth = context.theme.blockquoteBorderWidth
            let contentWidth = width - borderWidth - 16 // 16 padding
            
            var blockContext = context
            blockContext.currentTextColor = context.theme.blockquoteTextColor
            
            // 递归计算内部布局
            let innerLayout = calculateVerticalStackLayout(
                children: bNode.children,
                context: blockContext,
                origin: CGPoint(x: borderWidth + 16, y: 0),
                width: contentWidth,
                spacing: context.theme.paragraphSpacing
            )
            
            // 左侧边框
            let borderLayout = NodeLayout(
                frame: CGRect(x: 0, y: 0, width: borderWidth, height: innerLayout.frame.height),
                backgroundColor: context.theme.blockquoteBorderColor
            )
            
            return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: innerLayout.frame.height)),
                children: [borderLayout, innerLayout],
                node: node
            )
            
        case .horizontalRule(_):
             return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 1)),
                backgroundColor: context.theme.hrColor
            )
            
        default:
            // 其他节点暂且返回固定高度或0，或者通用处理
             return NodeLayout(
                frame: CGRect(origin: origin, size: CGSize(width: width, height: 20)),
                node: node
            )
        }
    }
    
    /// 计算列表布局
    private static func calculateListLayout(_ node: ListNode, context: UIKitRenderContext, origin: CGPoint, width: CGFloat) -> NodeLayout {
        var currentY: CGFloat = 0
        var itemLayouts: [NodeLayout] = []
        let spacing = context.theme.listItemSpacing
        
        for (index, item) in node.items.enumerated() {
            // 列表项布局
            // 标记宽度 + 间距
            let markerWidth: CGFloat = 20
            let contentWidth = width - markerWidth
            
            // 列表项内容（可能是多个段落等）
            // 递归使用 Stack Layout
            let contentLayout = calculateVerticalStackLayout(
                children: item.children,
                context: context,
                origin: CGPoint(x: markerWidth, y: currentY),
                width: contentWidth,
                spacing: 4 // 内部紧凑一些
            )
            
            // 标记 (Marker)
            // 简单创建一个文本 layout
            let markerText = node.listType == .bullet ? "•" : "\(index + 1)."
            let markerAttr = NSAttributedString(string: markerText, attributes: [.font: context.theme.font, .foregroundColor: context.theme.textColor])
            let markerLayout = NodeLayout(
                frame: CGRect(x: 0, y: currentY, width: markerWidth, height: 20), // 估算高度
                content: markerAttr
            )
            
            itemLayouts.append(markerLayout)
            itemLayouts.append(contentLayout)
            
            currentY += max(contentLayout.frame.height, 20) + spacing
        }
        
        if !node.items.isEmpty {
            currentY -= spacing
        }
        
        return NodeLayout(
            frame: CGRect(origin: origin, size: CGSize(width: width, height: currentY)),
            children: itemLayouts,
            node: .list(node)
        )
    }
}

