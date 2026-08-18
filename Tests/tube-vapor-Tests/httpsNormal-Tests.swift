import Testing
import Foundation
@testable import VaporTube

@Suite("Https 基本网络通讯测试集", .serialized)
struct HttpsNormalTests {
    
    let testString = "Hello World!"
    
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
        while await TestingShared.testStage != .httpsNormal {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("HTTP send zero body 请求测试", arguments: [HTTPMethod.GET, .POST, .PATCH, .PUT, .DELETE])
    func sendZeroBodyRequestTest(method: HTTPMethod) async throws {
        try await withClient { client in
            let res = try await client.execute(method, url: "http://localhost:\(TestingShared.httpsListenPort)/no-body").get()
            #expect(res.status == .ok)
            #expect(res.headers.contains(name: "content-length"))
            let length = try Int(#require(res.headers.first(name: "content-length")))
            #expect(length == "NO-BODY".lengthOfBytes(using: .utf8))
            var body = try #require(res.body)
            #expect(body.readString(length: body.readableBytes) == "NO-BODY")
        }
    }
    
    @Test("HTTP send 请求测试", arguments: [HTTPMethod.GET, .POST, .PATCH, .PUT, .DELETE])
    func sendRequestTest(method: HTTPMethod) async throws {
        try await withClient { client in
            let req = try HTTPClient.Request(
                url: "http://localhost:\(TestingShared.httpsListenPort)/string-echo?value=\(testString)",
                method: method,
                headers: ["Content-Type": "text/plain"],
                body: .string(testString)
            )
            
            let res = try await client.execute(request: req, deadline: .distantFuture).get()
            #expect(res.status == .ok)
            #expect(res.headers.contains(name: "content-length"))
            let length = try Int(#require(res.headers.first(name: "content-length")))
            #expect(length == testString.lengthOfBytes(using: .utf8))
            var body = try #require(res.body)
            #expect(body.readString(length: body.readableBytes) == testString)
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
