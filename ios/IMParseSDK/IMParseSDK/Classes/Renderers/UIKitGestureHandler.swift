//
//  UIKitGestureHandler.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//

import UIKit

// MARK: - 点击手势处理器

/// 点击手势处理器，用于持有点击处理闭包，避免依赖 UIKitRenderer 实例生命周期
/// 使用 NSObject 是为了能够作为 UIGestureRecognizer 的 target
class TapGestureHandler: NSObject {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    
    @objc func handleTap() {
        action()
    }
}


// MARK: - View Extension 用于方便添加手势

extension UIView {
    /// 添加点击手势和回调
    /// - Parameter action: 点击回调闭包
    func addTapAction(_ action: @escaping () -> Void) {
        self.isUserInteractionEnabled = true
        
        let handler = TapGestureHandler(action: action)
        let tapGesture = UITapGestureRecognizer(target: handler, action: #selector(TapGestureHandler.handleTap))
        self.addGestureRecognizer(tapGesture)
    }
}

