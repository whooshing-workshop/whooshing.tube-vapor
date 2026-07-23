import Testing
import Foundation
import NIOConcurrencyHelpers
@testable import VaporTube

struct TestingShared {
    enum TestStage: Int {
        case serverPrepare
        case enviromentParsing
        case driverEnvParsing
        case httpsFile
        case httpsError
        case httpsNormal
        case httpsStreaming
        case httpsWebSocket
        case done
    }
    
    @MainActor static var testStage: TestStage = .serverPrepare
    
    static let httpsListenPort = 6501
    
    static let testingPaths = FilePreparePaths(
        small: "./testing_files/test.png",
        large: "./testing_files/large.zip",
        smallSize: 3 * 1024 * 1024, // 3M
        largeSize: 1 * 1024 * 1024 * 1024, // 1G
        smallChunk: 1 * 1024 * 1024,
        largeChunk: 1 * 1024 * 1024
    )
    
    nonisolated(unsafe) static var normalFilePath: String!
    static let normalFileName = "test.png"
    nonisolated(unsafe) static var largeFilePath: String!
    static let largeFileName = "large.zip"
    
    static let logLevel = Logger.Level.notice
    
    static var initLoggingSystem: Bool {
        get { lock.withLock { __initLoggingSystem } }
        set { lock.withLock { __initLoggingSystem = newValue } }
    }
    nonisolated(unsafe) private static var __initLoggingSystem = false
    private static let lock = NIOLock()
}

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 30)

func makeHttpsClient() -> HTTPClient {
    HTTPClient(eventLoopGroup: eventLoopGroup.next(), configuration: .singletonConfiguration)
}

#if !canImport(Darwin) || os(macOS)

func isTCPPortOpen(_ port: Int) -> Bool {
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "lsof -i :\(port)"]
    task.standardOutput = pipe
    task.standardError = pipe
    do { try task.run() } catch { return false }
    task.waitUntilExit()
    return task.terminationStatus == 0
}

#else

import Network
import NIOConcurrencyHelpers

func isTCPPortOpen(_ port: Int) -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    let isOpen = SendableBool()
    
    guard
        port <= UInt16.max,
        port >= UInt16.min,
        let port = NWEndpoint.Port(rawValue: UInt16(port))
    else { return false }
    
    let connection = NWConnection(
        host: NWEndpoint.Host("localhost"),
        port: port,
        using: .tcp
    )

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            isOpen.bool = true
            connection.cancel()
            semaphore.signal()

        case .failed(_), .cancelled:
            isOpen.bool = false
            semaphore.signal()

        default:
            break
        }
    }

    connection.start(queue: .global())
    _ = semaphore.wait(timeout: .now() + 2)

    return isOpen.bool
}

final class SendableBool: @unchecked Sendable {
    public var bool: Bool {
        get { lock.withLock { __bool } }
        set { lock.withLock { __bool = newValue } }
    }
    private var __bool: Bool
    private let lock = NIOLock()
    
    init(_ bool: Bool = false) {
        self.__bool = bool
    }
}

#endif

actor OrderedIndexTracker {
    private var received = Set<Int>()
    private let maxIndex: Int
    init(maxIndex: Int) { self.maxIndex = maxIndex }
    func insert(_ index: Int) { received.insert(index) }
    func isReady() -> Bool { received.count == (maxIndex + 1) }
}

actor Counter {
    private var max: Int
    var value = 0
    
    init(max: Int, value: Int = 0) {
        self.max = max
        self.value = value
    }
    
    func next() -> Int {
        let current = value
        value += 1
        return current
    }
    
    func add(_ int: Int) { value += int }
    
    var isLast: Bool { value == max }
}


actor Verifier {
    private(set) var isFullFill = false
    func fullFill() { isFullFill = true }
}
