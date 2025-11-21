//
//  SKDeltaParser.swift
//  RongEnterpriseApp
//
//  Created by LGQ on 5/9/24.
//  Copyright © 2024 奇富科技. All rights reserved.
//

import UIKit
import SKDown
import SKDelta
/// 查找持有者
public typealias MentionStatusGemerator = (String) -> UIImage?
let key_bold = "bold"
let key_italic = "italic"
let key_underline = "underline"
let key_color = "color"

let key_image = "imageContainer"
let key_mention = "mention"
let key_emoji = "emoji"

let key_list = "list"

let key_list_bullet = "bullet"
let key_list_ordered = "ordered"
let key_list_checked = "checked"
let key_list_unchecked = "unchecked"

class DeltaParser: NSObject {
    
    // MARK: - Properties
    
    private let styler: SKDeltaStyler
    private let options: DownOptions
    private let listPrefixGeneratorBuilder: ListPrefixGeneratorBuilder
    private let mentionStatusGemerator: MentionStatusGemerator
    
    private var listPrefixGenerators = [ListItemPrefixGenerator]()
    
    /// Creates a new instance with the given styler and options.
    ///
    /// - parameters:
    ///     - styler: used to style the markdown elements.
    ///     - options: may be used to modify rendering.
    ///     - listPrefixGeneratorBuilder: may be used to modify list prefixes.
    
    public init(
        styler: SKDeltaStyler,
        options: DownOptions = .default,
        listPrefixGeneratorBuilder: @escaping ListPrefixGeneratorBuilder = { StaticListItemPrefixGenerator(list: $0) },
        mentionStatusGemerator:@escaping MentionStatusGemerator = {_ in nil}
    ) {
        self.styler = styler
        self.options = options
        self.listPrefixGeneratorBuilder = listPrefixGeneratorBuilder
        self.mentionStatusGemerator = mentionStatusGemerator
    }
    
    @objc public func parserAttributes(_ attributes:[[String:AnyObject]]) {
        
    }
    
    static func deltaToString(_ delta:Delta) -> String {
        var result = ""
        delta.eachLine(action: { (newDelta, attrs, idx) in
            // 每一行不同的op处理
            for op in newDelta.ops {
                let attr = opToString(op)
                result.append(attr)
            }
            return true
        })
        return result
    }
    
    static func opToString(_ op:Op) -> String {
        var result = ""
        if let text = op.insert?.value as? String {//insert是字符串
            result.append(text)
        }
        else if let insert = op.insert?.value as? [String:AnyCodable] {//insert是对象。图片或@
            if let _ = insert[key_image]?.value as? [String:AnyCodable] {
                result.append("[图片]")
            }
            if let obj = insert[key_mention]?.value as? [String:AnyCodable],let mention = OpMention(map: obj),let userName = mention.name {
                result.append("@\(userName)")
            }
        }
        return result
    }
    
    var idxForOrderedList = 0;
    
    func resetItemIdx() {
        idxForOrderedList = 0
    }
    
    
    func deltaToAttributedString(_ delta:Delta, maxWidth:CGFloat = 0) -> NSAttributedString? {
        let result = NSMutableAttributedString()
        resetItemIdx()
        delta.eachLine(action: { (newDelta, attrs, idx) in
            // 如果是list类型，则先处理文本再拼接到mutiAttr
            if let value = attrs[key_list]?.value as? String {
                var prefix:String = ""
                if (value == key_list_bullet) {
                    resetItemIdx()
                    prefix = "•"
                    let attributedPrefix = "\(prefix)\t".attributed
                    styler.style(listItemPrefix: attributedPrefix)
                    result.append(attributedPrefix)
                }else if (value == key_list_ordered) {
                    idxForOrderedList+=1
                    // 在text前增加 1. ,2., ...
                    prefix = "\(idxForOrderedList)."
                    let attributedPrefix = "\(prefix)\t".attributed
                    styler.style(listItemPrefix: attributedPrefix)
                    result.append(attributedPrefix)
                }
                //                styler.style(item: lineText, prefixLength: prefix.count)
            }else {
                resetItemIdx()
            }
            
            let lineText = NSMutableAttributedString()
            // 每一行不同的op处理
            for op in newDelta.ops {
                let attr = opToAttributedString(op,maxWidth: maxWidth)
                lineText.append(attr)
            }
            
            result.append(lineText)
            
            // 设置paragraphStyle
            result.addAttribute(for: .paragraphStyle, value: styler.paragraphStyles.body)
            // 拼接的换行符也要包含字体样式，不然高度计算有问题！！！
            result.append(styler.breakLine())
                        
            return true
        })
        
        removeLastNewline(from: result)
        
        return result.copy() as? NSAttributedString
    }
    
