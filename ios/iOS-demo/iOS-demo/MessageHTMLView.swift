//
//  MessageHTMLView.swift
//  IMParseDemo
//
//  WebView 用于显示消息的 HTML 内容，支持文本选择
//

import SwiftUI
import WebKit

struct MessageHTMLView: View {
    let html: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            WebView(html: html)
                .navigationTitle("消息内容")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct WebView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 允许文本选择
            webView.evaluateJavaScript("document.body.style.webkitUserSelect='text';")
            webView.evaluateJavaScript("document.body.style.webkitTouchCallout='default';")
        }
    }
}

