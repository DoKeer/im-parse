//
//  UIKitMessageListViewController.swift
//  IMParseDemo
//
//  UIKit 版本的消息列表
//

import UIKit

class UIKitMessageListViewController: UIViewController {
    
    private var messages: [Message] = []
    private var tableView: UITableView!
    
    // 高度反馈回调：当 cell 渲染完成后，使用 Auto Layout 的实际高度更新估算值
    private var heightFeedbackCallbacks: [String: (CGFloat) -> Void] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "UIKit 消息列表"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        loadMessages()
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(MessageTableViewCell.self, forCellReuseIdentifier: "MessageCell")
        
        // 使用自动布局计算行高
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadMessages() {
        // 在后台线程生成消息
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let generatedMessages = MessageDataGenerator.generateMessages(count: 100)
            
            // 获取宽度（需要在主线程获取，或者假设屏幕宽度）
            let screenWidth = UIScreen.main.bounds.width
            // Cell layout: 16 (left) + 16 (right) for container, inside: 16 (left) + 16 (right) for content
            // Total horizontal padding = 32 + 32 = 64
            let contentWidth = screenWidth - 64
            
            // 解析消息并计算布局
            var parsedMessages = generatedMessages
            for i in 0..<parsedMessages.count {
                // calculateLayout 会自动调用 parse
                parsedMessages[i].calculateLayout(width: contentWidth)
            }
            
            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self?.messages = parsedMessages
                self?.tableView.reloadData()
            }
        }
    }
}

extension UIKitMessageListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageTableViewCell
        // 计算 contentWidth: Screen - 32 (Container Margin) - 32 (Content Padding) = Screen - 64
        let contentWidth = tableView.bounds.width - 64
        let message = messages[indexPath.row]
        
        // 设置高度反馈回调
        let messageId = message.id
        heightFeedbackCallbacks[messageId] = { [weak self] actualHeight in
            // 更新消息的实际高度（减去 cell 的固定间距）
            // Container Top (8) + Sender Top (12) + Sender Height (~17) + Spacing (8) + Content + Content Bottom (12) + Container Bottom (8)
            // Total extra ~= 70
            let contentHeight = actualHeight - 70
            if let index = self?.messages.firstIndex(where: { $0.id == messageId }) {
                self?.messages[index].estimatedHeight = max(0, contentHeight)
            }
        }
        
        cell.configure(
            with: message,
            width: contentWidth,
            viewController: self,
            onLayoutComplete: { [weak self] actualHeight in
                // 触发高度反馈
                self?.heightFeedbackCallbacks[messageId]?(actualHeight)
            }
        )
        return cell
    }
}

extension UIKitMessageListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        
        // 如果有预计算的高度，加上 Cell 的固定间距
        // Container Top (8) + Sender Top (12) + Sender Height (~17) + Spacing (8) + Content + Content Bottom (12) + Container Bottom (8)
        // Total extra ~= 65
        if let contentHeight = message.estimatedHeight {
            return contentHeight + 70
        }
       
        return UITableView.automaticDimension
    }
    
    // 使用自动布局，不需要实现 willDisplay 来预计算高度
    // Rust 端的高度计算不准确，因为它没有考虑到 UIKit 的实际布局（padding、spacing、容器视图等）
    // 系统会根据 cell 的约束自动计算高度
}

// MARK: - Message Cell

class MessageTableViewCell: UITableViewCell {
    
