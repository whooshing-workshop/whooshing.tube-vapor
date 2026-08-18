import ErrorHandle
import NIOAdvanced

public extension VaporTube {
    @frozen
    enum Errcase: String, ErrList, Sendable {
        case vaporAppCreateFailed = "Vapor App 创建失败"
        case serviceInitFailed = "服务初始化配置失败"
        case executionFailed = "运行时出错，错误未被处理"
        case shutdownFailed = "关闭服务时出错"
    }
}

public extension Error {
    var vaporlized: AbortError {
        return errorInterpret(error: self)
        
        @Sendable
        func errorInterpret<T: Error>(error: T) -> AbortError {
            if let err = error as? any Err {
                let reason = String(describing: err.error.rawValue) + (err.explain == nil ? "" : ", " + err.explain!)
                
                switch err.category {
                case .external(suggestions: let suggestions):
                    return Abort(
                        .badRequest,
                        reason: reason,
                        identifier: err.error.identifier,
                        suggestedFixes: suggestions,
                        file: err.file,
                        function: err.function,
                        line: .init(err.line)
                    )
                case .inherit:
                    if let subError = err.subError {
                        return errorInterpret(error: subError)
                    }
                    
                    fallthrough
                case .internal:
                    return Abort(
                        .internalServerError,
                        reason: "服务器内部错误",
                        identifier: err.error.identifier,
                        suggestedFixes: ["请联系管理员以解决该错误"],
                        file: err.file,
                        function: err.function,
                        line: .init(err.line)
                    )
                case .none: fatalError("错误处理系统异常")
                }
            } else if let err = error as? AbortError {
                return err
            } else {
                return Abort(
                    .internalServerError,
                    reason: "服务器内部错误",
                    identifier: "Unknown",
                    suggestedFixes: ["请联系管理员以解决该错误"]
                )
            }
        }
    }
}

public extension EventLoopResult {
    var vaporlized: EventLoopFuture<Value> {
        return self.wrapped.flatMapErrorThrowing { error in
            throw error.vaporlized
        }
    }
}
