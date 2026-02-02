//
//  UIKitFrameHelpers.swift
//  IMParseSDK
//
//  Frame 布局相关的共享辅助类
//  用于 UIKitFrameAsyncCalculator 和 UIKitFrameRender
//

import UIKit

// MARK: - 辅助结构

internal struct AssociatedKeys {
    static var linkHandler: UInt8 = 0
    static var mentionHandler: UInt8 = 0
    static var tapHandler: UInt8 = 0
}

// MARK: - 自定义 AttributedString 属性键

/// 行内数学公式待渲染标记
/// 值类型: InlineMathRenderInfo
internal extension NSAttributedString.Key {
    static let inlineMathRenderInfo = NSAttributedString.Key("com.imparse.inlineMathRenderInfo")
    static let inlineImageRenderInfo = NSAttributedString.Key("com.imparse.inlineImageRenderInfo")
    static let mentionNodeInfo = NSAttributedString.Key("com.imparse.mentionNodeInfo")
}

/// 行内数学公式渲染信息
internal struct InlineMathRenderInfo {
    let mathNode: MathNode
    let textColor: UIColor
    let fontSize: CGFloat
}

/// 行内图片渲染信息
internal struct InlineImageRenderInfo {
    let imageNode: ImageNode
}

/// Mention 节点信息（用于在 NSAttributedString 中存储 mention 的 id 和 name）
internal struct MentionNodeInfo {
    let id: String
    let name: String
}

// MARK: - Emoji 文本附件

/// Emoji 文本附件，用于在 NSAttributedString 中嵌入 emoji 节点
internal class EmojiTextAttachment: NSTextAttachment {
    let emojiNode: EmojiNode
    let context: UIKitRenderContext
    private var isLoading = false
    private let font: UIFont // 保存字体，用于计算 attachmentBounds
    
    init(emojiNode: EmojiNode, context: UIKitRenderContext) {
        self.emojiNode = emojiNode
        self.context = context
        // 保存当前字体，用于后续计算 attachmentBounds
        self.font = context.currentFont ?? context.theme.font
        super.init(data: nil, ofType: nil)
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        // 获取图片的实际尺寸（如果已加载）
        let imageSize = self.image?.size ?? bounds.size
        
        // 计算垂直居中的偏移量
        // 参考：yOffset = (font.capHeight - imageSize.height) / 2
        let yOffset = (font.capHeight - imageSize.height) / 2
        
        // 返回调整后的 bounds
        return CGRect(origin: CGPoint(x: 0, y: yOffset), size: imageSize)
    }
 
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Mention 状态图片附件

/// Mention 状态图片附件，用于在 mention 文本后显示已读/未读状态
internal class MentionStatusImageAttachment: NSTextAttachment {
    let mentionNode: MentionNode
    let context: UIKitRenderContext
    private var isLoading = false
    private let font: UIFont
    
    init(mentionNode: MentionNode, context: UIKitRenderContext) {
        self.mentionNode = mentionNode
        self.context = context
        self.font = context.currentFont ?? context.theme.font
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let imageSize = self.image?.size ?? bounds.size
        let yOffset = (font.capHeight - imageSize.height) / 2
        return CGRect(origin: CGPoint(x: 0, y: yOffset), size: imageSize)
    }

}

// MARK: - 行内数学公式文本附件

/// 行内数学公式文本附件，用于在 NSAttributedString 中嵌入行内数学公式
/// 注意：此附件只接受已加载的图片，不负责异步加载
internal class MathTextAttachment: NSTextAttachment {
    let mathNode: MathNode
    private let font: UIFont // 保存字体，用于计算 attachmentBounds
    private var cacheImageBounds: CGRect = CGRectZero // 保存图片尺寸