    func removeLastNewline(from attributedString: NSMutableAttributedString) {
        // 获取字符串的长度
        let length = attributedString.length
        // 检查最后一个字符是否为 "\n"
        if length > 0, attributedString.string.hasSuffix(String.lineBreak) {
            // 删除最后一个 "\n"
            attributedString.deleteCharacters(in: NSRange(location: length - 1, length: 1))
        }
    }
    
    /// op 的insert内容转换为AttributedString
    /// 解析时只考虑op的insert类型。
    func opToAttributedString(_ op:Op, maxWidth:CGFloat = 0) -> NSMutableAttributedString {
        
        let result = NSMutableAttributedString()
        if let text = op.insert?.value as? String {//insert是字符串
            result.append(NSAttributedString(string: text))
            // 添加统一样式，字体和颜色,
            styler.style(text:result)
            
            guard let attr = op.attributes else {
                return result
            }
            for key in attr.keys { // 取出所有Attribute key,对应到不通类型的方法
                switch key{
                    case key_bold:
                        styler.style(strong: result)
                    case key_italic:// 英语有斜体，汉字没有
                        styler.style(emphasis: result)
                    case key_underline:
                        styler.style(underline: result)
                    case key_color:
                        if let color = attr[key_color]?.value as? String,let color = parseCSSColor(color) {
                            styler.style(color: result, color: color)
                        }
                    default:
                        break
                }
            }
        }
        else if let insert = op.insert?.value as? [String:AnyCodable] {//insert是对象。图片或@
            if let obj = insert[key_image]?.value as? [String:AnyCodable],let image = OpImage(map: obj) {
                styler.style(image: result, opImage: image)
            }
            else if let obj = insert[key_mention]?.value as? [String:AnyCodable],let mention = OpMention(map: obj) {
                styler.style(mention: result, mention: mention, mentionStatusGemerator: mentionStatusGemerator)
            }
            else if let obj = insert[key_emoji]?.value as? [String:AnyCodable],let emoji = OpEmoji(map: obj) {
                styler.style(emoji: result, emoji: emoji)
            }
        }
        return result
    }
}

public class SKReadStatusAttachment: NSTextAttachment {
    
}

@objcMembers class SKDeltaStyler: DownStyler {
    var messageId:String?
    var allRemoteImages:Set<String> = [] // 需要远程请求的图片数量
    var loadingRemoteImages:Set<String> = [] // 正在远程请求的图片数量
    deinit {
        
    }
    
    var maxWidth:CGFloat = 0
    var placeHolder:UIImage?
    
    public init(configuration: DownStylerConfiguration = DownStylerConfiguration(), messageId:String? = nil ,maxWidth:CGFloat = ALKit.kScreenW-100) {
        super.init(configuration: configuration)
        self.messageId = messageId
        self.maxWidth = maxWidth
    }
    
    func breakLine() -> NSMutableAttributedString {
        let res = String.lineBreak.attributed
        res.addAttribute(for: .font, value: fonts.body)
        return res
    }
    
