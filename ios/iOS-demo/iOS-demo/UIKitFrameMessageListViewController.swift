//
//  UIKitFrameMessageListViewController.swift
//  IMParseDemo
//
//  UIKit Frame 布局版本的消息列表
//

import UIKit
import IMParseSDK
import Kingfisher

class UIKitFrameMessageListViewController: UIViewController {
    
    private var messages: [Message] = []
    private var tableView: UITableView!
    private var layouting:Bool = false
    // 使用 Kingfisher 的图片缓存来缓存数学公式和 Mermaid 图表的图片
    // 不再需要高度反馈系统，直接使用预计算的高度
    
    // 全局共享的渲染上下文
    private var sharedRenderContext: UIKitRenderContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "UIKit Frame 消息列表"
        view.backgroundColor = .systemBackground
        
        setupSharedRenderContext()
        setupTableView()
        setupCache()
    }
    
    /// 初始化全局共享的渲染上下文
    private func setupSharedRenderContext() {
        sharedRenderContext = UIKitRenderContext(
            theme: UIKitTheme.default,
            width: 0, // 宽度会在使用时更新
            onLinkTap: { url in
                // URL 打开浏览器
                UIApplication.shared.open(url)
            },
            onImageTap: { [weak self] imageNode in
                // 图片弹出图片预览页面
                guard let self = self else { return }
                MessageTableViewCell.showImagePreview(imageNode: imageNode, from: self)
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
            imageLoaderDelegate: self,
            formulaSizeCacheDelegate: self,
            inlineImageLoaderDelegate: self,
            toolbarActionDelegate: self
        )
    }
    
    private func setupCache() {
        // Kingfisher 会自动处理内存警告和缓存清理
        // 不需要手动监听内存警告
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
        // Cell layout: 16 (left) + 16 (right) for container, inside: 16 (left) + 16 (right) for content
        // Total horizontal padding = 32 + 32 = 64
        let contentWidth = self.contentWidth
        
        // 在后台线程生成消息
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let generatedMessages = MessageDataGenerator.generateMessages(count: 1)
            
            // 解析消息并计算布局
            var parsedMessages = generatedMessages
            for i in 0..<parsedMessages.count {
                // calculateLayout 会自动调用 parse
                parsedMessages[i].calculateLayout(width: contentWidth, delegate: self)
            }
            
            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self?.messages = parsedMessages
                self?.tableView.reloadData()
            }
        }
    }
    
    private var contentWidth:CGFloat = 0
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if messages.isEmpty {
            if abs(contentWidth - self.view.frame.width) > 64 {
                contentWidth = self.view.frame.width - 64
                loadMessages()
            }
        }
    }

    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        layouting = true
        print("尺寸变化：\(size)，\(view.frame.size.width - size.width)")
        if abs(view.frame.size.width - size.width) >= 1.0 {
            layouting = false
            contentWidth = size.width - 64
            loadMessages()
        }
    }
    
}

extension UIKitFrameMessageListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageTableViewCell
        // 计算 contentWidth: Screen - 32 (Container Margin) - 32 (Content Padding) = Screen - 64
        let message = messages[indexPath.row]
        
        // 创建节点布局变化回调（在 viewController 中处理）
        let onNodeLayoutChanged: ((any Codable) -> Void)? = { [weak tableView, weak self] updatedNodeLayout in
            DispatchQueue.main.async {
                if let layouting = self?.layouting, layouting == true {
                    return
                }
                guard let tableView = tableView,
                      let self = self,
                      indexPath.row < self.messages.count else { return }
                
                // 递归查找并替换匹配的节点
//                    layout = updateNodeLayout(in: layout, with: updatedNodeLayout)
                self.messages[indexPath.row].layout = nil;
                self.messages[indexPath.row].calculateLayout(width: self.contentWidth, delegate: self)
                
                tableView.reloadRows(at: [indexPath], with: .none)

            }
        }
        
        // 更新共享的渲染上下文中的动态部分
        sharedRenderContext.width = contentWidth
        sharedRenderContext.onNodeLayoutChanged = onNodeLayoutChanged
        
        cell.configure(
            with: message,
            indexPath: indexPath,
            width: contentWidth,
            viewController: self,
            context: sharedRenderContext,
            onNodeLayoutChanged: onNodeLayoutChanged
        )
        return cell
    }
}

