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

// MARK: - 导航规则

/// 定义所有可导航的演示页面
/// 使用枚举来管理所有可导航的页面，便于扩展和维护
enum DemoPage: String, Identifiable, CaseIterable {
    case uikitFrame = "UIKit Frame 消息列表"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .uikitFrame:
            return "rectangle.grid.1x2"
        }
    }
    
    @ViewBuilder
    var destination: some View {
        switch self {
        case .uikitFrame:
            UIKitFrameMessageListWrapper()
        }
    }
}

// MARK: - 主视图

struct MainTabView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Text("IMParse 演示")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                Text("选择要查看的演示页面")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
                
                // 导航按钮 - 使用 NavigationLink 实现导航
                NavigationLink(value: DemoPage.uikitFrame) {
                    HStack {
                        Image(systemName: DemoPage.uikitFrame.icon)
                            .font(.title2)
                            .frame(width: 30)
                        
                        Text("UIKit Frame 消息列表")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding()
            .navigationDestination(for: DemoPage.self) { page in
                page.destination
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