    func style(image str: NSMutableAttributedString, opImage:OpImage) {
        
        guard let imageURL = opImage.url.flatMap(URL.init) else { return }
        // 异步请求图片
        let displaySize = displaySize(opImage: opImage)
        let imageAttachment = AsyncImageAttachment(imageURL: imageURL ,delegate: self)
        imageAttachment.displaySize = displaySize
        imageAttachment.maximumDisplayWidth = maxWidth
        if !imageAttachment.configCache() {
            allRemoteImages.insert(imageURL.absoluteString)
        }
        let imageString = NSAttributedString(attachment: imageAttachment)
        str.setAttributedString(imageString)
    }
    
    func style(mention str: NSMutableAttributedString, mention:OpMention, mentionStatusGemerator:@escaping MentionStatusGemerator = {_ in nil}) {
        
        if let id = mention.id {
            if id == "all" {
                str.append(NSAttributedString(string:"@所有人"))
                str.addAttributes([
                    .font: fonts.body,
                    .foregroundColor: UIColor.sk_teams])
            }
            else if let userName = RCEUserManager.shared().getUserInfo(mention.id)?.name {
                str.append(NSAttributedString(string:"@\(userName)"))
                str.addAttributes([
                    .font: fonts.body,
                    .foregroundColor: UIColor.sk_teams])
                // 处理点击事件。可以添加超链接。暂时不添加
                // @张春山|mention_separater:MDEP000227
                
                if let host = RCMessageModel.mentionLinkUrl(), let url = URL(string: "\(host)\(id)") {
                    str.addAttributes([.link: url])
                }
                
                // 根据当前用户的已读状态，获取图片
                if let image = mentionStatusGemerator(id) {
                    // 拼接已读状态图片
                    let attach = SKReadStatusAttachment()
                    attach.image = image
                    let attachString = NSAttributedString(attachment: attach)
                    str.append(attachString)
                }
            }
        }
    }
    
    func style(emoji str: NSMutableAttributedString, emoji:OpEmoji) {
        if let emojis = RCIM.shared().emojiArray as? [String],let content = emoji.content {
            let emojiSet = Set(emojis)
            if emojiSet.contains(content),let image = SKTeamsUtility.imageNamed(content, ofBundle: "IMKit.bundle"),let cgImage = image.cgImage {
                let attach = SKEmojiAttachment()
                let resizeImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: image.imageOrientation)
                attach.image = resizeImage.qmui_imageResized(inLimitedSize: CGSize(width: 25, height: 25))
                attach.font = fonts.body
//                attach.emojiSize = CGSize(width: 25, height: 25)
                let attachString = NSAttributedString(attachment: attach)
                str.append(attachString)
            }
        }
    }
    
    func replaceTextEmoji(str: NSMutableAttributedString, text:String){
        if let emojis = RCIM.shared().emojiArray as? [String],let emojiRanges = text.findEmoji(pattern: SKTeamsUtility.emojiCustom(), emojiSet: Set(emojis)) {
            let font = fonts.body
            str.replaceEmoji(with:CGSizeMake(25, 25),font:font, emojiRangeArr: emojiRanges)
        }
    }
    
    
//    override func style(text str: NSMutableAttributedString) {
//        str.addAttributes([.font:UIFont.systemFont(ofSize: 17)], range: NSRange(location: 0, length: str.length))
//        str.addAttributes([.foregroundColor:colors.body], range: NSRange(location: 0, length: str.length))
//    }
    
    /// 删除线
    override func style(strikethrough str: NSMutableAttributedString) {
        str.addAttributes([.strikethroughStyle:NSUnderlineStyle.single.rawValue], range: NSRange(location: 0, length: str.length))
    }
    
    /// 下划线
    override func style(underline str: NSMutableAttributedString) {
        str.addAttributes([.underlineStyle:NSUnderlineStyle.single.rawValue], range:  NSRange(location: 0, length: str.length))
    }
    
    override func style(color str: NSMutableAttributedString, color:UIColor) {
        str.addAttributes([.foregroundColor:color], range:  NSRange(location: 0, length: str.length))
    }
    
    func displaySize(opImage:OpImage) -> CGSize {
        // 没有宽和高的按照全屏
        if let width = (opImage.width as? NSString)?.doubleValue,let height = (opImage.height as? NSString)?.doubleValue {
            return SKDeltaStyler.displaySize(imageSize: CGSize(width: width, height: height), maxWidth: maxWidth)
        }
        return CGSize(width: maxWidth, height: 50)
    }
}

