//
//  UIKitToolbar.swift
//  IMParseSDK
//
//  工具栏组件 - 用于数学公式、Mermaid、表格的工具栏按钮
//

import UIKit

/// 工具栏按钮类型
enum ToolbarButtonType: Int {
    case copy = 0
    case download = 1
    case fullscreen = 2
}

/// 工具栏配置选项
struct ToolbarConfiguration: OptionSet {
    let rawValue: Int
    
    static let copy = ToolbarConfiguration(rawValue: 1 << 0)
    static let download = ToolbarConfiguration(rawValue: 1 << 1)
    static let fullscreen = ToolbarConfiguration(rawValue: 1 << 2)
    
    /// 默认配置：显示所有按钮
    static let `default`: ToolbarConfiguration = [.copy, .download, .fullscreen]
    
    /// 代码块配置：只显示复制和全屏按钮
    static let codeBlock: ToolbarConfiguration = [.copy, .fullscreen]
}

/// 工具栏组件
class UIKitToolbar: UIView {
    private let theme: UIKitTheme
    private let configuration: ToolbarConfiguration
    private var copyButton: UIButton?
    private var downloadButton: UIButton?
    private var fullscreenButton: UIButton?
    
    var onCopy: (() -> Void)?
    var onDownload: (() -> Void)?
    var onFullscreen: (() -> Void)?
    
    init(theme: UIKitTheme, configuration: ToolbarConfiguration = .default, frame: CGRect = .zero) {
        self.theme = theme
        self.configuration = configuration
        super.init(frame: frame)
        setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init(theme:configuration:) instead.")
    }
    
    private func setupToolbar() {
        let buttonSize = theme.toolbarButtonSize
        backgroundColor = UIColor.clear
        
        var buttons: [UIButton] = []
        
        // 根据配置创建按钮
        if configuration.contains(.copy) {
            copyButton = createButton(icon: "doc.on.doc", type: .copy, size: buttonSize)
            buttons.append(copyButton!)
        }
        
        if configuration.contains(.download) {
            downloadButton = createButton(icon: "arrow.down.circle", type: .download, size: buttonSize)
            buttons.append(downloadButton!)
        }
        
        if configuration.contains(.fullscreen) {
            fullscreenButton = createButton(icon: "arrow.up.left.and.arrow.down.right", type: .fullscreen, size: buttonSize)
            buttons.append(fullscreenButton!)
        }
        
        // 如果没有按钮，直接返回
        guard !buttons.isEmpty else {
            return
        }
        
        // 使用 frame 布局按钮，从右往左排列
        for button in buttons {
            addSubview(button)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let buttonSize = theme.toolbarButtonSize
        let buttonSpacing = theme.toolbarButtonSpacing
        let containerPadding = theme.toolbarPadding
        
        // 收集所有按钮
        var buttons: [UIButton] = []
        if let copyButton = copyButton { buttons.append(copyButton) }
        if let downloadButton = downloadButton { buttons.append(downloadButton) }
        if let fullscreenButton = fullscreenButton { buttons.append(fullscreenButton) }
        
        // 从右往左布局按钮
        var currentX = bounds.width - containerPadding
        let centerY = bounds.height / 2
        
        for button in buttons.reversed() {
            currentX -= buttonSize
            button.frame = CGRect(
                x: currentX,
                y: centerY - buttonSize / 2,
                width: buttonSize,
                height: buttonSize
            )
            currentX -= buttonSpacing
        }
    }
    
    private func createButton(icon: String, type: ToolbarButtonType, size: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        
        // 使用 SF Symbols
        if let image = UIImage(systemName: icon) {
            // 配置图片渲染模式，确保图标不被压扁
            let config = UIImage.SymbolConfiguration(pointSize: size * 0.6, weight: .regular, scale: .medium)
            let configuredImage = image.withConfiguration(config)
            button.setImage(configuredImage, for: .normal)
        }
        
        button.tintColor = UIColor.label
        button.backgroundColor = UIColor.clear
        
        // 设置图片内容模式，确保图标保持宽高比
        button.imageView?.contentMode = .scaleAspectFit
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        
        // 移除默认的内边距，让图标居中显示
        button.imageEdgeInsets = .zero
        button.contentEdgeInsets = .zero
        
        // 添加点击事件
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.tag = type.rawValue
        
        return button
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        if let type = ToolbarButtonType(rawValue: sender.tag) {
            switch type {
            case .copy:
                onCopy?()
            case .download:
                onDownload?()
            case .fullscreen:
                onFullscreen?()
            }
        }
    }
}

/// Mermaid 预览/代码切换器
class MermaidViewModeSwitcher: UIView {
    private let previewButton: UIButton!
    private let codeButton: UIButton!
    private let indicatorView: UIView!
    private let theme: UIKitTheme
    private let previewText: String
    private let codeText: String
    
