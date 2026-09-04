import Vapor
import Nexus

struct ConfigInjector: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.storage[ConfigKey.self] = request.application.nexus.config
        return try await next.respond(to: request)
    }
}
