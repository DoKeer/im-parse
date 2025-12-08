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
            
            UIKitFrameMessageListWrapper()
                .tabItem {
                    Label("UIKit Frame", systemImage: "rectangle.grid.1x2")
                }
            
            UIKitAutoLayoutMessageListWrapper()
                .tabItem {
                    Label("UIKit Auto Layout", systemImage: "list.bullet")
                }
        }
    }
}

// MARK: - UIKit Frame Wrapper

struct UIKitFrameMessageListWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitFrameMessageListViewController {
        return UIKitFrameMessageListViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitFrameMessageListViewController, context: Context) {
        // 不需要更新
    }
}

// MARK: - UIKit Auto Layout Wrapper

struct UIKitAutoLayoutMessageListWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitAutoLayoutMessageListViewController {
        return UIKitAutoLayoutMessageListViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIKitAutoLayoutMessageListViewController, context: Context) {
        // 不需要更新
    }
}