extension UIKitFrameMessageListViewController: UITableViewDelegate {
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
    private var lastReportedHeight: CGFloat = 0 // 记录上次报告的高度，防止重复调用
    private var isConfiguring = false // 防止在配置过程中重复调用
    
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
    
    func configure(with message: Message, indexPath: IndexPath, width: CGFloat, viewController: UIViewController? = nil, context: UIKitRenderContext, onNodeLayoutChanged: ((any Codable) -> Void)? = nil) {
        self.message = message
        self.viewController = viewController
        
        // 重置标志
        isConfiguring = true
        lastReportedHeight = 0
        
        senderLabel.text = message.sender
        typeLabel.text = message.type.rawValue.uppercased()
        
        // 清除旧的内容视图
        contentView_wrapper.subviews.forEach { $0.removeFromSuperview() }
        
        // 移除旧的手势识别器
        containerView.gestureRecognizers?.forEach { containerView.removeGestureRecognizer($0) }
        
        // 添加长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        containerView.addGestureRecognizer(longPressGesture)
        
        // 使用全局共享的渲染上下文（动态部分已在调用处更新）
        
        // 优先使用预计算的布局
        if let layout = message.layout {
            
            let astView = layout.render(context: context)
            // 使用 frame 布局，不使用 Auto Layout
            astView.frame = CGRect(origin: .zero, size: layout.frame.size)
            
            contentView_wrapper.addSubview(astView)
            
            // 直接使用计算出的高度，不需要等待布局
            // 对于预计算的布局，高度已经确定，不需要触发 onLayoutComplete
            // 因为 heightForRowAt 已经使用了预计算的高度
            isConfiguring = false
            lastReportedHeight = layout.frame.height + 70
            
            return
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
    
    
    /// 显示图片预览
    static func showImagePreview(imageNode: ImageNode, from viewController: UIViewController) {
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

// MARK: - UIKitInlineImageLoaderDelegate

extension UIKitFrameMessageListViewController: UIKitInlineImageLoaderDelegate {
    func loadEmojiImage(content: String, size: CGFloat, completion: @escaping (UIImage?) -> Void) {
        // Emoji content 格式应该是类似 "[加油]" 这样的
        // 对应的文件名是 "[加油].png"
        let imageName = "\(content).png"
        
        // 在后台线程加载图片，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async {
            var image: UIImage?
            
            // 首先尝试从 main bundle 加载
            if let loadedImage = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil) {
                image = loadedImage
            }
            // 如果 main bundle 中没有，尝试从 Emojis 文件夹加载
            else if let emojiPath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Emojis"),
                    let loadedImage = UIImage(contentsOfFile: emojiPath) {
                image = loadedImage
            }
            // 如果还是找不到，尝试从 Emojis bundle 加载
            else if let emojiBundlePath = Bundle.main.path(forResource: "Emojis", ofType: nil),
                    let emojiBundle = Bundle(path: emojiBundlePath),
                    let loadedImage = UIImage(named: imageName, in: emojiBundle, compatibleWith: nil) {
                image = loadedImage
            }
            
            // 回到主线程调用 completion
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    func loadMentionStatusImage(mentionNode: MentionNode, completion: @escaping (UIImage?) -> Void) {
        // 根据 mention 节点的 id 或 name 判断已读/未读状态
        // 这里示例：如果 id 是 "all"，显示已读图片；否则显示未读图片
        let imageName: String
        if mentionNode.id == "all" {
            imageName = "mention_read.png" // 已读图片
        } else {
            imageName = "mention_unread.png" // 未读图片
        }
        
        // 在后台线程加载图片
        DispatchQueue.global(qos: .userInitiated).async {
            var image: UIImage?
            
            // 尝试从 main bundle 加载
            if let loadedImage = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil) {
                image = loadedImage
            }
            // 如果找不到，返回 nil（不显示状态图片）
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}

// MARK: - UIKitImageLoaderDelegate

extension UIKitFrameMessageListViewController: UIKitImageLoaderDelegate {
    func loadImage(url: URL, into imageView: UIImageView?, completion: @escaping (UIImage?, Error?) -> Void) {
        if let imageView = imageView {
            // 使用 Kingfisher 加载图片到 imageView
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
        } else {
            // 如果 imageView 为空，直接从 Kingfisher 缓存读取图片
            ImageCache.default.retrieveImage(forKey: url.absoluteString) { result in
                switch result {
                case .success(let value):
                    if let image = value.image {
                        // 缓存命中，直接返回
                        completion(image, nil)
                    } else {
                        // 缓存未命中，从网络下载
                        KingfisherManager.shared.retrieveImage(with: url, options: [.cacheOriginalImage]) { result in
                            switch result {
                            case .success(let value):
                                completion(value.image, nil)
                            case .failure(let error):
                                completion(nil, error)
                            }
                        }
                    }
                case .failure:
                    // 缓存读取失败，从网络下载
                    KingfisherManager.shared.retrieveImage(with: url, options: [.cacheOriginalImage]) { result in
                        switch result {
                        case .success(let value):
                            completion(value.image, nil)
                        case .failure(let error):
                            completion(nil, error)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UIKitFormulaSizeCacheDelegate

extension UIKitFrameMessageListViewController: UIKitFormulaSizeCacheDelegate {
    /// 获取缓存的尺寸
    /// 从 Kingfisher 的图片缓存中读取图片，然后返回图片尺寸
    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
    /// - Returns: 缓存的尺寸，如果不存在则返回nil
    func getCachedSize(for key: String) -> CGSize? {
        // 生成 Kingfisher 缓存键
        let cacheKey = generateCacheKey(for: key)
        
        // 从 Kingfisher 内存缓存中同步读取图片
        if let cachedImage = ImageCache.default.retrieveImageInMemoryCache(forKey: cacheKey) {
            // 从内存缓存中获取尺寸
            return cachedImage.size
        }
        
        // 注意：Kingfisher 的磁盘读取是异步的，这里我们只检查内存缓存
        // 如果内存缓存中没有，返回 nil，布局计算会使用估算高度
        // 当图片从磁盘加载到内存后，会触发高度刷新
        return nil
    }
    
    /// 保存尺寸到缓存
    /// 实际上，这个方法会在图片渲染完成后被调用，此时图片已经保存到 Kingfisher 缓存
    /// 这里我们只需要记录尺寸信息（可选，因为可以从图片中获取）
    /// - Parameters:
    ///   - size: 要缓存的尺寸
    ///   - key: 缓存键（公式或Mermaid的内容字符串）
    func setCachedSize(_ size: CGSize, for key: String) {
        // 图片已经通过 saveFormulaImage 方法保存到 Kingfisher 缓存
        // 这里不需要额外操作，因为尺寸可以从缓存的图片中获取
    }
    
    /// 保存公式图片到 Kingfisher 缓存
    /// - Parameters:
    ///   - image: 要缓存的图片
    ///   - key: 缓存键（公式或Mermaid的内容字符串）
    func saveFormulaImage(_ image: UIImage, for key: String) {
        let cacheKey = generateCacheKey(for: key)
        // 保存到 Kingfisher 缓存（包括内存和磁盘）
        ImageCache.default.store(image, forKey: cacheKey, toDisk: true)
    }
    
    /// 获取缓存的公式图片（同步方法，用于协议实现）
    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
    /// - Returns: 缓存的图片，如果不存在则返回nil
    func getFormulaImage(for key: String) -> UIImage? {
        let cacheKey = generateCacheKey(for: key)
        // 先从内存缓存读取（快速）
        if let memoryImage = ImageCache.default.retrieveImageInMemoryCache(forKey: cacheKey) {
            return memoryImage
        }
        
        // 如果内存缓存没有，从磁盘缓存同步读取（使用信号量等待异步结果）
        var diskImage: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        ImageCache.default.retrieveImage(forKey: cacheKey) { result in
            switch result {
            case .success(let value):
                diskImage = value.image
            case .failure:
                diskImage = nil
            }
            semaphore.signal()
        }
        
        // 等待异步结果，最多等待 0.01 秒
        _ = semaphore.wait(timeout: .now() + .milliseconds(10))
        return diskImage
    }
    
    /// 从 Kingfisher 缓存获取公式图片（异步方法，用于内部调用）
    /// - Parameters:
    ///   - key: 缓存键
    ///   - completion: 完成回调，返回缓存的图片
    func getCachedFormulaImage(for key: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = generateCacheKey(for: key)
        // 从 Kingfisher 缓存中读取（包括内存和磁盘）
        ImageCache.default.retrieveImage(forKey: cacheKey) { result in
            switch result {
            case .success(let value):
                completion(value.image)
            case .failure:
                completion(nil)
            }
        }
    }
    
    /// 生成缓存键（参考 Kingfisher 的键生成策略）
    /// - Parameter key: 原始键
    /// - Returns: 处理后的缓存键
    private func generateCacheKey(for key: String) -> String {
        // Kingfisher 使用 MD5 哈希，这里我们使用简单的处理
        // 如果键太长，使用哈希
        if key.count > 200 {
            // 对于过长的键，使用哈希
            return "formula_hash_\(key.hash)"
        }
        // 添加前缀以区分公式图片和其他图片
        return "formula_\(key)"
    }
}

// MARK: - UIKitToolbarActionDelegate

extension UIKitFrameMessageListViewController: UIKitToolbarActionDelegate {
    /// 复制内容
    func copyContent(_ content: String, type: String) {
        UIPasteboard.general.string = content
        
        // 显示复制成功提示
        let alert = UIAlertController(
            title: "已复制",
            message: "\(type == "math" ? "数学公式" : type == "mermaid" ? "Mermaid 图表" : "表格")内容已复制到剪贴板",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    /// 下载内容（图片或代码）
    func downloadContent(_ content: String, type: String, image: UIImage?) {
        if let image = image {
            // 保存图片到相册
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        } else {
            // 保存代码为文本文件
            saveCodeToFile(content: content, type: type)
        }
    }
    
    /// 全屏显示
    func showFullscreen(_ content: String, type: String, image: UIImage?) {
        if let image = image {
            // 显示图片全屏预览
            let fullscreenVC = FullscreenImageViewController(image: image, title: type == "math" ? "数学公式" : "Mermaid 图表")
            let navController = UINavigationController(rootViewController: fullscreenVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        } else {
            // 显示代码全屏预览
            let fullscreenVC = FullscreenCodeViewController(content: content, type: type)
            let navController = UINavigationController(rootViewController: fullscreenVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    /// 图片保存完成回调
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let alert = UIAlertController(
                title: "保存失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(
                title: "保存成功",
                message: "图片已保存到相册",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
    
    /// 保存代码为文本文件
    private func saveCodeToFile(content: String, type: String) {
        let fileName = "\(type)_\(Date().timeIntervalSince1970).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // 使用 UIActivityViewController 分享文件
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            present(activityVC, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "保存失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - Fullscreen Image View Controller

/// 全屏图片预览视图控制器
class FullscreenImageViewController: UIViewController {
    private let image: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    
    init(image: UIImage, title: String) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        // 设置导航栏
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        // 设置滚动视图
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 设置图片视图
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
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
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

extension FullscreenImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: - Fullscreen Code View Controller

/// 全屏代码预览视图控制器
class FullscreenCodeViewController: UIViewController {
    private let content: String
    private let type: String
    private let textView = UITextView()
    
    init(content: String, type: String) {
        self.content = content
        self.type = type
        super.init(nibName: nil, bundle: nil)
        self.title = type == "math" ? "数学公式代码" : type == "mermaid" ? "Mermaid 代码" : "表格内容"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // 设置导航栏
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )
        
        // 设置文本视图
        textView.text = content
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
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
