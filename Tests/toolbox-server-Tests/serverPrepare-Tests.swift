import Testing
import Foundation
@testable import VaporTube

@Suite("准备 Server", .serialized)
struct ServerPrepare {
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .serverPrepare {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("启动 Server")
    func startServer() async throws {
        try await Entrypoint.runServices(
            shouldStop: {
                await TestingShared.testStage == .done
            },
            onReady: {
                await MainActor.run {
                    let currentRaw = TestingShared.testStage.rawValue
                    TestingShared.testStage = TestingShared.TestStage(rawValue: currentRaw + 1)!
                }
            }
        )
    }
}
