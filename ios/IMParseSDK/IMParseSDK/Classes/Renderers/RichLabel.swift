//
//  RichLabel.swift
//  IMParseSDK
//
//  UILabel + TextKit 富文本组件
//  用于替代 UITextView，提供更好的性能和可控性
//

import UIKit

// MARK: - RichSpan Protocol

/// 富文本 Span 协议
/// 用于表示富文本中的可交互元素（链接、mention 等）
internal protocol RichSpan {
    var range: NSRange { get set }
    func apply(to attr: NSMutableAttributedString)
    func onTap()
}

// MARK: - LinkSpan

/// 链接 Span
internal final class LinkSpan: RichSpan {
    var range: NSRange
    let url: URL
    let onTapHandler: (URL) -> Void
    
    init(range: NSRange, url: URL, onTap: @escaping (URL) -> Void) {
        self.range = range
        self.url = url
        self.onTapHandler = onTap
    }
    
    func apply(to attr: NSMutableAttributedString) {
        attr.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle(),
            .link: url
        ], range: range)
    }
    
    func onTap() {
        onTapHandler(url)
    }
}

// MARK: - MentionSpan

/// Mention Span
internal final class MentionSpan: RichSpan {
    var range: NSRange
    let mentionNode: MentionNode
    let onTapHandler: (MentionNode) -> Void
    
    init(range: NSRange, mentionNode: MentionNode, onTap: @escaping (MentionNode) -> Void) {
        self.range = range
        self.mentionNode = mentionNode
        self.onTapHandler = onTap
    }
    
    func apply(to attr: NSMutableAttributedString) {
        // Mention 使用自定义 URL scheme（优先使用 sk360Teams:// 以兼容现有代码）
        let encodedName = mentionNode.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? mentionNode.name
        let mentionURL = URL(string: "sk360Teams://\(mentionNode.id)#\(encodedName)")!
        
        attr.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle(),
            .link: mentionURL
        ], range: range)
    }
    
    func onTap() {
        onTapHandler(mentionNode)
    }
}

// MARK: - ImageSpan

/// 图片 Span（用于行内图片）
internal final class ImageSpan: RichSpan {
    var range: NSRange
    let attachment: ImageTextAttachment
    let onTapHandler: (ImageNode) -> Void

    init(range: NSRange, attachment: ImageTextAttachment, onTap: @escaping (ImageNode) -> Void) {
        self.range = range
        self.attachment = attachment
        self.onTapHandler = onTap
    }
    
    func apply(to attr: NSMutableAttributedString) {
        guard range.location + range.length <= attr.length else {
            return // range 无效，跳过
        }
        
        let attachmentString = NSAttributedString(attachment: attachment)
        attr.replaceCharacters(in: range, with: attachmentString)
    }
    
    func onTap() {
        onTapHandler(attachment.imageNode)
    }
}

// MARK: - RichLabel

/// 富文本标签组件
/// 使用 UILabel + TextKit 实现，提供更好的性能和可控性
internal final class RichLabel: UIView {
    
    // MARK: - UI
    private let label = UILabel()
    
    // MARK: - TextKit
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer(size: .zero)
    
