import Testing
import Foundation
import AsyncHTTPClient
import AsyncAlgorithms
@testable import VaporTube

@Suite("Https 流网络通讯测试集", .serialized)
struct HttpsStreamingTests {
    
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
        while await TestingShared.testStage != .httpsStreaming {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("Send stream 流请求测试", arguments: [HTTPMethod.POST])
    func sendStreamingTest(method: HTTPMethod) async throws {
        try await withClient { client in
            let pieces: Int64 = 10
            let chunkSize: Int64 = 1024
            let totalSize = pieces * chunkSize
            var size = 0
            let stream = AsyncThrowingChannel<ByteBuffer, Error>()
            Task {
                var current: Int64 = 0
                
                for _ in 0..<pieces {
                    let data = Self.randomData(size: .init(chunkSize))
                    await stream.send(data)
                    current += .init(data.readableBytes)
                    print("W-\(current)/\(totalSize)", terminator: "\n")
                }
                
                stream.finish()
            }
            
            var request = HTTPClientRequest(url: "http://localhost:\(TestingShared.httpsListenPort)/streaming-echo")
            request.method = method
            request.headers.add(name: "Content-Type", value: "application/octet-stream")
            request.headers.add(name: "transfer-encoding", value: "chunked")
            request.body = .stream(stream, length: .unknown)
            
            let res = try await client.execute(request, deadline: .distantFuture)
            #expect(res.status == .ok)
            
            for try await chunk in res.body {
                size += chunk.readableBytes
                print("R-\(size)/\(totalSize)", terminator: "\n")
            }
            
            #expect(size == totalSize)
        }
    }
    
    @Test("Send stream 流请求抛错测试")
    func sendStreamingThrowingTest() async throws {
        await withClient { client in
            let error = Abort(.init(statusCode: 1111, reasonPhrase: "Testing"))
            let stream = AsyncThrowingChannel<ByteBuffer, Error>()
            stream.fail(error)
            
            var request = HTTPClientRequest(url: "http://localhost:\(TestingShared.httpsListenPort)/streaming-echo")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/octet-stream")
            request.headers.add(name: "transfer-encoding", value: "chunked")
            request.body = .stream(stream, length: .unknown)
            
            await #expect(throws: Error.self, performing: {
                try await client.execute(request, deadline: .distantFuture)
            })
        }
    }
    
    @Test("Post stream 流大数据请求测试")
    func sendLargeStreamingTest() async throws {
        try await withClient { client in
            let pieces: Int64 = 100
            let chunkSize: Int64 = 65535
            let totalSize = pieces * chunkSize
            var size = 0
            let stream = AsyncThrowingChannel<ByteBuffer, Error>()
            Task {
                var current: Int64 = 0
                
                for _ in 0..<pieces {
                    let data = Self.randomData(size: .init(chunkSize))
                    await stream.send(data)
                    current += .init(data.readableBytes)
                    print("W-\(current)/\(totalSize)", terminator: "\n")
                }
                
                stream.finish()
            }
            
            var request = HTTPClientRequest(url: "http://localhost:\(TestingShared.httpsListenPort)/streaming-echo")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/octet-stream")
            request.headers.add(name: "transfer-encoding", value: "chunked")
            request.body = .stream(stream, length: .unknown)
            
            let res = try await client.execute(request, deadline: .distantFuture)
            #expect(res.status == .ok)
            
            for try await chunk in res.body {
                size += chunk.readableBytes
                print("R-\(size)/\(totalSize)", terminator: "\n")
            }
            
            #expect(size == totalSize)
        }
    }
    
    static func randomData(size: Int) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: size)
        var rng = SystemRandomNumberGenerator()
        let randomBytes = (0..<size).map { _ in UInt8.random(in: 0...255, using: &rng) }
        buffer.writeBytes(randomBytes)
        return buffer
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