extension SKDeltaStyler : AsyncImageAttachmentDelegate {
    static func displaySize(imageSize:CGSize,maxWidth:CGFloat) -> CGSize {
        // 没有宽和高的按照全屏
        var rWidth = maxWidth
        var rHeight:CGFloat = 50
        var aspectRatio:CGFloat = 0;
        
        if (imageSize.width>0) {
            aspectRatio = imageSize.height/imageSize.width
        }
        rWidth = min(imageSize.width, maxWidth)
        rHeight = aspectRatio*rWidth
        return CGSize(width: rWidth, height: CGFloat(ceil(rHeight)))
    }
    
    
    static func calculateAttributedStringSize(for attributedString: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        var totalAttachmentHeight: CGFloat = 0
        var attachmentMaxWidth:CGFloat = 0
        
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        var attachmentIndexes: [Int] = []
        
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            if let attachment = value as? AsyncImageAttachment {
                attachmentIndexes.append(range.location)
                let attachmentHeight: CGFloat
                if let rSize = attachment.displaySize {
                    attachmentHeight = rSize.height
                    attachmentMaxWidth = max(attachmentMaxWidth, rSize.width)
                } else {
                    attachmentHeight = 0
                }
                totalAttachmentHeight += attachmentHeight
            }
        }
        //
        for index in attachmentIndexes.reversed() {
            mutableAttributedString.replaceCharacters(in: NSRange(location: index, length: 1), with: "")
        }
        
        // 创建一个CTFramesetter对象
        let framesetter = CTFramesetterCreateWithAttributedString(mutableAttributedString)
        
        // 创建一个CGRect，宽度为指定的宽度，高度设置为一个足够大的值
        let size = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        
        // 使用CTFramesetterSuggestFrameSizeWithConstraints来计算文本需要的尺寸
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, mutableAttributedString.length), nil, size, nil)
        
        
        return CGSize(width: min(maxWidth,max(attachmentMaxWidth, suggestedSize.width)), height: totalAttachmentHeight+suggestedSize.height)
    }
    
    static func size(for attributedString: NSAttributedString, withWidth maxWidth: CGFloat) -> CGSize {
        // 创建 CTFramesetter
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        
        let constraintSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        
        // 设置绘制区域
        let drawingRect = CGRect(origin: .zero, size: constraintSize)
        let path = CGMutablePath()
        path.addRect(drawingRect)
        
        // 创建 CTFrame
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        
        // 获取行数组
        let lines = CTFrameGetLines(frame) as! [CTLine]
        
        var totalHeight: CGFloat = 0
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        var width:CGFloat = 0
        // 计算每行的高度，包括处理 NSTextAttachment
        for line in lines {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            
            let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            width = max(CGFloat(lineWidth), width)
            totalHeight += ascent + descent + leading
        }
        
        return CGSize(width: width, height: ceil(totalHeight))
    }
    
    func textAttachmentDidLoadImage(textAttachment: AsyncImageAttachment, displaySizeChanged: Bool, url: String) {
        allRemoteImages.remove(url)
        loadingRemoteImages.remove(url)
        var userInfo:[AnyHashable : Any] = [:]
        if let messageId = messageId {
            userInfo["messageId"] = messageId
        }
        if loadingRemoteImages.count == 0{
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TextAttachmentDidLoadImage"), object: nil, userInfo: userInfo)
            textAttachment.delegate = nil
        }
    }
    
    func textAttachmentLoadImageFailed(textAttachment: AsyncImageAttachment, displaySizeChanged: Bool, url: String) {
        allRemoteImages.remove(url)
        loadingRemoteImages.remove(url)
        if loadingRemoteImages.count == 0 {
            var userInfo:[AnyHashable : Any] = [:]
            if let messageId = messageId {
                userInfo["messageId"] = messageId
            }
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TextAttachmentDidLoadImage"), object: nil, userInfo: userInfo)
            textAttachment.delegate = nil
        }
    }
    
    func textAttachmentWillLoadImage(textAttachment: AsyncImageAttachment, url: String) {
        loadingRemoteImages.insert(url)
    }
    
    func isLoadImage(textAttachment: AsyncImageAttachment, url: String) -> Bool {
        return loadingRemoteImages.contains(url)
    }
    
}

