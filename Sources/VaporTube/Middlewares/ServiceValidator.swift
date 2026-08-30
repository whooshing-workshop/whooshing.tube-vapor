import Vapor

/// 验证来源服务是否合法的中间件
///
/// 方法是，其必须在请求头 “X-Module-ID” 附上其服务 ID，且必须是已在 Manager 中注册的 ID
/// 本中间件对照缓存中的服务列表检查该请求头，
/// 如果存在: 则接受连线
/// 若不存在: 询问 Manager
///          若 Manager 验证通过: 将该 ID 添加入缓存，同时允许连线
///          若 Manager 验证失败: 拒绝连线并报错
/// 同时，若来源服务的 ID 与本 ID 相同，则拒绝连线
///
/// Manager 的 ID 列表 Fetch API 应为: [GET] HTTP://MANAGER_URL/modules
/// Manager 的 ID 验证 API 应为: [GET] HTTP://MANAGER_URL/modules/MODULE_ID/verify
public struct ServiceValidator: AsyncMiddleware {
    public static let headerName: String = "X-Module-ID"
    
    public struct Identifier: Authenticatable {
        public let incomingId: UUID
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard
            let idString = request.headers.first(name: Self.headerName),
            let sourceModuleID = UUID(uuidString: idString)
        else {
            throw Abort(.unauthorized, reason: "未找到 \(Self.headerName) 请求头")
        }

        try await request.application.serviceRegistry.verify(
            moduleID: sourceModuleID,
            client: request.client,
            logger: request.logger
        )
        
        request.auth.login(Identifier(incomingId: sourceModuleID))
        
        return try await next.respond(to: request)
    }
    
    public init() {}
}

actor ServiceRegistry {
    /// 服务 ID 缓存池
    private var allowedModuleIDs: Set<UUID> = []
    private let managerURL: URL
    private let moduleID: UUID

    init(
        managerURL: URL,
        moduleID: UUID
    ) {
        self.managerURL = managerURL
        self.moduleID = moduleID
    }

    /// 向 Manager 拉取所有有效模块列表
    func syncFromManager(client: Client) async throws {
        struct ManagerListResponse: Content {
            let moduleIDs: [UUID]
        }
        let response = try await client.get("\(managerURL)/modules")
        let data = try response.content.decode(ManagerListResponse.self)
        self.allowedModuleIDs = Set(data.moduleIDs)
    }

    /// 校验模块 ID（本地命中直接返回；未命中则远程查验并动态更新）
    func verify(moduleID: UUID, client: Client, logger: Logger) async throws(VaporTube.Errcase.ErrType) {
        
        guard self.moduleID != moduleID else {
            throw VaporTube.Errcase.serviceValidateFailed.d("非法的模块 \(moduleID)", category: .external(suggestions: ["请使用合法的模块进行请求"], userdata: .init(HTTPResponseStatus.unauthorized)))
        }
        
        let logger = logger.derive(metadata: ["module_id": .summaryData(moduleID)])
        logger.info("校验来源模块是否合法")
        
        if allowedModuleIDs.contains(moduleID) { return }

        // 向 Manager 确认单个模块 ID
        struct VerifyResponse: Content {
            let allowed: Bool
        }
        
        let response: ClientResponse
        
        do {
            response = try await client.get("\(managerURL)/modules/\(moduleID)/verify")
        } catch {
            throw VaporTube.Errcase.serviceValidateFailed.d("向模块管理服务请求服务确认时失败", category: .internal)
        }
        
        guard
            response.status == .ok,
            let result = try? response.content.decode(VerifyResponse.self),
            result.allowed
        else {
            throw VaporTube.Errcase.serviceValidateFailed.d("验证未通过，非法的模块 \(moduleID)", category: .external(suggestions: ["请使用合法的模块进行请求"], userdata: .init(HTTPResponseStatus.unauthorized)))
        }

        logger.info("来源模块合法，允许连线")
        
        // 验证通过，加入本地缓存
        allowedModuleIDs.insert(moduleID)
    }
}

extension Application {
    struct ServiceRegistryKey: StorageKey {
        typealias Value = ServiceRegistry
    }

    var serviceRegistry: ServiceRegistry {
        get {
            guard let registry = self.storage[ServiceRegistryKey.self] else {
                fatalError("ServiceRegistry 未配置, 使用app.serviceRegistry = ...")
            }
            return registry
        }
        set {
            self.storage[ServiceRegistryKey.self] = newValue
        }
    }
}
