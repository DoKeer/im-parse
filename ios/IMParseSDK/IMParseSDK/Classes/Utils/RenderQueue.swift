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
        let queueCount = taskQueue.count
        let wasProcessing = isProcessing
        queueLock.unlock()
        
        print("📥 [RenderQueue] 任务入队，当前队列长度: \(queueCount), 是否正在处理: \(wasProcessing)")
        
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
            print("⚠️ [RenderQueue] 队列已在处理中，跳过")
            return
        }
        isProcessing = true
        let initialCount = taskQueue.count
        queueLock.unlock()
        
        print("🚀 [RenderQueue] 开始处理队列，初始任务数: \(initialCount)")
        var processedCount = 0
        
        while true {
            let task: (() async -> Void)?
            let remainingCount: Int
            
            queueLock.lock()
            if taskQueue.isEmpty {
                isProcessing = false
                queueLock.unlock()
                print("✅ [RenderQueue] 队列处理完成，共处理 \(processedCount) 个任务")
                break
            }
            task = taskQueue.removeFirst()
            remainingCount = taskQueue.count
            queueLock.unlock()
            
            processedCount += 1
            print("▶️ [RenderQueue] 执行任务 \(processedCount)/\(initialCount)，剩余: \(remainingCount)")
            
            // 执行任务
            await task?()
            
            print("✅ [RenderQueue] 任务 \(processedCount) 完成，剩余: \(remainingCount)")
        }
    }
    
    /// 清空队列
    func clear() {
        queueLock.lock()
        let count = taskQueue.count
        taskQueue.removeAll()
        queueLock.unlock()
        print("🗑️ [RenderQueue] 队列已清空，移除了 \(count) 个任务")
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
