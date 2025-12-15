////
////  UIKitAutoLayoutMessageListViewController.swift
////  IMParseDemo
////
////  UIKit Auto Layout 布局版本的消息列表
////
//
//import UIKit
//import IMParseSDK
//import Kingfisher
//
//class UIKitAutoLayoutMessageListViewController: UIViewController {
//    
//    private var messages: [Message] = []
//    private var tableView: UITableView!
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        title = "UIKit Auto Layout 消息列表"
//        view.backgroundColor = .systemBackground
//        
//        setupTableView()
//        setupCache()
//        loadMessages()
//    }
//    
//    private func setupCache() {
//        // Kingfisher 会自动处理内存警告和缓存清理
//        // 不需要手动监听内存警告
//    }
//    
//    
//    private func setupTableView() {
//        tableView = UITableView(frame: .zero, style: .plain)
//        tableView.translatesAutoresizingMaskIntoConstraints = false
//        tableView.delegate = self
//        tableView.dataSource = self
//        tableView.separatorStyle = .none
//        tableView.backgroundColor = .systemGroupedBackground
//        tableView.register(AutoLayoutMessageTableViewCell.self, forCellReuseIdentifier: "MessageCell")
//        
//        // 使用自动布局计算行高
////        tableView.estimatedRowHeight = 100
//        tableView.rowHeight = UITableView.automaticDimension
//        
//        view.addSubview(tableView)
//        
//        NSLayoutConstraint.activate([
//            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//    }
//    
//    private func loadMessages() {
//        // 在后台线程生成消息
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            let generatedMessages = MessageDataGenerator.generateMessages(count: 5)
//            
//            // 解析消息（不需要预计算布局，Auto Layout 会自动计算）
//            var parsedMessages = generatedMessages
//            for i in 0..<parsedMessages.count {
//                parsedMessages[i].parse()
//            }
//            
//            // 回到主线程更新 UI
//            DispatchQueue.main.async {
//                self?.messages = parsedMessages
//                self?.tableView.reloadData()
//            }
//        }
//    }
//}
//
//extension UIKitAutoLayoutMessageListViewController: UITableViewDataSource {
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return messages.count
//    }
//    
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! AutoLayoutMessageTableViewCell
//        // 计算 contentWidth: Screen - 32 (Container Margin) - 32 (Content Padding) = Screen - 64
//        let contentWidth = tableView.bounds.width - 64
//        let message = messages[indexPath.row]
//        
//        cell.configure(
//            with: message,
//            width: contentWidth,
//            viewController: self,
//            onLayoutComplete: { [weak tableView, weak self] in
//                DispatchQueue.main.async {
//                    guard let tableView = tableView,
//                          let self = self,
//                          indexPath.row < self.messages.count else { return }
//                    
//                    // 使用 beginUpdates/endUpdates 来触发高度重新计算
//                    tableView.beginUpdates()
//                    tableView.endUpdates()
//                }
//            }
//        )
//        return cell
//    }
//}
//
//extension UIKitAutoLayoutMessageListViewController: UITableViewDelegate {
//    // Auto Layout 模式下，使用 automaticDimension，不需要实现 heightForRowAt
//}
//
//// MARK: - Message Cell
//
//class AutoLayoutMessageTableViewCell: UITableViewCell {
//    
//    private let containerView = UIView()
//    private let senderLabel = UILabel()
//    private let contentView_wrapper = UIView() // 避免与 contentView 冲突
//    private let typeLabel = UILabel()
//    private var message: Message?
//    private weak var viewController: UIViewController?
//    private var currentConfigurationId: UUID? // 用于跟踪当前配置，避免重用时的异步操作覆盖
//    
//    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
//        super.init(style: style, reuseIdentifier: reuseIdentifier)
//        setupUI()
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    private func setupUI() {
//        selectionStyle = .none
//        backgroundColor = .clear
//        
//        containerView.backgroundColor = .systemBackground
//        containerView.layer.cornerRadius = 12
//        containerView.layer.shadowColor = UIColor.black.cgColor
//        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
//        containerView.layer.shadowOpacity = 0.1
//        containerView.layer.shadowRadius = 2
//        containerView.translatesAutoresizingMaskIntoConstraints = false
//        
//        senderLabel.font = .systemFont(ofSize: 14, weight: .semibold)
//        senderLabel.textColor = .systemBlue
//        senderLabel.translatesAutoresizingMaskIntoConstraints = false
//        
//        typeLabel.font = .systemFont(ofSize: 10, weight: .regular)
//        typeLabel.textColor = .secondaryLabel
//        typeLabel.translatesAutoresizingMaskIntoConstraints = false
//        typeLabel.setContentHuggingPriority(.required, for: .vertical)
//        typeLabel.setContentCompressionResistancePriority(.required, for: .vertical)
//        
//        contentView_wrapper.translatesAutoresizingMaskIntoConstraints = false
//        
//        contentView.addSubview(containerView)
//        containerView.addSubview(senderLabel)
//        containerView.addSubview(typeLabel)
//        containerView.addSubview(contentView_wrapper)
//        
//        NSLayoutConstraint.activate([
//            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
//            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
//            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
//            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
//            
//            senderLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
//            senderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
//            senderLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeLabel.leadingAnchor, constant: -8),
//            
//            typeLabel.centerYAnchor.constraint(equalTo: senderLabel.centerYAnchor),
//            typeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
//            
//            contentView_wrapper.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 8),
//            contentView_wrapper.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
//            contentView_wrapper.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
//            contentView_wrapper.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
//        ])
//    }
//    
//    func configure(with message: Message, width: CGFloat, viewController: UIViewController? = nil, onLayoutComplete: (() -> Void)? = nil) {
//        // 生成新的配置 ID，用于跟踪当前配置
//        let configurationId = UUID()
//        self.currentConfigurationId = configurationId
//        self.message = message
//        self.viewController = viewController
//        
//        senderLabel.text = message.sender
//        typeLabel.text = message.type.rawValue.uppercased()
//        
//        // 清除旧的内容视图（包括所有子视图和约束）
//        contentView_wrapper.subviews.forEach { subview in
//            // 移除所有约束
//            subview.removeFromSuperview()
//        }
//        
//        // 移除旧的手势识别器
//        containerView.gestureRecognizers?.forEach { containerView.removeGestureRecognizer($0) }
//        
//        // 添加长按手势
//        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
//        containerView.addGestureRecognizer(longPressGesture)
//        
//        // 如果有 AST JSON，解析并渲染
//        if let astJSON = message.astJSON {
//            DispatchQueue.global(qos: .utility).async { [weak self] in
//                do {
//                    // 解析 JSON 字符串为 RootNode（在后台线程）
//                    guard let jsonData = astJSON.data(using: .utf8) else {
//                        throw NSError(domain: "ParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to Data"])
//                    }
//                    
//                    let decoder = JSONDecoder()
//                    let rootNode = try decoder.decode(RootNode.self, from: jsonData)
//                    
//                    // 回到主线程进行 UI 渲染和添加视图
//                    DispatchQueue.main.async {
//                        guard let self = self,
//                              // 检查配置 ID 是否仍然匹配，避免重用时的异步操作覆盖新配置
//                              self.currentConfigurationId == configurationId else {
//                            return
//                        }
//                        
//                        // 再次清除（防止在异步操作期间被其他配置覆盖）
//                        self.contentView_wrapper.subviews.forEach { $0.removeFromSuperview() }
//                        
//                        // 创建渲染上下文（包含所有点击事件处理和高度变化回调）
//                        guard let context = self.createRenderContext(
//                            width: width,
//                            viewController: viewController,
//                            onHeightChanged: { [weak self] heightDiff in
//                                // 检查配置 ID 是否仍然匹配
//                                guard let self = self,
//                                      self.currentConfigurationId == configurationId else {
//                                    return
//                                }
//                                // 当内容高度变化时，触发 tableView 刷新
//                                DispatchQueue.main.async {
//                                    onLayoutComplete?()
//                                }
//                            }
//                        ) else {
//                            return
//                        }
//                        
//                        // 使用 UIKitAutoLayoutRender 渲染（Auto Layout 模式）- 必须在主线程
//                        let renderer = UIKitAutoLayoutRender()
//                        let astView = renderer.render(ast: rootNode, context: context)
//                        
//                        // 再次检查配置 ID（双重检查，确保安全）
//                        guard self.currentConfigurationId == configurationId else {
//                            return
//                        }
//                        
//                        // 添加到视图
//                        self.contentView_wrapper.addSubview(astView)
//                        
//                        // 设置 Auto Layout 约束
//                        astView.translatesAutoresizingMaskIntoConstraints = false
//                        NSLayoutConstraint.activate([
//                            astView.topAnchor.constraint(equalTo: self.contentView_wrapper.topAnchor),
//                            astView.leadingAnchor.constraint(equalTo: self.contentView_wrapper.leadingAnchor),
//                            astView.trailingAnchor.constraint(equalTo: self.contentView_wrapper.trailingAnchor),
//                            astView.bottomAnchor.constraint(equalTo: self.contentView_wrapper.bottomAnchor)
//                        ])
//                        
//                        // 初始布局完成后，触发一次高度计算
//                        DispatchQueue.main.async {
//                            // 再次检查配置 ID
//                            guard self.currentConfigurationId == configurationId else {
//                                return
//                            }
//                            onLayoutComplete?()
//                        }
//                    }
//                } catch {
//                    // 解析失败，显示原始内容
//                    print("Failed to parse AST JSON: \(error)")
//                    DispatchQueue.main.async {
//                        guard let self = self,
//                              self.currentConfigurationId == configurationId else {
//                            return
//                        }
//                        self.showPlainText(message.content)
//                    }
//                }
//            }
//        } else {
//            // 如果没有 AST，显示原始内容
//            showPlainText(message.content)
//        }
//    }
//    
//    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
//        guard gesture.state == .began,
//              let message = message,
//              let viewController = viewController else {
//            return
//        }
//        
//        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
//        
//        alertController.addAction(UIAlertAction(title: "选择文本", style: .default) { [weak self] _ in
//            self?.showHTMLView(for: message, from: viewController)
//        })
//        
//        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
//        
//        // iPad 支持
//        if let popover = alertController.popoverPresentationController {
//            popover.sourceView = containerView
//            popover.sourceRect = containerView.bounds
//        }
//        
//        viewController.present(alertController, animated: true)
//    }
//    
//    private func showHTMLView(for message: Message, from viewController: UIViewController) {
//        guard let html = message.toHTML() else {
//            let alert = UIAlertController(
//                title: "错误",
//                message: "无法生成 HTML 内容",
//                preferredStyle: .alert
//            )
//            alert.addAction(UIAlertAction(title: "确定", style: .default))
//            viewController.present(alert, animated: true)
//            return
//        }
//        
//        let htmlViewController = MessageHTMLViewController(html: html)
//        let navigationController = UINavigationController(rootViewController: htmlViewController)
//        viewController.present(navigationController, animated: true)
//    }
//    
//    private func showPlainText(_ text: String) {
//        let label = UILabel()
//        label.text = text
//        label.font = .systemFont(ofSize: 16)
//        label.numberOfLines = 0
//        label.textColor = .label
//        label.translatesAutoresizingMaskIntoConstraints = false
//        contentView_wrapper.addSubview(label)
//        
//        NSLayoutConstraint.activate([
//            label.topAnchor.constraint(equalTo: contentView_wrapper.topAnchor),
//            label.leadingAnchor.constraint(equalTo: contentView_wrapper.leadingAnchor),
//            label.trailingAnchor.constraint(equalTo: contentView_wrapper.trailingAnchor),
//            label.bottomAnchor.constraint(equalTo: contentView_wrapper.bottomAnchor)
//        ])
//    }
//    
//    /// 创建渲染上下文，包含所有点击事件处理
//    private func createRenderContext(
//        width: CGFloat,
//        viewController: UIViewController?,
//        onHeightChanged: ((CGFloat) -> Void)? = nil
//    ) -> UIKitRenderContext? {
// 
//        return UIKitRenderContext(
//            theme: UIKitTheme.default,
//            width: width,
//            onLinkTap: { url in
//                // URL 打开浏览器
//                UIApplication.shared.open(url)
//            },
//            onImageTap: { [weak viewController] imageNode in
//                // 图片弹出图片预览页面
//                guard let viewController = viewController else { return }
//                AutoLayoutMessageTableViewCell.showImagePreview(imageNode: imageNode, from: viewController)
//            },
//            onMentionTap: { mentionNode in
//                // Mention 打印 log
//                print("Mention 被点击: @\(mentionNode.name)")
//            },
//            onCodeBlockTap: { codeBlockNode in
//                // 代码块点击：打印 log
//                print("代码块被点击，内容长度: \(codeBlockNode.content.count) 字符")
//            },
//            onMathTap: { mathNode in
//                // 数学公式点击：打印 log
//                print("数学公式被点击: \(mathNode.display ? "块级" : "行内") - \(mathNode.content)")
//            },
//            onMermaidTap: { mermaidNode in
//                // Mermaid 图表点击：打印 log
//                print("Mermaid 图表被点击，内容长度: \(mermaidNode.content.count) 字符")
//            },
//            imageLoaderDelegate: viewController as? UIKitImageLoaderDelegate,
//            formulaSizeCacheDelegate: viewController as? UIKitFormulaSizeCacheDelegate,
//            inlineImageLoaderDelegate: viewController as? UIKitInlineImageLoaderDelegate,
//            onLayoutHeightChanged: onHeightChanged
//        )
//    }
//    
//    /// 显示图片预览
//    private static func showImagePreview(imageNode: ImageNode, from viewController: UIViewController) {
//        guard let url = URL(string: imageNode.url) else {
//            let alert = UIAlertController(
//                title: "错误",
//                message: "无效的图片 URL",
//                preferredStyle: .alert
//            )
//            alert.addAction(UIAlertAction(title: "确定", style: .default))
//            viewController.present(alert, animated: true)
//            return
//        }
//        
//        // 创建图片预览视图控制器
//        let imagePreviewVC = ImagePreviewViewController(imageURL: url, imageNode: imageNode)
//        let navigationController = UINavigationController(rootViewController: imagePreviewVC)
//        viewController.present(navigationController, animated: true)
//    }
//}
//
//// MARK: - UIKitInlineImageLoaderDelegate
//
//extension UIKitAutoLayoutMessageListViewController: UIKitInlineImageLoaderDelegate {
//    func loadEmojiImage(content: String, size: CGFloat, completion: @escaping (UIImage?) -> Void) {
//        // Emoji content 格式应该是类似 "[加油]" 这样的
//        // 对应的文件名是 "[加油].png"
//        let imageName = "\(content).png"
//        
//        // 在后台线程加载图片，避免阻塞主线程
//        DispatchQueue.global(qos: .userInitiated).async {
//            var image: UIImage?
//            
//            // 首先尝试从 main bundle 加载
//            if let loadedImage = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil) {
//                image = loadedImage
//            }
//            // 如果 main bundle 中没有，尝试从 Emojis 文件夹加载
//            else if let emojiPath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Emojis"),
//                    let loadedImage = UIImage(contentsOfFile: emojiPath) {
//                image = loadedImage
//            }
//            // 如果还是找不到，尝试从 Emojis bundle 加载
//            else if let emojiBundlePath = Bundle.main.path(forResource: "Emojis", ofType: nil),
//                    let emojiBundle = Bundle(path: emojiBundlePath),
//                    let loadedImage = UIImage(named: imageName, in: emojiBundle, compatibleWith: nil) {
//                image = loadedImage
//            }
//            
//            // 回到主线程调用 completion
//            DispatchQueue.main.async {
//                completion(image)
//            }
//        }
//    }
//    
//    func loadMentionStatusImage(mentionNode: MentionNode, completion: @escaping (UIImage?) -> Void) {
//        // 根据 mention 节点的 id 或 name 判断已读/未读状态
//        // 这里示例：如果 id 是 "all"，显示已读图片；否则显示未读图片
//        let imageName: String
//        if mentionNode.id == "all" {
//            imageName = "mention_read.png" // 已读图片
//        } else {
//            imageName = "mention_unread.png" // 未读图片
//        }
//        
//        // 在后台线程加载图片
//        DispatchQueue.global(qos: .userInitiated).async {
//            var image: UIImage?
//            
//            // 尝试从 main bundle 加载
//            if let loadedImage = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil) {
//                image = loadedImage
//            }
//            // 如果找不到，返回 nil（不显示状态图片）
//            
//            DispatchQueue.main.async {
//                completion(image)
//            }
//        }
//    }
//}
//
//// MARK: - UIKitImageLoaderDelegate
//
//extension UIKitAutoLayoutMessageListViewController: UIKitImageLoaderDelegate {
//    func loadImage(url: URL, into imageView: UIImageView?, completion: @escaping (UIImage?, Error?) -> Void) {
//        // 使用 Kingfisher 加载图片
//        if let imageView = imageView {
//            imageView.kf.setImage(
//                with: url,
//                placeholder: nil,
//                options: [
//                    .transition(.fade(0.2)),
//                    .cacheOriginalImage
//                ],
//                completionHandler: { result in
//                    switch result {
//                    case .success(let value):
//                        completion(value.image, nil)
//                    case .failure(let error):
//                        completion(nil, error)
//                    }
//                }
//            )
//        }
//    }
//}
//
//// MARK: - UIKitFormulaSizeCacheDelegate
//
//extension UIKitAutoLayoutMessageListViewController: UIKitFormulaSizeCacheDelegate {
//    /// 获取缓存的尺寸
//    /// 从 Kingfisher 的图片缓存中读取图片，然后返回图片尺寸
//    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
//    /// - Returns: 缓存的尺寸，如果不存在则返回nil
//    func getCachedSize(for key: String) -> CGSize? {
//        // 生成 Kingfisher 缓存键
//        let cacheKey = generateCacheKey(for: key)
//        
//        // 从 Kingfisher 内存缓存中同步读取图片
//        if let cachedImage = ImageCache.default.retrieveImageInMemoryCache(forKey: cacheKey) {
//            // 从内存缓存中获取尺寸
//            return cachedImage.size
//        }
//        
//        // 注意：Kingfisher 的磁盘读取是异步的，这里我们只检查内存缓存
//        // 如果内存缓存中没有，返回 nil，布局计算会使用估算高度
//        // 当图片从磁盘加载到内存后，会触发高度刷新
//        return nil
//    }
//    
//    /// 保存尺寸到缓存
//    /// 实际上，这个方法会在图片渲染完成后被调用，此时图片已经保存到 Kingfisher 缓存
//    /// 这里我们只需要记录尺寸信息（可选，因为可以从图片中获取）
//    /// - Parameters:
//    ///   - size: 要缓存的尺寸
//    ///   - key: 缓存键（公式或Mermaid的内容字符串）
//    func setCachedSize(_ size: CGSize, for key: String) {
//        // 图片已经通过 saveFormulaImage 方法保存到 Kingfisher 缓存
//        // 这里不需要额外操作，因为尺寸可以从缓存的图片中获取
//    }
//    
//    /// 保存公式图片到 Kingfisher 缓存
//    /// - Parameters:
//    ///   - image: 要缓存的图片
//    ///   - key: 缓存键（公式或Mermaid的内容字符串）
//    func saveFormulaImage(_ image: UIImage, for key: String) {
//        let cacheKey = generateCacheKey(for: key)
//        // 保存到 Kingfisher 缓存（包括内存和磁盘）
//        ImageCache.default.store(image, forKey: cacheKey, toDisk: true)
//    }
//    
//    /// 获取缓存的公式图片（同步方法，用于协议实现）
//    /// - Parameter key: 缓存键（公式或Mermaid的内容字符串）
//    /// - Returns: 缓存的图片，如果不存在则返回nil
//    func getFormulaImage(for key: String) -> UIImage? {
//        let cacheKey = generateCacheKey(for: key)
//        // 从 Kingfisher 内存缓存中同步读取图片
//        return ImageCache.default.retrieveImageInMemoryCache(forKey: cacheKey)
//    }
//    
//    /// 从 Kingfisher 缓存获取公式图片（异步方法，用于内部调用）
//    /// - Parameters:
//    ///   - key: 缓存键
//    ///   - completion: 完成回调，返回缓存的图片
//    func getCachedFormulaImage(for key: String, completion: @escaping (UIImage?) -> Void) {
//        let cacheKey = generateCacheKey(for: key)
//        // 从 Kingfisher 缓存中读取（包括内存和磁盘）
//        ImageCache.default.retrieveImage(forKey: cacheKey) { result in
//            switch result {
//            case .success(let value):
//                completion(value.image)
//            case .failure:
//                completion(nil)
//            }
//        }
//    }
//    
//    /// 生成缓存键（参考 Kingfisher 的键生成策略）
//    /// - Parameter key: 原始键
//    /// - Returns: 处理后的缓存键
//    private func generateCacheKey(for key: String) -> String {
//        // Kingfisher 使用 MD5 哈希，这里我们使用简单的处理
//        // 如果键太长，使用哈希
//        if key.count > 200 {
//            // 对于过长的键，使用哈希
//            return "formula_hash_\(key.hash)"
//        }
//        // 添加前缀以区分公式图片和其他图片
//        return "formula_\(key)"
//    }
//}
//
