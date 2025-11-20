//
//  UIKitMessageListViewController.swift
//  IMParseDemo
//
//  UIKit 版本的消息列表
//

import UIKit
import IMParseSDK
import Kingfisher

class UIKitMessageListViewController: UIViewController {
    
    private var messages: [Message] = []
    private var tableView: UITableView!
    
    // 不再需要高度反馈系统，直接使用预计算的高度
    
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
        // 在主线程获取屏幕宽度，避免 iOS 26.0 的弃用警告
        let screenWidth: CGFloat
        if #available(iOS 13.0, *), let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenWidth = windowScene.screen.bounds.width
        } else {
            screenWidth = UIScreen.main.bounds.width
        }
        // Cell layout: 16 (left) + 16 (right) for container, inside: 16 (left) + 16 (right) for content
        // Total horizontal padding = 32 + 32 = 64
        let contentWidth = screenWidth - 64
        
        // 在后台线程生成消息
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let generatedMessages = MessageDataGenerator.generateMessages(count: 100)
            
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
        
        cell.configure(
            with: message,
            width: contentWidth,
            viewController: self,
            onLayoutComplete: nil // 不再需要反馈，直接使用预计算高度
        )
        return cell
    }
}

extension UIKitMessageListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        
        // 如果有预计算的布局，使用精确的高度
        // Container Top (8) + Sender Top (12) + Sender Height (~17) + Spacing (8) + Content + Content Bottom (12) + Container Bottom (8)
        // Total extra ~= 70
        if let layout = message.layout {
            return layout.frame.height + 70
        }
        
        // 如果有估算高度，使用它
        if let contentHeight = message.estimatedHeight {
            return contentHeight + 70
        }
       
        // 否则返回估算值
        return 100
    }
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
        
        // 创建高度变化回调，通过 viewController 通知 tableView 更新
        let onHeightChanged: ((CGFloat) -> Void)? = { [weak viewController] _ in
            guard let viewController = viewController as? UIKitMessageListViewController else { return }
            // 通知 table view 更新 cell 高度
            DispatchQueue.main.async {
                let tableView = viewController.tableView
//                tableView.beginUpdates()
//                tableView.endUpdates()
            }
        }
        
        // 优先使用预计算的布局
        if let layout = message.layout {
            let context = UIKitRenderContext(
                theme: .default,
                width: width,
                onLinkTap: { url in UIApplication.shared.open(url) },
                onImageTap: nil,
                onMentionTap: nil,
                imageLoaderDelegate: viewController as? UIKitImageLoaderDelegate,
                onLayoutHeightChanged: onHeightChanged
            )
            
            let astView = layout.render(context: context)
            // 使用 frame 布局，不使用 Auto Layout
            astView.frame = CGRect(origin: .zero, size: layout.frame.size)
            
            contentView_wrapper.addSubview(astView)
            
            // 直接使用计算出的高度，不需要等待布局
            let actualHeight = layout.frame.height
            onLayoutComplete?(actualHeight)
            
            return
        }
        
        // 如果有 AST JSON，解析并计算布局
        if let astJSON = message.astJSON {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                do {
                    // 解析 JSON 字符串为 RootNode
                    guard let jsonData = astJSON.data(using: .utf8) else {
                        throw NSError(domain: "ParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to Data"])
                    }
                    
                    let decoder = JSONDecoder()
                    let rootNode = try decoder.decode(RootNode.self, from: jsonData)
                    
                    // 计算布局
                    let context = UIKitRenderContext(
                        theme: .default,
                        width: width,
                        onLinkTap: { url in UIApplication.shared.open(url) },
                        onImageTap: nil,
                        onMentionTap: nil,
                        imageLoaderDelegate: viewController as? UIKitImageLoaderDelegate,
                        onLayoutHeightChanged: onHeightChanged
                    )
                    
                    // 使用 UIKitRenderer 的 frame 渲染方法
                    let renderer = UIKitRenderer()
                    
                    // 回到主线程渲染
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        // 使用 renderWithFrame 方法，它内部使用 UIKitLayoutCalculator 计算布局
                        let astView = renderer.renderWithFrame(ast: rootNode, context: context)
                        // 使用 frame 布局
                        astView.frame = CGRect(origin: .zero, size: astView.bounds.size)
                        self.contentView_wrapper.addSubview(astView)
                        
                        // 使用计算出的高度
                        let actualHeight = astView.bounds.height
                        onLayoutComplete?(actualHeight)
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
            
            // 计算纯文本高度
            if let onLayoutComplete = onLayoutComplete {
                let text = message.content
                let font = UIFont.systemFont(ofSize: 16)
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font],
                    context: nil
                ).size
                let textHeight = ceil(size.height)
                onLayoutComplete(textHeight)
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

// MARK: - UIKitImageLoaderDelegate

extension UIKitMessageListViewController: UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView, completion: @escaping (UIImage?, Error?) -> Void) {
        // 使用 Kingfisher 加载图片
        imageView.kf.setImage(
            with: url,
            placeholder: nil,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ],
            completionHandler: { result in
                switch result {
                case .success(let value):
                    completion(value.image, nil)
                case .failure(let error):
                    completion(nil, error)
                }
            }
        )
    }
}
