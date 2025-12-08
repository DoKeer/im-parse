cmake_minimum_required(VERSION 3.18.1)

project("im_parse_jni")

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 保留所有符号（包括 JNI 符号）
# Android NDK 默认使用 --gc-sections 会移除"未使用"的符号
# JNI 符号在链接时被认为是"未使用"的，所以会被移除
# 我们需要移除 --gc-sections 选项
# 注意：这需要在 Gradle 的 CMake 参数中设置，因为 Android 工具链会覆盖 CMAKE_SHARED_LINKER_FLAGS

# 添加 JNI 包装层源文件
add_library(im_parse_jni SHARED
        im_parse_jni.cpp
)

# 查找必需的库
find_library(log-lib log)

# 链接 Android 日志库
target_link_libraries(im_parse_jni PRIVATE
        ${log-lib}
)

# 设置 JNI 库输出名称
set_target_properties(im_parse_jni PROPERTIES
        OUTPUT_NAME "im_parse_core"
)

# 强制保留所有符号（包括 JNI 符号）
# 使用 --whole-archive 确保所有符号都被保留
# 注意：这会使库变大，但确保 JNI 符号不被移除
target_link_options(im_parse_jni PRIVATE
        -Wl,--whole-archive
        -Wl,--no-whole-archive
)

# 根据架构添加 Rust 库路径
set(RUST_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs.backup/${ANDROID_ABI}")

# 如果 Rust 静态库存在，链接它
if(EXISTS "${RUST_LIB_DIR}/libim_parse_core.a")
    add_library(rust_core STATIC IMPORTED)
    set_target_properties(rust_core PROPERTIES
            IMPORTED_LOCATION "${RUST_LIB_DIR}/libim_parse_core.a"
    )
    target_link_libraries(im_parse_jni rust_core)
    message(STATUS "Linking Rust static library: ${RUST_LIB_DIR}/libim_parse_core.a")
# 如果 Rust 动态库存在，链接它
elseif(EXISTS "${RUST_LIB_DIR}/libim_parse_core.so")
    add_library(rust_core SHARED IMPORTED)
    set_target_properties(rust_core PROPERTIES
            IMPORTED_LOCATION "${RUST_LIB_DIR}/libim_parse_core.so"
    )
    # 使用 PRIVATE 链接
    target_link_libraries(im_parse_jni PRIVATE
            rust_core
    )
    message(STATUS "Linking Rust shared library: ${RUST_LIB_DIR}/libim_parse_core.so")
else()
    message(FATAL_ERROR "Rust library not found in ${RUST_LIB_DIR}")
endif()

