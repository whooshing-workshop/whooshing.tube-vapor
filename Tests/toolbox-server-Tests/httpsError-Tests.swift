import Testing
import Foundation
@testable import VaporTube

@Suite("Https HTTP 当传输遇到错误的处理测试集", .serialized)
struct HttpsErrorTests {
    
    let testString = "ErrorTesting"
    
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
        while await TestingShared.testStage != .httpsError {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("404-未找到", arguments: [HTTPMethod.GET, .POST, .PATCH, .PUT, .DELETE])
    func errorCode404Test(method: HTTPMethod) async throws {
        try await withClient { client in
            let res = try await client.execute(method, url: "http://localhost:\(TestingShared.httpsListenPort)/not-exist?value=\(testString)").get()
            #expect(res.status == .notFound)
        }
    }
    
    @Test("400-Get Query 必须但不存在")
    func errorCode400Test() async throws {
        try await withClient { client in
            var res = try await client.get(url: "http://localhost:\(TestingShared.httpsListenPort)/string-echo").get()
            #expect(res.status == .badRequest)
            res = try await client.get(url: "http://localhost:\(TestingShared.httpsListenPort)/string-echo?wrongquery=hello").get()
            #expect(res.status == .badRequest)
        }
    }
    
    @Test("415-Send 请求体数据不合法", arguments: [HTTPMethod.POST, .PATCH, .PUT, .DELETE])
    func errorCode415Test(method: HTTPMethod) async throws {
        try await withClient { client in
            let res = try await client.execute(method, url: "http://localhost:\(TestingShared.httpsListenPort)/string-echo").get()
            #expect(res.status == .unsupportedMediaType)
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
