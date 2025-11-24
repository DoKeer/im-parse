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
            let generatedMessages = MessageDataGenerator.generateMessages(count: 1)
            
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
        
        // 创建渲染上下文（包含所有点击事件处理）
        let context = createRenderContext(
            width: width,
            viewController: viewController,
            onHeightChanged: onHeightChanged
        )
        
        // 优先使用预计算的布局
        if let layout = message.layout {
            
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
                    
                    // 创建渲染上下文（包含所有点击事件处理）
                    let context = self?.createRenderContext(
                        width: width,
                        viewController: viewController,
                        onHeightChanged: onHeightChanged
                    )
                    
                    guard let context = context else { return }
                    
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
    
    /// 创建渲染上下文，包含所有点击事件处理
    private func createRenderContext(
        width: CGFloat,
        viewController: UIViewController?,
        onHeightChanged: ((CGFloat) -> Void)?
    ) -> UIKitRenderContext {
        return UIKitRenderContext(
            theme: UIKitTheme.default,
            width: width,
            onLinkTap: { url in
                // URL 打开浏览器
                UIApplication.shared.open(url)
            },
            onImageTap: { [weak viewController] imageNode in
                // 图片弹出图片预览页面
                guard let viewController = viewController else { return }
                MessageTableViewCell.showImagePreview(imageNode: imageNode, from: viewController)
            },
            onMentionTap: { mentionNode in
                // Mention 打印 log
                print("Mention 被点击: @\(mentionNode.name)")
            },
            onCodeBlockTap: { codeBlockNode in
                // 代码块点击：打印 log
                print("代码块被点击，内容长度: \(codeBlockNode.content.count) 字符")
            },
            onMathTap: { mathNode in
                // 数学公式点击：打印 log
                print("数学公式被点击: \(mathNode.display ? "块级" : "行内") - \(mathNode.content)")
            },
            onMermaidTap: { mermaidNode in
                // Mermaid 图表点击：打印 log
                print("Mermaid 图表被点击，内容长度: \(mermaidNode.content.count) 字符")
            },
            imageLoaderDelegate: viewController as? UIKitImageLoaderDelegate,
            onLayoutHeightChanged: onHeightChanged
        )
    }
    
    /// 显示图片预览
    private static func showImagePreview(imageNode: ImageNode, from viewController: UIViewController) {
        guard let url = URL(string: imageNode.url) else {
            let alert = UIAlertController(
                title: "错误",
                message: "无效的图片 URL",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        // 创建图片预览视图控制器
        let imagePreviewVC = ImagePreviewViewController(imageURL: url, imageNode: imageNode)
        let navigationController = UINavigationController(rootViewController: imagePreviewVC)
        viewController.present(navigationController, animated: true)
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

// MARK: - Image Preview View Controller

/// 图片预览视图控制器
class ImagePreviewViewController: UIViewController {
    private let imageURL: URL
    private let imageNode: ImageNode
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    init(imageURL: URL, imageNode: ImageNode) {
        self.imageURL = imageURL
        self.imageNode = imageNode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupUI()
        loadImage()
        setupNavigationBar()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        
        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 添加双击手势放大/缩小
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapGesture)
        
        // 添加单击手势关闭
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        view.addGestureRecognizer(singleTapGesture)
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closePreview)
        )
        
        // 设置导航栏样式为深色，以便在黑色背景上可见
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
    }
    
    private func loadImage() {
        activityIndicator.startAnimating()
        
        // 使用 Kingfisher 加载图片
        imageView.kf.setImage(
            with: imageURL,
            placeholder: nil,
            options: [
                .transition(.fade(0.3)),
                .cacheOriginalImage
            ],
            completionHandler: { [weak self] result in
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    switch result {
                    case .success(let value):
                        self?.imageView.image = value.image
                        // 调整图片大小以适应屏幕
                        self?.updateImageViewSize(image: value.image)
                    case .failure(let error):
                        self?.showError(message: "图片加载失败: \(error.localizedDescription)")
                    }
                }
            }
        )
    }
    
    private func updateImageViewSize(image: UIImage) {
        let imageSize = image.size
        let viewSize = scrollView.bounds.size
        
        guard imageSize.width > 0 && imageSize.height > 0 && viewSize.width > 0 && viewSize.height > 0 else {
            return
        }
        
        let imageAspectRatio = imageSize.width / imageSize.height
        let viewAspectRatio = viewSize.width / viewSize.height
        
        var newSize: CGSize
        if imageAspectRatio > viewAspectRatio {
            // 图片更宽，以宽度为准
            newSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspectRatio)
        } else {
            // 图片更高，以高度为准
            newSize = CGSize(width: viewSize.height * imageAspectRatio, height: viewSize.height)
        }
        
        imageView.frame = CGRect(origin: .zero, size: newSize)
        scrollView.contentSize = newSize
        
        // 居中显示
        let offsetX = max(0, (viewSize.width - newSize.width) / 2)
        let offsetY = max(0, (viewSize.height - newSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(
            title: "错误",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.closePreview()
        })
        present(alert, animated: true)
    }
    
    @objc private func handleSingleTap() {
        closePreview()
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // 缩小
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // 放大到点击位置
            let point = gesture.location(in: imageView)
            let zoomScale = scrollView.maximumZoomScale
            let zoomRect = CGRect(
                x: point.x - scrollView.bounds.width / (2 * zoomScale),
                y: point.y - scrollView.bounds.height / (2 * zoomScale),
                width: scrollView.bounds.width / zoomScale,
                height: scrollView.bounds.height / zoomScale
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    @objc private func closePreview() {
        dismiss(animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let image = imageView.image {
            updateImageViewSize(image: image)
        }
    }
}

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 保持图片居中
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
}
