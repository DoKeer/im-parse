//
//  SwiftUIMessageListView.swift
//  IMParseDemo
//
//  SwiftUI 版本的消息列表
//

import SwiftUI

struct SwiftUIMessageListView: View {
    @State private var messages: [Message] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("加载消息...")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageRowView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("SwiftUI 消息列表")
            .onAppear {
                loadMessages()
            }
        }
    }
    
    private func loadMessages() {
        // 在后台线程生成消息
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedMessages = MessageDataGenerator.generateMessages(count: 1)
            
            // 解析消息
            var parsedMessages = generatedMessages
            for i in 0..<parsedMessages.count {
                parsedMessages[i].parse()
            }
            
            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self.messages = parsedMessages
                self.isLoading = false
            }
        }
    }
}

// MARK: - Message Row View

struct MessageRowView: View {
    let message: Message
    @State private var astNode: RootNode?
    @State private var estimatedHeight: CGFloat?
    @State private var showHTMLView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 发送者信息
            HStack {
                Text(message.sender)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(message.type.rawValue.uppercased())
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // 消息内容
            if let astNode = astNode {
                MessageASTView(node: astNode)
            } else if let astJSON = message.astJSON {
                // 解析 AST JSON
                Text("解析 AST...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .onAppear {
                        parseAST(from: astJSON)
                    }
            } else {
                // 显示原始内容
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .contextMenu {
            Button(action: {
                showHTMLView = true
            }) {
                Label("选择文本", systemImage: "text.cursor")
            }
        }
        .sheet(isPresented: $showHTMLView) {
            if let html = message.toHTML() {
                MessageHTMLView(html: html)
            }
        }
    }
    
    private func parseAST(from json: String) {
        DispatchQueue.global(qos: .utility).async {
            do {
                // 解析 JSON 字符串为 RootNode
                guard let jsonData = json.data(using: .utf8) else {
                    throw NSError(domain: "ParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to Data"])
                }
                
                let decoder = JSONDecoder()
                let rootNode = try decoder.decode(RootNode.self, from: jsonData)
                
                // 回到主线程更新 UI
                DispatchQueue.main.async {
                    // 将 RootNode 转换为 ASTNode（用于渲染）
                    // 由于 RootNode 本身就是 ASTNode，直接使用
                    self.astNode = rootNode
                }
            } catch {
                // 解析失败，记录错误但不阻塞 UI
                print("Failed to parse AST JSON: \(error)")
                DispatchQueue.main.async {
                    // 解析失败时保持 astNode 为 nil，显示原始内容
                    self.astNode = nil
                }
            }
        }
    }
}

// MARK: - AST View

struct MessageASTView: View {
    let node: RootNode
    
    var body: some View {
        let renderer = SwiftUIRenderer()
        let context = RenderContext(
            theme: .default,
            width: UIScreen.main.bounds.width - 64, // 减去 padding
            onLinkTap: { url in
                UIApplication.shared.open(url)
            },
            onImageTap: nil,
            onMentionTap: nil
        )
        return renderer.render(ast: node, context: context)
    }
}

// MARK: - Preview

struct SwiftUIMessageListView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIMessageListView()
    }
}

