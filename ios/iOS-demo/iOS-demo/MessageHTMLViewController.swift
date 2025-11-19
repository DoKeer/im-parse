//
//  MessageHTMLViewController.swift
//  IMParseDemo
//
//  WebView 控制器用于显示消息的 HTML 内容，支持文本选择
//

import UIKit
import WebKit

class MessageHTMLViewController: UIViewController {
    
    private let html: String
    private var webView: WKWebView!
    
    init(html: String) {
        self.html = html
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "消息内容"
        view.backgroundColor = .systemBackground
        
        setupWebView()
        setupNavigationBar()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 使用 MathHTMLRenderer 包装 HTML，自动添加 KaTeX CSS 支持
        let wrappedHTML = MathHTMLRenderer.wrapHTMLWithKaTeX(html)
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissViewController)
        )
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
}

extension MessageHTMLViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 允许文本选择
        webView.evaluateJavaScript("document.body.style.webkitUserSelect='text';")
        webView.evaluateJavaScript("document.body.style.webkitTouchCallout='default';")
    }
}

