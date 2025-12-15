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

/// 工具栏组件
class UIKitToolbar: UIView {
    private let buttonSize: CGFloat = 32
    private let buttonSpacing: CGFloat = 8
    private let containerPadding: CGFloat = 8
    
    private var copyButton: UIButton!
    private var downloadButton: UIButton!
    private var fullscreenButton: UIButton!
    
    var onCopy: (() -> Void)?
    var onDownload: (() -> Void)?
    var onFullscreen: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }
    
    private func setupToolbar() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        // 创建按钮
        copyButton = createButton(icon: "doc.on.doc", type: .copy)
        downloadButton = createButton(icon: "arrow.down.circle", type: .download)
        fullscreenButton = createButton(icon: "arrow.up.left.and.arrow.down.right", type: .fullscreen)
        
        // 布局按钮
        let stackView = UIStackView(arrangedSubviews: [copyButton, downloadButton, fullscreenButton])
        stackView.axis = .horizontal
        stackView.spacing = buttonSpacing
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: containerPadding),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: containerPadding),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -containerPadding),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -containerPadding),
            heightAnchor.constraint(equalToConstant: buttonSize + containerPadding * 2)
        ])
    }
    
    private func createButton(icon: String, type: ToolbarButtonType) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 使用 SF Symbols
        if let image = UIImage(systemName: icon) {
            button.setImage(image, for: .normal)
        }
        
        button.tintColor = UIColor.label
        button.backgroundColor = UIColor.clear
        
        // 按钮尺寸
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: buttonSize),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
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
    
    // 保存指示器的约束引用
    private var indicatorLeadingConstraint: NSLayoutConstraint?
    private var indicatorTrailingConstraint: NSLayoutConstraint?
    private var indicatorBottomConstraint: NSLayoutConstraint?
    private var indicatorHeightConstraint: NSLayoutConstraint?
    
    var onModeChanged: ((Bool) -> Void)? // true = 预览模式, false = 代码模式
    
    private var isPreviewMode: Bool = true {
        didSet {
            updateMode()
            onModeChanged?(isPreviewMode)
        }
    }
    
    override init(frame: CGRect) {
        previewButton = UIButton(type: .system)
        codeButton = UIButton(type: .system)
        indicatorView = UIView()
        
        super.init(frame: frame)
        setupSwitcher()
    }
    
    required init?(coder: NSCoder) {
        previewButton = UIButton(type: .system)
        codeButton = UIButton(type: .system)
        indicatorView = UIView()
        
        super.init(coder: coder)
        setupSwitcher()
    }
    
    private func setupSwitcher() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 6
        
        // 预览按钮
        previewButton.setTitle("预览", for: .normal)
        previewButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        previewButton.translatesAutoresizingMaskIntoConstraints = false
        previewButton.addTarget(self, action: #selector(previewTapped), for: .touchUpInside)
        
        // 代码按钮
        codeButton.setTitle("代码", for: .normal)
        codeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        codeButton.translatesAutoresizingMaskIntoConstraints = false
        codeButton.addTarget(self, action: #selector(codeTapped), for: .touchUpInside)
        
        // 指示器
        indicatorView.backgroundColor = UIColor.systemBlue
        indicatorView.layer.cornerRadius = 3
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(previewButton)
        addSubview(codeButton)
        addSubview(indicatorView)
        
        // 设置按钮约束
        NSLayoutConstraint.activate([
            previewButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            previewButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            previewButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            previewButton.widthAnchor.constraint(equalToConstant: 60),
            
            codeButton.leadingAnchor.constraint(equalTo: previewButton.trailingAnchor, constant: 4),
            codeButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            codeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            codeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            codeButton.widthAnchor.constraint(equalToConstant: 60),
            
            heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // 设置指示器的初始约束（默认在预览按钮下方）
        indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: previewButton.leadingAnchor)
        indicatorTrailingConstraint = indicatorView.trailingAnchor.constraint(equalTo: previewButton.trailingAnchor)
        indicatorBottomConstraint = indicatorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        indicatorHeightConstraint = indicatorView.heightAnchor.constraint(equalToConstant: 2)
        
        NSLayoutConstraint.activate([
            indicatorLeadingConstraint!,
            indicatorTrailingConstraint!,
            indicatorBottomConstraint!,
            indicatorHeightConstraint!
        ])
        
        updateMode()
    }
    
    @objc private func previewTapped() {
        isPreviewMode = true
    }
    
    @objc private func codeTapped() {
        isPreviewMode = false
    }
    
    private func updateMode() {
        // 先停用旧的约束
        indicatorLeadingConstraint?.isActive = false
        indicatorTrailingConstraint?.isActive = false
        
        if isPreviewMode {
            previewButton.setTitleColor(.white, for: .normal)
            codeButton.setTitleColor(.label, for: .normal)
            
            // 移动指示器到预览按钮下方
            indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: previewButton.leadingAnchor)
            indicatorTrailingConstraint = indicatorView.trailingAnchor.constraint(equalTo: previewButton.trailingAnchor)
        } else {
            previewButton.setTitleColor(.label, for: .normal)
            codeButton.setTitleColor(.white, for: .normal)
            
            // 移动指示器到代码按钮下方
            indicatorLeadingConstraint = indicatorView.leadingAnchor.constraint(equalTo: codeButton.leadingAnchor)
            indicatorTrailingConstraint = indicatorView.trailingAnchor.constraint(equalTo: codeButton.trailingAnchor)
        }
        
        // 激活新的约束
        indicatorLeadingConstraint?.isActive = true
        indicatorTrailingConstraint?.isActive = true
        
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
}

