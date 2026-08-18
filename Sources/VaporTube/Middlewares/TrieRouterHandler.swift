import Vapor
@preconcurrency import RoutingKit

struct TrieRouterMiddleware: AsyncMiddleware {
    let router: TrieRouter<VaporTube.Handler>

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let pathSegments = request.url.path
            .split(separator: "/")
            .map(String.init)
            
        let fullRoutePath = [request.method.rawValue] + pathSegments
        
        var params = Parameters()
        
        if let handler = router.route(
            path: fullRoutePath,
            parameters: &params
        ) {
            request.parameters = params
            
            let encodable = try await handler(request)
            return try await encodable.encodeResponse(for: request)
        }

        return try await next.respond(to: request)
    }
}
