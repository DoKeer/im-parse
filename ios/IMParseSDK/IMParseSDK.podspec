Pod::Spec.new do |s|
  s.name             = 'IMParseSDK'
  s.version          = '1.0.0'
  s.summary          = 'iOS SDK for parsing and rendering Markdown and Delta format messages'
  s.description      = <<-DESC
IMParseSDK 是一个用于解析和渲染 Markdown 和 Delta 格式消息的 iOS SDK。
它提供了 UIKit 和 SwiftUI 两种渲染器，支持数学公式、Mermaid 图表等高级功能。
                       DESC

  s.homepage         = 'https://github.com/your-org/im-parse'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/your-org/im-parse.git', :tag => s.version.to_s }

  s.swift_version = '5.0'
  s.ios.deployment_target = '13.0'

  # 默认包含所有内容（完整版）
  s.default_subspecs = 'AutoLayout', 'Frame', 'SwiftUI'
  
  # Rust 核心库路径（所有 subspecs 共享）
  xcframework_path = 'IMParseSDK/Libraries/im_parse_core.xcframework'
  static_lib_path = 'IMParseSDK/Libraries/libim_parse_core.a'

  # ==================== Core Subspec ====================
  # 核心功能：解析和模型（所有版本都需要）
  s.subspec 'Core' do |core|
    core.source_files = 'IMParseSDK/Classes/Core/**/*.{h,m,swift}', 
                        'IMParseSDK/Classes/Models/ASTNodes.swift',
                        'IMParseSDK/Classes/Models/StyleConfig.swift',
                        'IMParseSDK/IMParseSDK.h',
                        'IMParseSDK/Classes/Utils/LocalResourceSchemeHandler.swift',
                        'IMParseSDK/Classes/Utils/RenderQueue.swift'

    core.public_header_files = 'IMParseSDK/IMParseSDK.h', 'IMParseSDK/Classes/Core/**/*.h'
    core.frameworks = 'Foundation'
    
    # 资源文件配置（Mermaid.js、KaTeX CSS 和字体文件）
    # 使用 resources 会将资源复制到 framework bundle 中
    # LocalResourceSchemeHandler 可以通过 Bundle(for: type(of: self)) 找到资源
    core.resources = 'IMParseSDK/Resources/**/*.{js,css,woff2,woff,ttf,otf}'
    
    # Rust 核心库配置
    if File.exist?(xcframework_path)
      core.vendored_frameworks = xcframework_path
      core.preserve_paths = xcframework_path
    else
      if File.exist?(static_lib_path)
        core.vendored_libraries = [static_lib_path]
        core.preserve_paths = static_lib_path
      else
        raise "XCFramework 和静态库都不存在！请先运行: cd ios/IMParseSDK && ./build-rust-lib.sh"
      end
    end
    
    # 头文件搜索路径和链接配置
    pod_target_config = {
      'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/IMParseSDK/IMParseSDK/Classes/Core',
    }
    
    # 如果使用静态库，需要 force_load
    if File.exist?(static_lib_path) && !File.exist?(xcframework_path)
      pod_target_config['OTHER_LDFLAGS'] = '$(inherited) -force_load ${PODS_ROOT}/IMParseSDK/IMParseSDK/Libraries/libim_parse_core.a'
    end
    
    core.pod_target_xcconfig = pod_target_config
    
    # 用户目标配置
    core.user_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/IMParseSDK/IMParseSDK/Classes/Core',
      'LIBRARY_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/IMParseSDK/IMParseSDK/Libraries'
    }
  end

  # ==================== AutoLayout Subspec ====================
  # UIKit Auto Layout 渲染器版本（使用 UIStackView 和 Auto Layout）
  s.subspec 'AutoLayout' do |autolayout|
    autolayout.dependency 'IMParseSDK/Core'
    autolayout.source_files = 'IMParseSDK/Classes/Renderers/UIKitAutoLayoutRender.swift',
                              'IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift',
                              'IMParseSDK/Classes/Renderers/MermaidHTMLRenderer.swift',
                              'IMParseSDK/Classes/Renderers/UIKitAttributedStringBuilder.swift',
                              'IMParseSDK/Classes/Renderers/UIKitRenderContext.swift',
                              'IMParseSDK/Classes/Renderers/UIKitTheme.swift',
                              'IMParseSDK/Classes/Renderers/UIKitGestureHandler.swift',
                              'IMParseSDK/Classes/Renderers/UIKitRenderHelpers.swift',
                              'IMParseSDK/Classes/Renderers/UIKitAutoLayoutAsyncCalculator.swift',
                              'IMParseSDK/Classes/Renderers/UIKitToolbar.swift'
    
    autolayout.frameworks = 'UIKit', 'WebKit'
  end

  # ==================== Frame Subspec ====================
  # UIKit Frame 布局渲染器版本（使用精确的 frame 布局）
  s.subspec 'Frame' do |frame|
    frame.dependency 'IMParseSDK/Core'
    frame.source_files = 'IMParseSDK/Classes/Renderers/UIKitFrameAsyncCalculator.swift',
                         'IMParseSDK/Classes/Renderers/UIKitFrameRender.swift',
                         'IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift',
                         'IMParseSDK/Classes/Renderers/MermaidHTMLRenderer.swift',
                         'IMParseSDK/Classes/Renderers/UIKitAttributedStringBuilder.swift',
                         'IMParseSDK/Classes/Renderers/UIKitRenderContext.swift',
                         'IMParseSDK/Classes/Renderers/UIKitTheme.swift',
                         'IMParseSDK/Classes/Renderers/UIKitGestureHandler.swift',
                         'IMParseSDK/Classes/Renderers/UIKitRenderHelpers.swift',
                         'IMParseSDK/Classes/Renderers/UIKitToolbar.swift'
    
  end

  # ==================== SwiftUI Subspec ====================
  # SwiftUI 渲染器版本（需要 iOS 16.0+）
  s.subspec 'SwiftUI' do |swiftui|
    swiftui.dependency 'IMParseSDK/Core'
    
    swiftui.source_files = 'IMParseSDK/Classes/Renderers/SwiftUIRenderer.swift',
                           'IMParseSDK/Classes/Renderers/SwiftUIRenderContext.swift',
                           'IMParseSDK/Classes/Renderers/MathHTMLRenderer.swift',
                           'IMParseSDK/Classes/Renderers/MermaidHTMLRenderer.swift',
                           'IMParseSDK/Classes/Renderers/UIKitToolbar.swift'
    
    
    swiftui.frameworks = 'SwiftUI', 'UIKit', 'WebKit'
  end

  # ==================== Full Subspec (Deprecated) ====================
  # 完整版本：包含所有功能（AutoLayout + Frame + SwiftUI，需要 iOS 15.0+）
  # 注意：此 subspec 已废弃，建议直接使用 AutoLayout、Frame 和 SwiftUI subspecs
  s.subspec 'Full' do |full|
    full.dependency 'IMParseSDK/Core'
    full.dependency 'IMParseSDK/AutoLayout'
    full.dependency 'IMParseSDK/Frame'
    full.dependency 'IMParseSDK/SwiftUI'
  end
end