// MARK: - Helper extensions
fileprivate extension NSMutableAttributedString {
    
    func addAttributes(_ attrs: Attributes) {
        addAttributes(attrs, range: wholeRange)
    }
    
    func addAttribute(for key: Key, value: Any) {
        addAttribute(key, value: value, range: wholeRange)
    }
}

fileprivate extension NSAttributedString {
    
    typealias Attributes = [NSAttributedString.Key: Any]

    // MARK: - Ranges
    
    var wholeRange: NSRange {
        return NSRange(location: 0, length: length)
    }
    
    func removingAttachments() -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(attributedString: self)
        
        mutableAttributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableAttributedString.length), options: []) { value, range, _ in
            if let _ = value as? NSTextAttachment {
                mutableAttributedString.removeAttribute(.attachment, range: range)
            }
        }
        
        return NSAttributedString(attributedString: mutableAttributedString)
    }
}

private extension String {
    static var paragraphSeparator: String {
        return "\u{2029}"
    }

    // This code point allows line breaking, without starting a new paragraph.

    static var lineSeparator: String {
        return "\u{2028}"
    }
    
    static var lineBreak: String {
        return "\n"
    }

    static var zeroWidthSpace: String {
        return "\u{200B}"
    }
    
    var attributed: NSMutableAttributedString {
        return NSMutableAttributedString(string: self)
    }
    
    func findEmoji(pattern: String, emojiSet: Set<String>) -> [NSRange]? {
        guard !pattern.isEmpty, !self.isEmpty else {
            return nil
        }
        
        do {
            let regExp = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let resultArr = regExp.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
            var emojiRangeArr = [NSRange]()
            
            for result in resultArr {
                autoreleasepool {
                    let emojiRange = result.range
                    if let emojiName = Range(emojiRange, in: self).map({ String(self[$0]) }), emojiSet.contains(emojiName) {
                        emojiRangeArr.append(emojiRange)
                    }
                }
            }
            
            // 从大到小排序
            emojiRangeArr.sort { $0.location > $1.location }
            
            return emojiRangeArr
        } catch {
            print("Failed to find custom emoji positions: \(error)")
            return nil
        }
    }
}

public extension NSAttributedString {
    @objc func attributedString(upToNthNewline nthNewline: Int) -> NSAttributedString? {
        let fullString = self.string
        var newlineCount = 0
        var targetRange: NSRange?
        
        fullString.enumerateSubstrings(in: fullString.startIndex..<fullString.endIndex, options: .byLines) { (substring, substringRange, enclosingRange, stop) in
            newlineCount += 1
            if newlineCount == nthNewline {
                let location = fullString.distance(from: fullString.startIndex, to: substringRange.upperBound)
                targetRange = NSRange(location: 0, length: location)
                stop = true
            }
        }
        
        if let range = targetRange {
            let res =  NSMutableAttributedString()
            res.append(self.attributedSubstring(from: range))
            res.append(NSAttributedString(string: "..."))
            return res
        }
        
        return nil
    }
    
    @objc func attributedString(upToCharacters count: Int) -> NSAttributedString {
        let length = min(self.length, count)
        let range = NSRange(location: 0, length: length)
        return self.attributedSubstring(from: range)
    }
}
