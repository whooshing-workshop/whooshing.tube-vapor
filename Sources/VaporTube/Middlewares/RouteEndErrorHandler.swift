import Vapor

/// 用于将所有 Vapor 路由返回的错误转为 AbortError
public struct RouteEndErrorHandler: AsyncMiddleware {
    @inlinable
    init() {}
    
    @inlinable
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            throw error.vaporlized
        }
    }
}
