import Testing
import Foundation
@testable import VaporTube

@Suite("Https WebSocket 测试集", .serialized)
struct HttpsWebSocketTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .httpsWebSocket {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("WebSocket 数据交互", arguments: [
        (10000, "normal", 10),
        (10, "largest", 65535 * 20),
    ])
    func dataCommuteTest(paras: (Int, String, Int))  {
        let (times, suffix, chunkSize) = paras
        let tracker = OrderedIndexTracker(maxIndex: times - 1)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await WebSocket.connect(to: "ws://localhost:\(TestingShared.httpsListenPort)/websocket-echo-\(suffix)", configuration: .init(maxFrameSize: Int(UInt32.max))) { ws in
                    Task {
                        var printIndex = 0
                        for i in 0..<times {
                            var data = Self.randomData(size: chunkSize)
                            var d = ByteBuffer(integer: i)
                            d.writeBuffer(&data)
                            try await ws.send(d.readBytes(length: chunkSize)!)
                            if i == (times / 5) * printIndex {
                                printIndex += 1
                                print("writing: \(i)")
                            }
                        }
                        print("writing end: \(times - 1)")
                    }
                    
                    let readCounter = Counter(max: times)
                    
                    ws.onBinary { ws, data in
                        var d = data
                        let index: Int = d.readInteger()!
                        d.moveReaderIndex(to: 0)
                        await tracker.insert(index)
                        
                        if await index == (times / 5) * readCounter.value {
                            let _ = await readCounter.next()
                            print("reading: \(index)")
                        }
                        
                        if await tracker.isReady() {
                            print("reading end: \(times - 1)")
                            ws.close(promise: nil)
                            semaphore.signal()
                        }
                    }
                    
                    ws.onClose.whenComplete { res in
                        print("Closed")
                        switch res {
                        case .success():
                            semaphore.signal()
                        case .failure(let err):
                            print(err)
                            #expect(Bool(false))
                            semaphore.signal()
                        }
                    }
                }
            } catch {
                print(error)
                #expect(Bool(false))
                semaphore.signal()
            }
        }
        semaphore.wait()
    }
    
    @Test("连线失败")
    func connectionErrorTest() async throws {
        await #expect(throws: Error.self, performing: { try await WebSocket.connect(to: "ws://127.0.0.1:100000", onUpgrade: { _ in }) })
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
