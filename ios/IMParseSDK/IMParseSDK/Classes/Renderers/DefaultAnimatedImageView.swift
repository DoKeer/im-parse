//
//  DefaultAnimatedImageView.swift
//  IMParseSDK
//
//  Created by IMParse on 2025.
//
//  基于 ImageIO 的轻量级动图视图实现
//  采用流式解码和有限帧缓存策略，显著降低内存占用
//

import UIKit
import ImageIO

// MARK: - 动图帧信息

/// 动图帧信息
internal struct AnimatedImageFrame {
    let image: CGImage
    let duration: TimeInterval
}

// MARK: - DefaultAnimatedImageView

/// 默认动图视图实现
/// 基于 ImageIO 框架，采用流式解码策略：
/// - 只缓存当前帧和预解码的少量帧（默认3帧）
/// - 支持自动降采样大尺寸图片
/// - 支持 GIF 和 APNG 格式
internal class DefaultAnimatedImageView: UIView {
    
    // MARK: - Properties
    
    /// 图片数据源
    private var imageSource: CGImageSource?
    
    /// 总帧数
    private var frameCount: Int = 0
    
    /// 当前帧索引
    private var currentFrameIndex: Int = 0
    
    /// 帧持续时间数组
    private var frameDurations: [TimeInterval] = []
    
    /// 帧缓存（只保留少量帧）
    private var frameCache: [Int: CGImage] = [:]
    
    /// 最大缓存帧数
    private let maxCacheFrames: Int = 3
    
    /// 显示链接
    private var displayLink: CADisplayLink?
    
    /// 累计时间
    private var accumulatedTime: TimeInterval = 0
    
    /// 当前帧持续时间
    private var currentFrameDuration: TimeInterval = 0
    
    /// 是否正在播放
    private(set) var isAnimating: Bool = false
    
    /// 显示图层
    private let imageLayer = CALayer()
    
    /// 图片数据（用于重新加载）
    private var imageData: Data?
    
    /// 降采样目标尺寸（0 表示不降采样）
    var downsampleSize: CGSize = .zero
    
    /// 循环次数（0 表示无限循环）
    var loopCount: Int = 0
    
    /// 当前循环次数
    private var currentLoopCount: Int = 0
    
    /// 静态图片（首帧或非动图）
    private var staticImage: UIImage?
    
    /// 内容模式
    override var contentMode: UIView.ContentMode {
        didSet {
            updateImageLayerContentsGravity()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageLayer()
    }
    
    deinit {
        stopAnimating()
    }
    
    // MARK: - Setup
    
    private func setupImageLayer() {
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.frame = bounds
        layer.addSublayer(imageLayer)
    }
    
    private func updateImageLayerContentsGravity() {
        switch contentMode {
        case .scaleToFill:
            imageLayer.contentsGravity = .resize
        case .scaleAspectFit:
            imageLayer.contentsGravity = .resizeAspect
        case .scaleAspectFill:
            imageLayer.contentsGravity = .resizeAspectFill
        case .center:
            imageLayer.contentsGravity = .center
        case .top:
            imageLayer.contentsGravity = .top
        case .bottom:
            imageLayer.contentsGravity = .bottom
        case .left:
            imageLayer.contentsGravity = .left
        case .right:
            imageLayer.contentsGravity = .right
        case .topLeft:
            imageLayer.contentsGravity = .topLeft
        case .topRight:
            imageLayer.contentsGravity = .topRight
        case .bottomLeft:
            imageLayer.contentsGravity = .bottomLeft
        case .bottomRight:
            imageLayer.contentsGravity = .bottomRight
        default:
            imageLayer.contentsGravity = .resizeAspect
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageLayer.frame = bounds
    }
    
    // MARK: - Public Methods
    
    /// 加载动图数据
    /// - Parameter data: 图片数据
    /// - Returns: 是否成功加载
    @discardableResult
    func loadAnimatedImage(from data: Data) -> Bool {
        // 清理之前的状态
        reset()
        
        self.imageData = data
        
        // 创建图片源
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        
        self.imageSource = source
        self.frameCount = CGImageSourceGetCount(source)
        
        // 如果只有一帧，作为静态图片处理
        if frameCount <= 1 {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                staticImage = UIImage(cgImage: cgImage)
                imageLayer.contents = cgImage
            }
            return true
        }
        
        // 解析帧持续时间
        parseFrameDurations(from: source)
        
        // 加载第一帧
        if let firstFrame = decodeFrame(at: 0) {
            imageLayer.contents = firstFrame
            frameCache[0] = firstFrame
            staticImage = UIImage(cgImage: firstFrame)
        }
        
        // 预解码下几帧
        prefetchFrames()
        
        return true
    }
    
    /// 获取静态图片（首帧）
    func getStaticImage() -> UIImage? {
        return staticImage
    }
    
    /// 开始播放动画
    func startAnimating() {
        guard !isAnimating, frameCount > 1 else { return }
        
        isAnimating = true
        currentLoopCount = 0
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// 停止播放动画
    func stopAnimating() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// 重置到初始状态
    func reset() {
        stopAnimating()
        imageSource = nil
        frameCount = 0
        currentFrameIndex = 0
        frameDurations.removeAll()
        frameCache.removeAll()
        accumulatedTime = 0
        currentFrameDuration = 0
        currentLoopCount = 0
        imageLayer.contents = nil
        staticImage = nil
        imageData = nil
    }
    
    // MARK: - Private Methods
    
    /// 解析帧持续时间
    private func parseFrameDurations(from source: CGImageSource) {
        frameDurations.removeAll()
        
        for i in 0..<frameCount {
            var duration: TimeInterval = 0.1 // 默认 100ms
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any] {
                // 尝试 GIF 属性
                if let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    if let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    }
                }
                // 尝试 APNG 属性
                else if let pngProperties = properties[kCGImagePropertyPNGDictionary as String] as? [String: Any] {
                    if let delayTime = pngProperties[kCGImagePropertyAPNGUnclampedDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    } else if let delayTime = pngProperties[kCGImagePropertyAPNGDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    }
                }
                // 尝试 WebP 属性
                else if let webpProperties = properties[kCGImagePropertyWebPDictionary as String] as? [String: Any] {
                    if let delayTime = webpProperties[kCGImagePropertyWebPUnclampedDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    } else if let delayTime = webpProperties[kCGImagePropertyWebPDelayTime as String] as? Double, delayTime > 0 {
                        duration = delayTime
                    }
                }
            }
            
            // 最小帧持续时间为 10ms
            duration = max(duration, 0.01)
            frameDurations.append(duration)
        }
        
