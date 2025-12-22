//
//  RenderQueue.swift
//  IMParseSDK
//
//  串行渲染队列管理器
//  用于确保渲染任务按顺序执行，不并发渲染
//

import Foundation
import WebKit

/// 串行渲染队列管理器
/// 确保渲染任务按顺序执行，渲染成功一个就返回一个
@MainActor
class RenderQueue {
    static let shared = RenderQueue()
    
    // 渲染任务队列
    private var taskQueue: [() async -> Void] = []
    private var isProcessing = false
    private let queueLock = NSLock()
    
    private init() {}
    
    /// 将渲染任务加入队列
    /// - Parameter task: 渲染任务闭包
    func enqueue(_ task: @escaping () async -> Void) {
        queueLock.lock()
        taskQueue.append(task)
        queueLock.unlock()
        
        // 如果当前没有在处理任务，开始处理
        if !isProcessing {
            Task { @MainActor in
                await processQueue()
            }
        }
    }
    
    /// 处理队列中的任务（串行执行）
    private func processQueue() async {
        queueLock.lock()
        guard !isProcessing else {
            queueLock.unlock()
            return
        }
        isProcessing = true
        queueLock.unlock()
        
        while true {
            let task: (() async -> Void)?
            
            queueLock.lock()
            if taskQueue.isEmpty {
                isProcessing = false
                queueLock.unlock()
                break
            }
            task = taskQueue.removeFirst()
            queueLock.unlock()
            
            // 执行任务
            await task?()
        }
    }
    
    /// 清空队列
    func clear() {
        queueLock.lock()
        taskQueue.removeAll()
        queueLock.unlock()
    }
}

extension WKWebView {
    func takeSnapshot(with config: WKSnapshotConfiguration? = nil) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.takeSnapshot(with: config) { image, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "WKWebView",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                    ))
                }
            }
        }
    }
}