    /// 初始化行内数学公式附件
    /// - Parameters:
    ///   - mathNode: 数学公式节点
    ///   - image: 已加载的公式图片（必须提供，应该比需要的大）
    ///   - font: 当前字体（用于计算 bounds）
    init(mathNode: MathNode, image: UIImage, font: UIFont, context: UIKitRenderContext) {
        self.mathNode = mathNode
        self.font = font
        super.init(data: nil, ofType: nil)
        
        // 计算目标显示尺寸（基于字体行高，考虑屏幕 scale）
        let screenScale = UIScreen.main.scale
        let minHeight = font.capHeight // 基础Attachment高度比字体capHeight要放大2倍
        let maxHeight = font.capHeight * 4 // 最大Attachment高度比字体capHeight要放大5倍
        let imageAspectRatio = image.size.width / image.size.height
        let availableWidth = context.width*0.7
        
        // 行内数学公式图片缩放算法，保证图片清晰度和阅读体验
        var targetWidth = image.size.width
        var targetHeight = image.size.height
        
        // 1. 如果图片宽度比context.width大，则按照比例缩放，保证图片宽度不超过context.width
        if image.size.width > availableWidth {
            targetWidth = availableWidth
            targetHeight = targetWidth / imageAspectRatio
        }
        
        // 2. 如果图片宽度比context.width小，再判断图片高度
        else if image.size.width <= availableWidth {
            // 2.1 如果图片高度比maxHeight小，直接使用图片尺寸（已在上面设置）
            if image.size.height > maxHeight {
                // 2.2 如果图片高度比maxHeight大，则按照比例缩放，保证图片高度不超过maxHeight
                targetHeight = maxHeight
                targetWidth = targetHeight * imageAspectRatio
                // 如果缩放后宽度超过可用宽度，需要重新按宽度缩放
                if targetWidth > availableWidth {
                    targetWidth = availableWidth
                    targetHeight = targetWidth / imageAspectRatio
                }
            }
            else if image.size.height < minHeight {
                // 4. 如果图片高度比minHeight小，则按照比例缩放，保证图片高度不小于minHeight
                targetHeight = minHeight
                targetWidth = targetHeight * imageAspectRatio
                // 如果缩放后宽度超过可用宽度，需要重新按宽度缩放
                if targetWidth > availableWidth {
                    targetWidth = availableWidth
                    targetHeight = targetWidth / imageAspectRatio
                }
            }
        }
        
        // 使用UIGraphicsImageRenderer进行缩放，保持屏幕scale
        let scaledImage: UIImage
        if abs(targetWidth - image.size.width) > 1 || abs(targetHeight - image.size.height) > 1 {
            scaledImage = image.scaled(to: CGSize(width: targetWidth, height: targetHeight), scale: screenScale)
        } else {
            // 不需要缩放，直接使用原图
            scaledImage = image
        }
        
        // 设置缩放后的图片
        self.image = scaledImage
        // 计算垂直居中的 bounds（使用缩放后的尺寸）
        let displaySize = CGSize(width: Int(ceilf(Float(targetWidth))), height: Int(ceilf(Float(targetHeight))))
        let yOffset = (font.capHeight - displaySize.height) / 2
        self.cacheImageBounds = CGRect(origin: CGPoint(x: 0, y: Int(ceilf(Float(yOffset)))), size: displaySize)
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    /// 考虑屏幕 scale，确保在高分辨率屏幕上显示清晰
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        // 获取图片的实际尺寸（逻辑尺寸，points）
        // 图片已经在初始化时缩放到正确尺寸，直接使用即可
        return self.cacheImageBounds

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 行内图片文本附件

/// 行内图片文本附件，用于在 NSAttributedString 中嵌入行内图片
/// 注意：此附件只接受已加载的图片，不负责异步加载
/// 
/// 对于动图（GIF/APNG/WebP），应在上层使用 AnimatedImageUtils.extractFirstFrame 
/// 提取首帧后传入，以避免内存爆炸问题
internal class ImageTextAttachment: NSTextAttachment {
    let imageNode: ImageNode
    private let font: UIFont // 保存字体，用于计算 attachmentBounds
    private var cacheImageBounds: CGRect = .zero // 保存图片尺寸
    private let context: UIKitRenderContext

    /// 初始化行内图片附件
    /// - Parameters:
    ///   - imageNode: 图片节点
    ///   - image: 已加载的图片
    ///   - font: 当前字体（用于计算 bounds）
    ///   - context: 渲染上下文
    init(imageNode: ImageNode, image: UIImage, font: UIFont, context: UIKitRenderContext) {
        self.imageNode = imageNode
        self.font = font
        self.context = context
        super.init(data: nil, ofType: nil)
        
        // 计算目标显示尺寸
        let screenScale = UIScreen.main.scale
        let imageAspectRatio = image.size.width / image.size.height
        
        // 1. 计算最大允许尺寸
        let maxWidth = context.width * 0.7 // 最大可展示宽度为容器的70%
        let maxHeight = context.width * 2.0 // 最大高度不能超过context.width的两倍
        
        // 2. 根据图片原始尺寸和长宽比计算目标尺寸（不超过最大尺寸）
        var targetWidth: CGFloat
        var targetHeight: CGFloat
        
        if image.size.width > maxWidth {
            // 如果图片宽度超过最大宽度，按宽度缩放
            targetWidth = maxWidth
            targetHeight = targetWidth / imageAspectRatio
            // 如果按宽度缩放后高度超过最大高度，则按高度缩放
            if targetHeight > maxHeight {
                targetHeight = maxHeight
                targetWidth = targetHeight * imageAspectRatio
            }
        } else if image.size.height > maxHeight {
            // 如果图片高度超过最大高度，按高度缩放
            targetHeight = maxHeight
            targetWidth = targetHeight * imageAspectRatio
            // 如果按高度缩放后宽度超过最大宽度，则按宽度缩放
            if targetWidth > maxWidth {
                targetWidth = maxWidth
                targetHeight = targetWidth / imageAspectRatio
            }
        } else {
            // 图片尺寸在允许范围内，使用原始尺寸
            targetWidth = image.size.width
            targetHeight = image.size.height
        }
        
        // 3. 如果imageNode指定了尺寸，需要和计算出的最大尺寸对比
        if let nodeWidth = imageNode.width, let nodeHeight = imageNode.height {
            let nodeWidthCGFloat = CGFloat(nodeWidth)
            let nodeHeightCGFloat = CGFloat(nodeHeight)
            
            // 如果imageNode的尺寸大于计算出的最大尺寸，则压缩到最大尺寸
            if nodeWidthCGFloat > maxWidth || nodeHeightCGFloat > maxHeight {
                // 需要压缩，使用计算出的最大尺寸
                // targetWidth 和 targetHeight 已经在上面计算好了
            } else {
                // 如果imageNode的尺寸小于或等于最大尺寸，则使用imageNode的尺寸
                targetWidth = nodeWidthCGFloat
                targetHeight = nodeHeightCGFloat
            }
        }
        
        // 4. 使用UIGraphicsImageRenderer进行缩放，保持屏幕scale
        let scaledImage: UIImage
        if abs(targetWidth - image.size.width) > 1 || abs(targetHeight - image.size.height) > 1 {
            scaledImage = image.scaled(to: CGSize(width: targetWidth, height: targetHeight), scale: screenScale)
        } else {
            // 不需要缩放，直接使用原图
            scaledImage = image
        }
        
        // 设置缩放后的图片
        self.image = scaledImage
        // 计算bounds，图片顶部对齐font的顶部
        let displaySize = CGSize(width: targetWidth, height: targetHeight)
        // font.ascender 是从基线到字体顶部的距离，图片顶部对齐字体顶部
        self.cacheImageBounds = CGRect(origin: CGPoint(x: 0, y: font.ascender - targetHeight), size: displaySize)
    }
    
    /// 动态计算 attachment 的 bounds，确保与文本垂直居中
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        self.cacheImageBounds.origin.x = position.x
        return self.cacheImageBounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UITextView 事件处理

/// 用于处理 UITextView 链接和 mention 点击的代理
/// 上层可以使用此类来处理链接和 mention 点击，或者实现自己的 UITextViewDelegate
public class LinkHandler {
    let onLinkTap: ((URL) -> Void)?
    let onMentionTap: ((MentionNode) -> Void)?
    let onImageTap: ((ImageNode) -> Void)?

    public init(onLinkTap: ((URL) -> Void)?, onMentionTap: ((MentionNode) -> Void)? = nil, onImageTap: ((ImageNode) -> Void)? = nil) {
        self.onLinkTap = onLinkTap
        self.onMentionTap = onMentionTap
        self.onImageTap = onImageTap
    }
}

// 注意：MentionTapHandler 已移除
// 现在 mention 通过自定义 URL（sk360Teams://）处理，使用 LinkHandler 统一处理
// 这样可以避免访问 TextKit 组件，从而避免触发布局导致文本被裁剪

// MARK: - NodeLayout 工具方法

/// 递归更新节点布局
/// - Parameters:
///   - layout: 当前布局
///   - updatedLayout: 更新后的节点布局
/// - Returns: 更新后的完整布局
public func updateNodeLayout(in layout: NodeLayout, with updatedLayout: NodeLayout) -> NodeLayout {
    // 如果当前节点就是要更新的节点（通过节点内容匹配）
    if let currentNode = layout.node, let updatedNode = updatedLayout.node {
        if nodesMatch(currentNode, updatedNode) {
            // 返回更新后的布局
            return updatedLayout
        }
    }
    
    // 递归查找子节点
    var updatedChildren = layout.children
    var hasChanges = false
    
    for (index, child) in layout.children.enumerated() {
        let updatedChild = updateNodeLayout(in: child, with: updatedLayout)
        if updatedChild !== child {
            updatedChildren[index] = updatedChild
            hasChanges = true
        }
    }
    
    // 如果子节点有更新，重新计算当前节点的 frame
    if hasChanges {
        // 重新计算垂直堆栈的高度
        var totalHeight: CGFloat = 0
        for child in updatedChildren {
            totalHeight += child.frame.height
        }
        
        let newFrame = CGRect(
            origin: layout.frame.origin,
            size: CGSize(width: layout.frame.width, height: totalHeight)
        )
        
        return NodeLayout(
            frame: newFrame,
            children: updatedChildren,
            node: layout.node,
            content: layout.content,
            backgroundColor: layout.backgroundColor,
            cornerRadius: layout.cornerRadius,
            borderColor: layout.borderColor,
            borderWidth: layout.borderWidth
        )
    }
    
    return layout
}

/// 判断两个 AST 节点是否匹配（用于查找要更新的节点）
public func nodesMatch(_ node1: ASTNodeWrapper, _ node2: ASTNodeWrapper) -> Bool {
    switch (node1, node2) {
    case (.mathBlock(let math1), .mathBlock(let math2)):
        return math1.content == math2.content
    case (.mermaidBlock(let mermaid1), .mermaidBlock(let mermaid2)):
        return mermaid1.content == mermaid2.content
    default:
        return false
    }
}


extension UIImage {
    // 方法1：高质量缩放（保持清晰）
    func scaled(to size: CGSize, scale: CGFloat? = nil) -> UIImage {
        // 1. 确保目标尺寸是整数像素
        let targetSize = CGSize(
            width: floor(size.width),
            height: floor(size.height)
        )
        
        // 2. 计算实际像素尺寸
        let renderScale = scale ?? UIScreen.main.scale
        let pixelSize = CGSize(
            width: targetSize.width * renderScale,
            height: targetSize.height * renderScale
        )
        
        // 3. 使用整数像素尺寸创建渲染器
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = renderScale
        format.opaque = self.imageRendererFormat.opaque  // 保持透明度设置
        format.preferredRange = .standard  // 保持颜色范围
        
        let renderer = UIGraphicsImageRenderer(
            size: targetSize,  // 使用点尺寸
            format: format
        )
        
        return renderer.image { context in
            // 4. 设置高质量插值
            context.cgContext.interpolationQuality = .high
            
            // 5. 确保绘制在像素边界上
            let drawRect = CGRect(origin: .zero, size: targetSize)
            
            // 6. 使用正确的混合模式
            self.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
        }
    }
    
    // 方法2：保持宽高比的高质量缩放
    func scaledAspectFit(to targetSize: CGSize, scale: CGFloat? = nil) -> UIImage {
        // 计算保持宽高比的目标尺寸
        let aspectRatio = self.size.width / self.size.height
        var newSize = targetSize
        
        if targetSize.width / aspectRatio <= targetSize.height {
            newSize.height = targetSize.width / aspectRatio
        } else {
            newSize.width = targetSize.height * aspectRatio
        }
        
        // 对齐到像素边界
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        return self.scaled(to: newSize, scale: scale)
    }
    
    // 方法3：针对特定用途的优化缩放
    enum ScaleQuality {
        case high       // 高质量，适合照片
        case medium     // 中等质量，适合UI元素
        case fast       // 快速，适合临时显示
    }
    
    func scaled(to size: CGSize, quality: ScaleQuality = .high) -> UIImage {
        let targetSize = CGSize(
            width: floor(size.width),
            height: floor(size.height)
        )
        
        let renderer: UIGraphicsImageRenderer
        let format = UIGraphicsImageRendererFormat.default()
        
        switch quality {
        case .high:
            format.scale = UIScreen.main.scale
            format.opaque = false
            format.preferredRange = .extended  // 扩展颜色范围
            
            renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            return renderer.image { context in
                context.cgContext.interpolationQuality = .high
                context.cgContext.setAllowsAntialiasing(true)
                
                // 使用 transform 确保像素对齐
                let transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                context.cgContext.concatenate(transform)
                
                self.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
        case .medium:
            format.scale = UIScreen.main.scale
            format.opaque = self.imageRendererFormat.opaque
            
            renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            return renderer.image { context in
                context.cgContext.interpolationQuality = .medium
                self.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
        case .fast:
            format.scale = 1.0  // 使用较低的 scale 提高性能
            
            renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            return renderer.image { _ in
                self.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}

// 像素对齐工具
struct PixelAlignment {
    // 将点坐标对齐到像素边界
    static func alignToPixel(_ point: CGPoint) -> CGPoint {
        let scale = UIScreen.main.scale
        return CGPoint(
            x: round(point.x * scale) / scale,
            y: round(point.y * scale) / scale
        )
    }
    
    // 将尺寸对齐到像素边界
    static func alignToPixel(_ size: CGSize) -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(
            width: ceil(size.width * scale) / scale,
            height: ceil(size.height * scale) / scale
        )
    }
    
    // 将对齐的 CGRect
    static func alignToPixel(_ rect: CGRect) -> CGRect {
        return CGRect(
            origin: alignToPixel(rect.origin),
            size: alignToPixel(rect.size)
        )
    }
    
    // 检查是否需要像素对齐
    static func needsAlignment(_ value: CGFloat) -> Bool {
        let scale = UIScreen.main.scale
        let pixelValue = value * scale
        return abs(pixelValue - round(pixelValue)) > 0.001
    }
}
