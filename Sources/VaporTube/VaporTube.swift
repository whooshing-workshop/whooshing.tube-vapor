import Nexus
import Vapor
import LoggingAdvanced

public protocol DebugConfig: Sendable {
    var config: Environment.Config { get }
}

/// 通用服务启动器，封装对 Vapor 应用的初始化、配置与生命周期控制
///
/// 该类用于启动不同的服务模块，使用 `Whooshing.make(_)` 创建一个 Whooshing 实例
/// 并调用 `execute()` 或 `excuteWithAsyncShutdown()` 令其运行
public final class VaporTube: Tube, @unchecked Sendable {
    /// 底层 Vapor 应用实例
    public let app: Application
    /// 当前服务使用的日志记录器
    public let logger: Logger
    
    /// 异步启动应用并监听请求（会阻塞直到关闭）
    @inlinable
    public func execute() async -> Result<Void, Failure> {
        await .async(throws: Errcase.executionFailed, category: .internal) {
            try await app.execute()
        }
    }
    /// 异步关闭 Vapor 应用
    @inlinable
    public func asyncShutdown() async -> Result<Void, Failure> {
        await .async(throws: Errcase.shutdownFailed, category: .internal) {
            try await app.asyncShutdown()
        }
    }
    /// 依次执行应用启动与关闭
    @inlinable
    public func executeWithAsyncShutdown() async -> Result<Void, Failure> {
        await .async { () throws(Failure) in
            try await execute().get()
            try await asyncShutdown().get()
        }
    }
    
    @usableFromInline
    init(
        app: Application,
        logger: Logger
    ) {
        self.app = app
        self.logger = logger
    }
}

public extension VaporTube {
    typealias Request = Vapor.Request
    typealias Response = Vapor.Response
    typealias HandlerResponse = Vapor.Content
    typealias Failure = Errcase.ErrType
}

extension VaporTube {
    /// 构建 Vapor 服务的运行实例
    /// - Parameters:
    ///   - env: 启动环境
    ///   - driverKeys: 要注入的驱动列表
    ///   - logger: 该服务要使用的日志记录器
    ///   - loggingFactory: 该服务将配置的日志工厂，whooshing 实例不主动启动其 bootstrap 函数，仅配置日志策略，但不启动，由外部调用者自行决定合适启用
    @inlinable
    public static func make(
        _ paras: Bootstrap.Paras
    ) async -> Result<VaporTube, Failure> {
        await makeService(paras: paras) { _ throws(Errcase.ErrType) in }
    }
}

extension VaporTube {
    @usableFromInline
    static func makeService(
        paras: Bootstrap.Paras,
        config conf: (VaporTube) async throws(Errcase.ErrType) -> Void
    ) async -> Result<VaporTube, Failure> {
        await .async() { () throws(Failure) in
            let logger = paras.logger
            let env = paras.environment
            let config = paras.config
            
            let initLogger = logger.derive(subId: "sysinit")
            
            initLogger.debug("准备 Vapor 实例")

            let app = try await required(throws: Self.Errcase.vaporAppCreateFailed, category: .internal) {
                try await Application.make(env, .shared(paras.eventLoopGroup))
            }
            app.logger = logger.derive(subId: "vapor")
            app.http.server.configuration.hostname = config.hostname
            app.http.server.configuration.port = config.port
            
            initLogger.debug("准备数据库实例")
            
            if env == .testing {
                for dbService in config.dbServices {
                    for db in dbService.dbs {
                        app.databases.use(
                            .postgres(
                                configuration: db.testingConfig,
                                maxConnectionsPerEventLoop: 1,
                                connectionPoolTimeout: .seconds(10),
                                sqlLogLevel: .debug
                            ),
                            as: db.id
                        )
                    }
                }
            } else {
                for dbService in config.dbServices {
                    for db in dbService.dbs {
                        app.databases.use(
                            .postgres(
                                configuration: db.config,
                                maxConnectionsPerEventLoop: 1,
                                connectionPoolTimeout: .seconds(10),
                                sqlLogLevel: .info
                            ),
                            as: db.id
                        )
                    }
                }
            }
            let service = Self(app: app, logger: logger.derive(subId: "woo"))
            app.serviceRegistry = .init(managerURL: config.managerUrl, moduleID: config.id)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            ContentConfiguration.global.use(decoder: decoder, for: .json)
            do {
                try await conf(service)
                app.middleware.use(RouteEndErrorHandler())
            } catch {
                let err = Self.Errcase.serviceInitFailed.subErr(error, category: .internal)
                service.logger.report(error: err)
                do {
                    try await service.asyncShutdown().get()
                } catch {
                    service.logger.warning("Service 异常退出时的二次清理发生故障: \(error)")
                }
                throw err
            }
            return service
        }
    }
}
