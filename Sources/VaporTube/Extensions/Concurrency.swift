import Dispatch
import ErrorHandle

@usableFromInline
final class SyncResultBox<T, E: Error>: @unchecked Sendable {
    @usableFromInline var result: Result<T, E>? = nil
    @usableFromInline init() {}
}

@inlinable
public func asyncResultToSync<T, E>(
    action: @escaping @Sendable () async -> Result<T, E>
) -> T where T: Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    
    let box = SyncResultBox<T, E>()
    
    Task {
        box.result = await action()
        semaphore.signal()
    }
    
    semaphore.wait()
    
    switch box.result {
    case .success(let storage): return storage
    case .failure(let error): fatalError(String(reflecting: error))
    case .none: fatalError("异步任务未返回结果却触发了信号量")
    }
}

@inlinable
public func asyncToSync<T, E>(
    action: @escaping @Sendable () async throws(E) -> T
) -> T where T: Sendable {
    asyncResultToSync {
        await .async { () throws(E) in
            try await action()
        }
    }
}

@inlinable
public func fatalIfFail<T>(
    action: () throws -> T
) -> T {
    do {
        return try action()
    } catch {
        fatalError(String(reflecting: error))
    }
}
