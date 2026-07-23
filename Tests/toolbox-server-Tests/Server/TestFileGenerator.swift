import Foundation
import NIOCore
import NIOPosix
import _NIOFileSystem

import Foundation
import NIOCore
import NIOPosix

enum TestFileGenerator {
    /// 依照指定路径和大小，流式生成一个测试文件（支持自动递归创建文件夹，防内存暴涨）
    /// - Parameters:
    ///   - relativePath: 文件写入路径（支持以项目目录为基准的相对路径，如 "Outputs/test_large.bin"）
    ///   - chunkSize: 每个数据块（Chunk）的大小（单位：字节，例如 1 * 1024 * 1024 代表 1MB）
    ///   - totalSize: 期望最终生成的文件总大小（单位：字节，例如 100 * 1024 * 1024 代表 100MB）
    ///   - eventLoopGroup: 用于调度异步 I/O 的 EventLoopGroup（测试环境可以直接传系统的 `MultiThreadedEventLoopGroup.shared`）
    @discardableResult
    static func generateDummyFile(
        at relativePath: String,
        chunkSize: Int,
        totalSize: Int,
        on eventLoopGroup: EventLoopGroup
    ) async throws -> String {
        // 1. 自动解析和对齐相对路径（转换为绝对路径）
        let fileManager = FileManager.default
        // 通过当前文件路径推导项目根目录，避免 Xcode 或 SPM 运行时的临时目录问题
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TestFileGenerator.swift
            .deletingLastPathComponent() // Server
            .deletingLastPathComponent() // toolbox-server-Tests
            .deletingLastPathComponent() // Tests
            .path
        
        let absolutePath = (relativePath as NSString).isAbsolutePath
            ? relativePath
            : URL(fileURLWithPath: projectRoot).appendingPathComponent(relativePath).path
        
        // 2. 智能前置：如果文件夹不存在，自动递归创建中间文件夹（mkdir -p）
        let directoryURL = URL(fileURLWithPath: absolutePath).deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            print("📁 目标文件夹不存在，正在自动创建: \(directoryURL.path)")
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 如果文件之前就存在，直接复用，不重复创建
        if fileManager.fileExists(atPath: absolutePath) {
            print("📁 目标文件已存在，直接复用: \(absolutePath)")
            return absolutePath
        }
        
        // 3. 使用全新的 NIOFileSystem 替代过时的 NIOFileHandle 和 NonBlockingFileIO
        let fileSystem = FileSystem.shared
        try await fileSystem.withFileHandle(
            forWritingAt: FilePath(absolutePath),
            options: .modifyFile(createIfNecessary: true)
        ) { file in
            var currentOffset: Int64 = 0
            var bytesRemaining = totalSize
            
            print("⏳ 开始流式写入测试文件... 目标路径: \(absolutePath)")
            
            // 5. 核心流式循环：只要总大小没填满，就持续滚动写入
            while bytesRemaining > 0 {
                // 动态计算当前这一块该写多大（最后一块可能不够一个完整的 chunkSize）
                let currentChunkSize = min(chunkSize, bytesRemaining)
                
                // 💡 极其重要：在循环内部实时分配临时的内存 ByteBuffer 块
                var buffer = ByteBufferAllocator().buffer(capacity: currentChunkSize)
                buffer.writeRepeatingByte(1, count: currentChunkSize)
                
                let bytesToWrite = buffer.readableBytes
                
                // 💡 使用 NIOFileSystem 的原生异步 write，自动处理非阻塞写和背压
                _ = try await file.write(
                    contentsOf: buffer,
                    toAbsoluteOffset: currentOffset
                )
                
                // 推进偏移量指针，递减剩余字节数
                currentOffset += Int64(bytesToWrite)
                bytesRemaining -= bytesToWrite
                
                // 可选：在控制台打印进度日志，方便测试时监控
                let progress = Double(currentOffset) / Double(totalSize) * 100.0
                if Int(progress) % 20 == 0 || bytesRemaining == 0 {
                    print("💾 已流式落盘: \(currentOffset) / \(totalSize) 字节 (\(String(format: "%.1f", progress))%)")
                }
            }
        }
        
        print("✅ 测试大文件流式创建圆满成功！文件完整路径: \(absolutePath)")
        
        return absolutePath
    }
}