        if !frameDurations.isEmpty {
            currentFrameDuration = frameDurations[0]
        }
    }
    
    /// 解码指定帧
    private func decodeFrame(at index: Int) -> CGImage? {
        guard let source = imageSource, index < frameCount else { return nil }
        
        var options: [String: Any] = [
            kCGImageSourceShouldCache as String: false, // 不让 ImageIO 缓存，我们自己管理
            kCGImageSourceShouldAllowFloat as String: true
        ]
        
        // 如果需要降采样
        if downsampleSize != .zero {
            let maxDimension = max(downsampleSize.width, downsampleSize.height) * UIScreen.main.scale
            options[kCGImageSourceThumbnailMaxPixelSize as String] = maxDimension
            options[kCGImageSourceCreateThumbnailFromImageAlways as String] = true
            options[kCGImageSourceCreateThumbnailWithTransform as String] = true
        }
        
        return CGImageSourceCreateImageAtIndex(source, index, options as CFDictionary)
    }
    
    /// 预解码后续帧
    private func prefetchFrames() {
        // 在后台线程预解码
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for i in 1..<min(self.maxCacheFrames, self.frameCount) {
                if self.frameCache[i] == nil {
                    if let frame = self.decodeFrame(at: i) {
                        DispatchQueue.main.async {
                            self.frameCache[i] = frame
                        }
                    }
                }
            }
        }
    }
    
    /// DisplayLink 回调
    @objc private func displayLinkFired(_ displayLink: CADisplayLink) {
        guard isAnimating, frameCount > 1 else { return }
        
        accumulatedTime += displayLink.duration
        
        // 检查是否需要切换到下一帧
        while accumulatedTime >= currentFrameDuration {
            accumulatedTime -= currentFrameDuration
            
            // 切换到下一帧
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
            
            // 检查是否完成一次循环
            if currentFrameIndex == 0 {
                currentLoopCount += 1
                if loopCount > 0 && currentLoopCount >= loopCount {
                    stopAnimating()
                    return
                }
            }
            
            // 更新当前帧持续时间
            currentFrameDuration = frameDurations[currentFrameIndex]
            
            // 显示当前帧
            displayCurrentFrame()
            
            // 清理旧帧缓存，预解码新帧
            updateFrameCache()
        }
    }
    
    /// 显示当前帧
    private func displayCurrentFrame() {
        // 优先从缓存获取
        if let cachedFrame = frameCache[currentFrameIndex] {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.contents = cachedFrame
            CATransaction.commit()
        } else {
            // 同步解码当前帧
            if let frame = decodeFrame(at: currentFrameIndex) {
                frameCache[currentFrameIndex] = frame
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                imageLayer.contents = frame
                CATransaction.commit()
            }
        }
    }
    
    /// 更新帧缓存
    private func updateFrameCache() {
        // 计算需要保留的帧范围
        var framesToKeep = Set<Int>()
        for i in 0..<maxCacheFrames {
            let frameIndex = (currentFrameIndex + i) % frameCount
            framesToKeep.insert(frameIndex)
        }
        
        // 移除不需要的帧
        for key in frameCache.keys {
            if !framesToKeep.contains(key) {
                frameCache.removeValue(forKey: key)
            }
        }
        
        // 预解码下几帧
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for i in 1..<self.maxCacheFrames {
                let frameIndex = (self.currentFrameIndex + i) % self.frameCount
                if self.frameCache[frameIndex] == nil {
                    if let frame = self.decodeFrame(at: frameIndex) {
                        DispatchQueue.main.async {
                            // 再次检查是否还需要这一帧
                            if self.isAnimating {
                                self.frameCache[frameIndex] = frame
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DefaultAnimatedImageProvider

/// 默认动图视图提供者
/// 使用 SDK 内置的 DefaultAnimatedImageView 实现
public class DefaultAnimatedImageProvider: UIKitAnimatedImageViewProvider {
    
    /// 降采样目标尺寸（用于大图优化）
    public var downsampleSize: CGSize = .zero
    
    public init() {}
    
    public func createAnimatedImageView() -> UIView {
        let imageView = DefaultAnimatedImageView()
        imageView.downsampleSize = downsampleSize
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    public func loadAnimatedImage(data: Data, into imageView: UIView, completion: @escaping (Bool) -> Void) {
        guard let animatedView = imageView as? DefaultAnimatedImageView else {
            completion(false)
            return
        }
        
        let success = animatedView.loadAnimatedImage(from: data)
        if success {
            animatedView.startAnimating()
        }
        completion(success)
    }
    
    public func loadAnimatedImage(url: URL, into imageView: UIView, completion: @escaping (Bool, UIImage?) -> Void) {
        guard let animatedView = imageView as? DefaultAnimatedImageView else {
            completion(false, nil)
            return
        }
        
        // 使用 URLSession 加载数据
        URLSession.shared.dataTask(with: url) { [weak animatedView] data, _, error in
            DispatchQueue.main.async {
                guard let animatedView = animatedView, let data = data, error == nil else {
                    completion(false, nil)
                    return
                }
                
                let success = animatedView.loadAnimatedImage(from: data)
                if success {
                    animatedView.startAnimating()
                }
                completion(success, animatedView.getStaticImage())
            }
        }.resume()
    }
    
    public func isAnimatedImage(data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 1
    }
    
    public func stopAnimation(in imageView: UIView) {
        guard let animatedView = imageView as? DefaultAnimatedImageView else { return }
        animatedView.stopAnimating()
    }
    
    public func startAnimation(in imageView: UIView) {
        guard let animatedView = imageView as? DefaultAnimatedImageView else { return }
        animatedView.startAnimating()
    }
}

// MARK: - AnimatedImageUtils

/// 动图工具类
public enum AnimatedImageUtils {
    
    /// 检测数据是否为动图
    /// - Parameter data: 图片数据
    /// - Returns: 如果是动图返回 true
    public static func isAnimatedImage(data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 1
    }
    
    /// 提取动图首帧
    /// - Parameter data: 图片数据
    /// - Returns: 首帧图片，如果失败返回 nil
    public static func extractFirstFrame(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 提取动图首帧（带降采样）
    /// - Parameters:
    ///   - data: 图片数据
    ///   - maxSize: 最大尺寸
    /// - Returns: 首帧图片，如果失败返回 nil
    public static func extractFirstFrame(from data: Data, maxSize: CGSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let maxDimension = max(maxSize.width, maxSize.height) * UIScreen.main.scale
        let options: [String: Any] = [
            kCGImageSourceThumbnailMaxPixelSize as String: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways as String: true,
            kCGImageSourceCreateThumbnailWithTransform as String: true,
            kCGImageSourceShouldCacheImmediately as String: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 获取动图信息
    /// - Parameter data: 图片数据
    /// - Returns: 帧数和总时长的元组，如果失败返回 nil
    public static func getAnimatedImageInfo(from data: Data) -> (frameCount: Int, duration: TimeInterval)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }
        
        var totalDuration: TimeInterval = 0
        
        for i in 0..<frameCount {
            var frameDuration: TimeInterval = 0.1
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any] {
                if let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    if let delay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                        frameDuration = delay
                    } else if let delay = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
                        frameDuration = delay
                    }
                }
            }
            
            totalDuration += max(frameDuration, 0.01)
        }
        
        return (frameCount, totalDuration)
    }
}