    // MARK: - Data
    private var spans: [RichSpan] = []
    private var onLinkTap: ((URL) -> Void)?
    private var onMentionTap: ((MentionNode) -> Void)?
    private var onImageTap: ((ImageNode) -> Void)?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // 配置 UILabel
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.backgroundColor = .clear
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 配置 TextKit
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        
        // 添加点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        label.addGestureRecognizer(tap)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // ✅ 修复：完善 layoutSubviews，确保 TextKit 布局正确
        textContainer.size = bounds.size
        label.preferredMaxLayoutWidth = bounds.width
        layoutManager.ensureLayout(for: textContainer)
    }
    
    // MARK: - Public Methods
    
    /// 设置富文本内容
    /// - Parameters:
    ///   - attributedString: 富文本字符串
    ///   - spans: Span 数组（用于处理点击事件）
    ///   - onLinkTap: 链接点击回调
    ///   - onMentionTap: Mention 点击回调
    func setAttributedText(
        _ attributedString: NSAttributedString,
        spans: [RichSpan] = [],
        onLinkTap: ((URL) -> Void)? = nil,
        onMentionTap: ((MentionNode) -> Void)? = nil,
        onImageTap: ((ImageNode) -> Void)? = nil
    ) {
        // 创建可变的 attributed string
        let mutableAttr = NSMutableAttributedString(attributedString: attributedString)
        
        // 应用所有 spans（按位置从后往前排序，避免 range 偏移问题）
        // 注意：ImageSpan 现在不再 replaceCharacters，所以不需要排序
        // 但为了安全，仍然按位置从后往前处理
        let sortedSpans = spans.sorted { $0.range.location > $1.range.location }
        for span in sortedSpans {
            span.apply(to: mutableAttr)
        }
        
        // ✅ 修复：末尾 attachment 丢失问题
        // 如果文本末尾是 attachment（\u{FFFC}），添加 zero-width space 确保 TextKit 生成 glyph
        if mutableAttr.string.hasSuffix("\u{FFFC}") {
            mutableAttr.append(NSAttributedString(string: "\u{200B}")) // zero-width space
        }
        
        // 保存 spans 和回调
        self.spans = spans
        self.onLinkTap = onLinkTap
        self.onMentionTap = onMentionTap
        self.onMentionTap = onMentionTap

        // ✅ 修复：TextKit 布局顺序（关键！）
        // 1. 先设置 preferredMaxLayoutWidth
        label.preferredMaxLayoutWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        
        // 2. 设置 textStorage（这会触发 layoutManager 更新）
        textStorage.setAttributedString(mutableAttr)
        
        // 3. 确保布局完成
        layoutManager.ensureLayout(for: textContainer)
        
        // 4. 最后设置 attributedText 到 UILabel
        label.attributedText = mutableAttr
    }
    
    /// 从 NSAttributedString 中提取 spans（用于兼容现有代码）
    /// - Parameters:
    ///   - attributedString: 富文本字符串
    ///   - onLinkTap: 链接点击回调
    ///   - onMentionTap: Mention 点击回调
    func setAttributedText(
        _ attributedString: NSAttributedString,
        onLinkTap: ((URL) -> Void)? = nil,
        onMentionTap: ((MentionNode) -> Void)? = nil,
        onImageTap: ((ImageNode) -> Void)? = nil
    ) {
        var extractedSpans: [RichSpan] = []
        
        // 遍历 attributedString 提取链接和 mention
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
            // 检查是否有链接
            if let url = attributes[.link] as? URL {
                // 检查是否是 mention URL（支持 mention:// 和 sk360Teams://）
                if url.scheme == "mention" || url.scheme == "sk360Teams" {
                    // 解析 mention URL：scheme://{id}#{name}
                    let id = url.host ?? ""
                    let name = url.fragment?.removingPercentEncoding ?? ""
                    if !id.isEmpty && !name.isEmpty {
                        let mentionNode = MentionNode(id: id, name: name)
                        let span = MentionSpan(range: range, mentionNode: mentionNode) { node in
                            onMentionTap?(node)
                        }
                        extractedSpans.append(span)
                    }
                } else {
                    // 普通链接
                    let span = LinkSpan(range: range, url: url) { url in
                        onLinkTap?(url)
                    }
                    extractedSpans.append(span)
                }
            }else if let attachment = attributes[.attachment] as? ImageTextAttachment {
                let span = ImageSpan(range: range, attachment: attachment) { imageNode in
                    onImageTap?(imageNode)
                }
                extractedSpans.append(span)
            }
        }
        
        setAttributedText(
            attributedString,
            spans: extractedSpans,
            onLinkTap: onLinkTap,
            onMentionTap: onMentionTap
        )
    }
    
    // MARK: - Tap Handling
    
    @objc
    private func handleTap(_ tap: UITapGestureRecognizer) {
        let location = tap.location(in: label)
        guard let index = characterIndex(at: location) else { return }
        
        // ✅ 修复：点击只认 span，不认 attributes（避免重复触发）
        // 查找命中的 span（按顺序查找，找到第一个就返回）
        for span in spans {
            if NSLocationInRange(index, span.range) {
                span.onTap()
                return // 找到就返回，不再继续查找
            }
        }
        
        // 如果没有找到 span，尝试从 attributedString 中查找链接（向后兼容）
        // 注意：这应该只在 spans 为空时使用，或者作为 fallback
        if spans.isEmpty, let attributedText = label.attributedText {
            attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, range, stop in
                if NSLocationInRange(index, range) {
                    if let url = attributes[.link] as? URL {
                        // 检查是否是 mention URL（支持 mention:// 和 sk360Teams://）
                        if url.scheme == "mention" || url.scheme == "sk360Teams" {
                            // 解析 mention URL：scheme://{id}#{name}
                            let id = url.host ?? ""
                            let name = url.fragment?.removingPercentEncoding ?? ""
                            if !id.isEmpty && !name.isEmpty {
                                let mentionNode = MentionNode(id: id, name: name)
                                onMentionTap?(mentionNode)
                            }
                        } else {
                            onLinkTap?(url)
                        }
                        stop.pointee = true // 停止枚举
                    }
                }
            }
        }
    }
    
    /// 获取点击位置的字符索引
    private func characterIndex(at point: CGPoint) -> Int? {
        guard let text = label.attributedText, text.length > 0 else {
            return nil
        }
        
        // ✅ 修复：更严谨的 offset 逻辑（不假设垂直居中）
        // 计算文本的 bounding box
        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        
        // 转换点击位置到文本坐标系
        // UILabel 默认是 top-aligned，所以不需要假设居中
        let location = CGPoint(
            x: point.x - textBoundingBox.minX,
            y: point.y - textBoundingBox.minY
        )
        
        // 检查点击位置是否在文本范围内
        guard textBoundingBox.contains(location) else {
            return nil
        }
        
        // 获取 glyph index
        let glyphIndex = layoutManager.glyphIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        
        // 检查 glyph index 是否有效
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return nil
        }
        
        // 转换为字符索引
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // 检查字符索引是否有效
        guard charIndex < text.length else {
            return nil
        }
        
        return charIndex
    }
}