    private let containerView = UIView()
    private let senderLabel = UILabel()
    private let contentView_wrapper = UIView() // 避免与 contentView 冲突
    private let typeLabel = UILabel()
    private var message: Message?
    private weak var viewController: UIViewController?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 2
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        senderLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        senderLabel.textColor = .systemBlue
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        typeLabel.font = .systemFont(ofSize: 10, weight: .regular)
        typeLabel.textColor = .secondaryLabel
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.setContentHuggingPriority(.required, for: .vertical)
        typeLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        contentView_wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(senderLabel)
        containerView.addSubview(typeLabel)
        containerView.addSubview(contentView_wrapper)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            senderLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            senderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            senderLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeLabel.leadingAnchor, constant: -8),
            
            typeLabel.centerYAnchor.constraint(equalTo: senderLabel.centerYAnchor),
            typeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            contentView_wrapper.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 8),
            contentView_wrapper.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentView_wrapper.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentView_wrapper.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with message: Message, width: CGFloat, viewController: UIViewController? = nil, onLayoutComplete: ((CGFloat) -> Void)? = nil) {
        self.message = message
        self.viewController = viewController
        
        senderLabel.text = message.sender
        typeLabel.text = message.type.rawValue.uppercased()
        
        // 清除旧的内容视图
        contentView_wrapper.subviews.forEach { $0.removeFromSuperview() }
        
        // 移除旧的手势识别器
        containerView.gestureRecognizers?.forEach { containerView.removeGestureRecognizer($0) }
        
        // 添加长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        containerView.addGestureRecognizer(longPressGesture)
        
        // 优先使用预计算的布局
        if let layout = message.layout {
            let context = UIKitRenderContext(
                theme: .default,
                width: width,
                onLinkTap: { url in UIApplication.shared.open(url) },
                onImageTap: nil,
                onMentionTap: nil
            )
            
            let astView = layout.render(context: context)
            astView.translatesAutoresizingMaskIntoConstraints = false
            
            contentView_wrapper.addSubview(astView)
            
            // 使用 Auto Layout 约束，让系统自动计算高度
            NSLayoutConstraint.activate([
                astView.topAnchor.constraint(equalTo: contentView_wrapper.topAnchor),
                astView.leadingAnchor.constraint(equalTo: contentView_wrapper.leadingAnchor),
                astView.trailingAnchor.constraint(equalTo: contentView_wrapper.trailingAnchor),
                astView.bottomAnchor.constraint(equalTo: contentView_wrapper.bottomAnchor)
            ])
            
            // 布局完成后，使用 Auto Layout 的实际高度进行反馈
            // 使用下一个 run loop 来获取实际高度
            DispatchQueue.main.async { [weak self, weak astView] in
                guard let self = self, let astView = astView else { return }
                // 强制布局更新
                self.contentView_wrapper.setNeedsLayout()
                self.contentView_wrapper.layoutIfNeeded()
                
                // 等待下一个 run loop，确保布局完成
                DispatchQueue.main.async {
                    // 获取实际高度（astView 的高度，即 AST 内容的实际高度）
                    let actualHeight = astView.bounds.height
                    onLayoutComplete?(actualHeight)
                }
            }
            
            return
        }
        
        // 如果有 AST JSON，解析并渲染 AST
        if let astJSON = message.astJSON {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                do {
                    // 解析 JSON 字符串为 RootNode
                    guard let jsonData = astJSON.data(using: .utf8) else {
                        throw NSError(domain: "ParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to Data"])
                    }
                    
                    let decoder = JSONDecoder()
                    let rootNode = try decoder.decode(RootNode.self, from: jsonData)
                    
                    // 回到主线程渲染 AST
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        let renderer = UIKitRenderer()
                        let context = UIKitRenderContext(
                            theme: .default,
                            width: width - 32, // 减去 padding
                            onLinkTap: { url in
                                UIApplication.shared.open(url)
                            },
                            onImageTap: nil,
                            onMentionTap: nil
                        )
                        
                        let astView = renderer.render(ast: rootNode, context: context)
                        astView.translatesAutoresizingMaskIntoConstraints = false
                        self.contentView_wrapper.addSubview(astView)
                        
                        NSLayoutConstraint.activate([
                            astView.topAnchor.constraint(equalTo: self.contentView_wrapper.topAnchor),
                            astView.leadingAnchor.constraint(equalTo: self.contentView_wrapper.leadingAnchor),
                            astView.trailingAnchor.constraint(equalTo: self.contentView_wrapper.trailingAnchor),
                            astView.bottomAnchor.constraint(equalTo: self.contentView_wrapper.bottomAnchor)
                        ])
                        
                        // 布局完成后，使用 Auto Layout 的实际高度进行反馈
                        DispatchQueue.main.async { [weak self, weak astView] in
                            guard let self = self, let astView = astView else { return }
                            // 强制布局更新
                            self.contentView_wrapper.setNeedsLayout()
                            self.contentView_wrapper.layoutIfNeeded()
                            
                            // 等待下一个 run loop，确保布局完成
                            DispatchQueue.main.async {
                                // 获取实际高度（astView 的高度，即 AST 内容的实际高度）
                                let actualHeight = astView.bounds.height
                                onLayoutComplete?(actualHeight)
                            }
                        }
                    }
                } catch { 
                    // 解析失败，显示原始内容
                    print("Failed to parse AST JSON: \(error)")
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.showPlainText(message.content)
                    }
                }
            }
        } else {
            // 如果没有 AST，显示原始内容
            showPlainText(message.content)
            
            // 布局完成后反馈
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.contentView_wrapper.setNeedsLayout()
                self.contentView_wrapper.layoutIfNeeded()
                
                // 等待下一个 run loop，确保布局完成
                DispatchQueue.main.async {
                    let actualHeight = self.contentView_wrapper.bounds.height
                    onLayoutComplete?(actualHeight)
                }
            }
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let message = message,
              let viewController = viewController else {
            return
        }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "选择文本", style: .default) { [weak self] _ in
            self?.showHTMLView(for: message, from: viewController)
        })
        
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad 支持
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = containerView
            popover.sourceRect = containerView.bounds
        }
        
        viewController.present(alertController, animated: true)
    }
    
    private func showHTMLView(for message: Message, from viewController: UIViewController) {
        guard let html = message.toHTML() else {
            let alert = UIAlertController(
                title: "错误",
                message: "无法生成 HTML 内容",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        let htmlViewController = MessageHTMLViewController(html: html)
        let navigationController = UINavigationController(rootViewController: htmlViewController)
        viewController.present(navigationController, animated: true)
    }
    
    private func showPlainText(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView_wrapper.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView_wrapper.topAnchor),
            label.leadingAnchor.constraint(equalTo: contentView_wrapper.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView_wrapper.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentView_wrapper.bottomAnchor)
        ])
    }
}
