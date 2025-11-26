//
//  DemoApp.swift
//  IMParseDemo
//
//  主应用入口
//

import SwiftUI
import IMParseSDK

@main
struct IMParseDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            SwiftUIMessageListView()
                .tabItem {
                    Label("SwiftUI", systemImage: "square.stack.3d.up")
                }
            
            UIKitMessageListWrapper()
                .tabItem {
                    Label("UIKit", systemImage: "list.bullet")
                }
        }
    }
}

// MARK: - UIKit Wrapper

struct UIKitMessageListWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitFrameMessageListViewController {
        return UIKitFrameMessageListViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitFrameMessageListViewController, context: Context) {
        // 不需要更新
    }
}