    var onModeChanged: ((Bool) -> Void)? // true = 预览模式, false = 代码模式
    
    private var isPreviewMode: Bool = true {
        didSet {
            updateMode()
            onModeChanged?(isPreviewMode)
        }
    }
    
    init(theme: UIKitTheme, previewText: String, codeText: String, frame: CGRect = .zero) {
        self.theme = theme
        self.previewText = previewText
        self.codeText = codeText
        previewButton = UIButton(type: .system)
        codeButton = UIButton(type: .system)
        indicatorView = UIView()
        
        super.init(frame: frame)
        setupSwitcher()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init(theme:previewText:codeText:) instead.")
    }
    
    private func setupSwitcher() {
        // 根据高度计算字体大小，取整
        let fontSize = Int(theme.toolbarButtonSize * 0.5)
        // 预览按钮
        previewButton.setTitle(previewText, for: .normal)
        previewButton.titleLabel?.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
        previewButton.addTarget(self, action: #selector(previewTapped), for: .touchUpInside)
        previewButton.backgroundColor = .clear

        // 代码按钮
        codeButton.setTitle(codeText, for: .normal)
        codeButton.titleLabel?.font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .medium)
        codeButton.addTarget(self, action: #selector(codeTapped), for: .touchUpInside)
        codeButton.backgroundColor = .clear

        // 指示器
        indicatorView.backgroundColor = UIColor.systemBlue
        
        addSubview(previewButton)
        addSubview(codeButton)
        addSubview(indicatorView)
        
        updateMode()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let buttonSpacing = theme.toolbarSwitcherButtonSpacing
        let buttonWidth = theme.toolbarSwitcherButtonWidth
        let switcherPadding = theme.toolbarPadding
        
        // 布局预览按钮
        previewButton.frame = CGRect(
            x: switcherPadding,
            y: switcherPadding,
            width: buttonWidth,
            height: bounds.height - switcherPadding * 2
        )
        
        // 布局代码按钮
        codeButton.frame = CGRect(
            x: previewButton.frame.maxX + buttonSpacing,
            y: switcherPadding,
            width: buttonWidth,
            height: bounds.height - switcherPadding * 2
        )
        
        // 布局指示器
        let indicatorHeight: CGFloat = 2
        if isPreviewMode {
            indicatorView.frame = CGRect(
                x: previewButton.frame.minX,
                y: bounds.height - indicatorHeight - 2,
                width: previewButton.frame.width,
                height: indicatorHeight
            )
        } else {
            indicatorView.frame = CGRect(
                x: codeButton.frame.minX,
                y: bounds.height - indicatorHeight - 2,
                width: codeButton.frame.width,
                height: indicatorHeight
            )
        }
        
        indicatorView.layer.cornerRadius = indicatorHeight/2
    }
    
    @objc private func previewTapped() {
        isPreviewMode = true
    }
    
    @objc private func codeTapped() {
        isPreviewMode = false
    }
    
    private func updateMode() {
        if isPreviewMode {
            // 选中状态：使用深色文字，确保在浅灰色背景上有足够的对比度
            previewButton.setTitleColor(.label, for: .normal)
            codeButton.setTitleColor(.secondaryLabel, for: .normal)
        } else {
            // 未选中状态
            previewButton.setTitleColor(.secondaryLabel, for: .normal)
            // 选中状态：使用深色文字
            codeButton.setTitleColor(.label, for: .normal)
        }
        
        // 使用动画移动指示器
        UIView.animate(withDuration: 0.2) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}

