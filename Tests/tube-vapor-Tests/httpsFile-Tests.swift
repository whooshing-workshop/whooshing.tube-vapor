import Testing
import Foundation
import SystemPackage
import NIOFileSystem
import AsyncHTTPClient
import AsyncAlgorithms
@testable import VaporTube

@Suite("Https 文件传输测试集", .serialized)
struct HttpsFileTests {
    
    func withClient(_ action: (HTTPClient) async throws -> Void) async rethrows {
        let client = makeHttpsClient()
        do {
            try await action(client)
            try await client.shutdown()
        } catch {
            try! await client.shutdown()
        }
    }
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .httpsFile {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("创建测试文件")
    func testFileCreating() async throws {
        try await withClient { client in
            let req = try HTTPClient.Request(
                url: "http://localhost:\(TestingShared.httpsListenPort)/file-prepare",
                method: .POST,
                headers: ["Content-Type": "application/json"],
                body: .data(JSONEncoder().encode(TestingShared.testingPaths))
            )
            
            let res = try await client.execute(request: req).get()
            let body = try #require(res.body)
            let paths = try JSONDecoder().decode(FilePrepareRes.self, from: body)
            TestingShared.normalFilePath = paths.smallPath
            TestingShared.largeFilePath = paths.largetPath
        }
    }
    
    @Test("Send 文件流传输", .serialized, arguments: [HTTPMethod.POST, .PATCH, .PUT])
    func fileSendTest(method: HTTPMethod) async throws {
        try await withClient { client in
            var size = 0
            let url = FilePath(TestingShared.normalFilePath)
            let info = try #require(await FileSystem.shared.info(forFileAt: url))
            
            let stream = AsyncThrowingChannel<ByteBuffer, Error>()
            
            Task {
                var fileHandle: ReadFileHandle? = nil
                do {
                    let fh = try await FileSystem.shared.openFile(forReadingAt: url, options: .init())
                    fileHandle = fh
                    
                    var current: Int64 = 0
                    
                    for try await chunk in fh.readChunks(chunkLength: .kilobytes(64)) {
                        await stream.send(chunk)
                        current += .init(chunk.readableBytes)
                        print("W-\((Double(current)/Double(info.size)*100).formatted(.number.precision(.fractionLength(0...1))))%", terminator: " ")
                    }
                    try await fh.close()
                    stream.finish()
                } catch {
                    try await fileHandle?.close()
                    stream.fail(error)
                }
            }
            
            var request = HTTPClientRequest(url: "http://localhost:\(TestingShared.httpsListenPort)/file-echo")
            request.method = method
            request.headers.add(name: "content-disposition", value: url.lastComponent?.string  ?? "")
            request.headers.add(name: "Content-Type", value: "application/octet-stream")
            request.headers.add(name: "transfer-encoding", value: "chunked")
            request.body = .stream(stream, length: .unknown)
            
            let res = try await client.execute(request, deadline: .distantFuture)
            #expect(res.status == .ok)
            
            for try await chunk in res.body {
                size += chunk.readableBytes
                print("R-\((Double(size)/Double(info.size)*100).formatted(.number.precision(.fractionLength(0...1))))%", terminator: " ")
            }
            
            #expect(size == info.size)
            
            print()
        }
    }
    
    @Test("Send 大文件流传输")
    func largeFilePostTest() async throws {
        try await withClient { client in
            var size = 0
            let url = FilePath(TestingShared.largeFilePath)
            let info = try #require(await FileSystem.shared.info(forFileAt: url))
            
            let stream = AsyncThrowingChannel<ByteBuffer, Error>()
            
            Task {
                var fileHandle: ReadFileHandle? = nil
                do {
                    let fh = try await FileSystem.shared.openFile(forReadingAt: url, options: .init())
                    fileHandle = fh
                    
                    var current: Int64 = 0
                    
                    for try await chunk in fh.readChunks(chunkLength: .kilobytes(64)) {
                        await stream.send(chunk)
                        current += .init(chunk.readableBytes)
                        print("W-\((Double(current)/Double(info.size)*100).formatted(.number.precision(.fractionLength(0...1))))%", terminator: " ")
                    }
                    try await fh.close()
                    stream.finish()
                } catch {
                    try await fileHandle?.close()
                    stream.fail(error)
                }
            }
            
            var request = HTTPClientRequest(url: "http://localhost:\(TestingShared.httpsListenPort)/file-echo")
            request.method = .POST
            request.headers.add(name: "content-disposition", value: url.lastComponent?.string  ?? "")
            request.headers.add(name: "Content-Type", value: "application/octet-stream")
            request.headers.add(name: "transfer-encoding", value: "chunked")
            request.body = .stream(stream, length: .unknown)
            
            let res = try await client.execute(request, deadline: .distantFuture)
            #expect(res.status == .ok)
            
            for try await chunk in res.body {
                size += chunk.readableBytes
                print("R-\((Double(size)/Double(info.size)*100).formatted(.number.precision(.fractionLength(0...1))))%", terminator: " ")
            }
            
            #expect(size == info.size)
            
            print()
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
