//
//  Message.swift
//  IMParseSDK
//
//  消息模型
//

import Foundation
import UIKit

/// 消息类型
public enum MessageType: String, Codable {
    case markdown
    case delta
}

/// 消息模型
public struct Message: Identifiable, Codable {
    public let id: String
    public let type: MessageType
    public let content: String
    public let sender: String
    public let timestamp: Date
    public var astJSON: String?
    public var estimatedHeight: CGFloat?
    
    // 异步计算的布局结果 (不参与 Codable)
    public var layout: NodeLayout?
    
    enum CodingKeys: String, CodingKey {
        case id, type, content, sender, timestamp, astJSON, estimatedHeight
    }
    
    public init(id: String = UUID().uuidString,
         type: MessageType,
         content: String,
         sender: String,
         timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
    }
    
    /// 解析消息内容为 AST
    public mutating func parse() {
        let result: ParseResult
        switch type {
        case .markdown:
            result = IMParseCore.parseMarkdown(content)
        case .delta:
            result = IMParseCore.parseDelta(content)
        }
        
        if result.success {
            self.astJSON = result.astJSON
        }
    }
    

    /// 异步计算布局（使用 UIKitRenderer）
    /// 这将在后台线程中执行完整的文本测量和布局计算
    public mutating func calculateLayout(width: CGFloat) {
        // 确保 AST 已解析
        if astJSON == nil {
            parse()
        }
        
        guard let astJSON = astJSON,
              let jsonData = astJSON.data(using: .utf8),
              let rootNode = try? JSONDecoder().decode(RootNode.self, from: jsonData) else {
            return
        }
        
        // 创建布局上下文
        let context = UIKitRenderContext(
            theme: .default, // 使用默认主题，实际项目中可能需要从配置获取
            width: width,
            onLinkTap: nil,
            onImageTap: nil,
            onMentionTap: nil
        )
        
        // 计算布局
        self.layout = UIKitLayoutCalculator.calculateLayout(ast: rootNode, context: context)
        self.estimatedHeight = self.layout?.frame.height
    }
    
    /// 转换为 HTML
    public func toHTML() -> String? {
        return toHTML(config: nil)
    }
    
    /// 转换为 HTML（使用样式配置）
    public func toHTML(config: StyleConfig?) -> String? {
        let result: ParseResult
        switch type {
        case .markdown:
            result = IMParseCore.markdownToHTML(content, config: config)
        case .delta:
            result = IMParseCore.deltaToHTML(content, config: config)
        }
        
        return result.success ? result.astJSON : nil
    }
}

