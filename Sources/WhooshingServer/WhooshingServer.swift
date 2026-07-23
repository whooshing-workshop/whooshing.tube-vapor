import Vapor
import Fluent
import ErrorHandle
import AnyCodable
import LoggingAdvanced
import FluentPostgresDriver
import NIOConcurrencyHelpers

public protocol DebugConfig: Sendable {
    var config: Environment.Config { get }
}

/// 描述一个 Whooshing 系统子服务，提供基本的服务控制操作
public protocol WhooshingService: Sendable {
    associatedtype Failure: Err
    
    /// 底层 Vapor 应用实例
    var app: Application { get }
    /// 当前环境的配置项（端口、数据库等）
    var config: Environment.Config { get }
    /// 当前服务使用的日志记录器
    var logger: Logger { get set }
    /// 该服务所有连接的数据库
    var databases: Set<Environment.DB> { get }
    /// 调试参数
    var debugingData: Https.Debuging? { get }
    /// 异步启动应用并监听请求（会阻塞直到关闭）
    func execute() async -> Result<Void, Failure>
    /// 异步关闭 Vapor 应用
    func asyncShutdown() async -> Result<Void, Failure>
    /// 依次执行应用启动与关闭
    func executeWithAsyncShutdown() async -> Result<Void, Failure>
}

/// 通用服务启动器，封装对 Vapor 应用的初始化、配置与生命周期控制
///
/// 该类用于启动不同的服务模块，使用 `Whooshing.make(_)` 创建一个 Whooshing 实例
/// 并调用 `execute()` 或 `excuteWithAsyncShutdown()` 令其运行
public final class Whooshing: WhooshingService, @unchecked Sendable {
    
    public typealias Failure = Errcase.ErrType
    
    /// 启动模式枚举，表示当前服务运行的目标环境
    ///
    /// 可以指定运行模式为 production, debug, independentDebug
    ///
    /// Mode.detect 表示自动从环境变量检测运行模式
    ///
    /// 其中，independentDebug 表示不依赖任何外部模块，比如用户身份认证模块，服务管理模块等等
    /// 自动内部处理这些认证请求，保证可无依赖运行在本机。
    /// 而这需要提供一些服务参数，不同的服务需要不同的参数，见
    ///
    /// - ``Api.Debuging``
    /// - ``Inline.Debuging``
    /// - ``Https.Debuging``
    ///
    /// - Warning: independentDebug 模式应当永远仅仅用作测试，请勿在生产环境使用
    @frozen
    public struct Mode: Sendable, CustomStringConvertible, Loggerable {
        
        /// 生产环境，使用正式配置
        @inlinable public static var production: Mode { Mode(envrionment: .production) }
        
        /// 调试环境，使用 development 配置
        @inlinable public static var debug: Mode { Mode(envrionment: .development) }
        
        /// 独立调试配置，传入调试参数结构体
        /// > 在一般的 .production 或 .debug 模式下，
        /// 这些参数会通过 Whooshing 系统的环境变量解析得到，
        /// 而在无依赖 debug 模式下，则需要提供伪造的参数进行运行测试
        /// - Warning: 该模式应当永远仅仅用作测试，请勿在生产环境使用
        @inlinable public static func independentDebug(_ debuging: Https.Debuging) -> Mode { Mode(envrionment: .development, debuging: debuging) }
        
        /// 测试配置，传入调试参数结构体应当仅仅用在单元测试中
        /// > 在一般的 .production 或 .debug 模式下，
        /// 这些参数会通过 Whooshing 系统的环境变量解析得到，
        /// 而在无依赖 debug 模式下，则需要提供伪造的参数进行运行测试
        /// - Warning: 该模式应当永远仅仅用作测试，请勿在生产环境使用
        @inlinable public static func testing(_ debuging: Https.Debuging) -> Mode { Mode(envrionment: .testing, debuging: debuging) }
        
        /// 自动从环境变量变量判断运行模式，你需要选择提供调试参数
        /// 若你希望永远不使用 testing 或 independentDebug 模式，可以指定为 nil
        /// 这样若环境中出现了这两个模式，将会直接触发 fatalError
        ///
        /// Mode.production 对应 --env production
        /// Mode.debug 与 Mode.independentDebug 对应 --env development
        /// Mode.testing 对应 --env testing
        ///
        /// > 在一般的 .production 或 .debug 模式下，
        /// 这些参数会通过 Whooshing 系统的环境变量解析得到，
        /// 而在无依赖 debug 模式下，则需要提供伪造的参数进行运行测试
        @inlinable public static func detect(_ debuging: Https.Debuging? = nil) -> Mode {
            let env = try! Environment.detect()
            return Mode(envrionment: env, debuging: debuging)
        }
        
        /// 当前运行的环境
        public var envrionment: Environment
        
        @usableFromInline
        let debuging: Https.Debuging?
        
        @inlinable init(envrionment: Environment, debuging: Https.Debuging? = nil) {
            self.envrionment = envrionment
            self.debuging = debuging
        }
        
        public var json: [String: AnyCodable] {[
            "env": AnyCodable(envrionment.name),
            "is_release": AnyCodable(envrionment.isRelease),
            "arguments": AnyCodable(envrionment.arguments)
        ]}
        
        public var description: String {
            formatJson(json)
        }
        
        public var summaryDescription: String {
            "env-\(envrionment.name)\(envrionment.isRelease ? "-release" : "")"
        }
    }
    
    /// 底层 Vapor 应用实例
    public let app: Application
    /// 当前环境的配置项（端口、数据库等）
    public let config: Environment.Config
    /// 当前服务使用的日志记录器
    public var logger: Logger {
        get { lock.withLock { __logger } }
        set { lock.withLock { __logger = newValue } }
    }
    
    private var __logger: Logger
    private let lock = NIOLock()
    
    /// 该服务所有连接的数据库
    public private(set) lazy var databases: Set<Environment.DB> = {
        .init(self.config.dbServices.flatMap { $0.dbs })
    }()
    
    /// 调试参数
    public let debugingData: Https.Debuging?
    
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
        config: Environment.Config,
        debugingData: Https.Debuging?,
        logger: Logger
    ) {
        self.app = app
        self.config = config
        self.debugingData = debugingData
        __logger = logger
    }
}

public extension Whooshing {
    @frozen
    struct BootstrapParas: Sendable {
        @usableFromInline
        let debuging: Https.Debuging?
        
        @usableFromInline
        let logger: Logger
        
        @usableFromInline
        let environment: Environment
        
        @usableFromInline
        let config: Environment.Config
        
        @usableFromInline
        let driverKeys: [any Environment.DriverKey.Type]
        
        public let loggingFactory: LoggingFactory
        
        @usableFromInline
        init(
            debuging: Https.Debuging?,
            logger: Logger,
            environment: Environment,
            config: Environment.Config,
            driverKeys: [any Environment.DriverKey.Type],
            loggingFactory: LoggingFactory
        ) {
            self.debuging = debuging
            self.logger = logger
            self.environment = environment
            self.config = config
            self.driverKeys = driverKeys
            self.loggingFactory = loggingFactory
        }
    }
}

public extension Whooshing {
    /// - Parameters:
    ///   - mode: 启动环境
    ///   - driverKeys: 要注入的驱动列表
    ///   - logger: 该服务要使用的日志记录器
    ///   - loggingFactory: 该服务将配置的日志工厂，whooshing 实例不主动启动其 bootstrap 函数，仅配置日志策略，但不启动，由外部调用者自行决定合适启用
    @inlinable
    static func bootstrap(
        _ mode: Mode,
        driverKeys: [any Environment.DriverKey.Type] = [],
        logger: Logger,
        loggingFactory: LoggingFactory? = nil
    ) async -> Result<BootstrapParas, Failure> {
        await .async { () throws(Failure) in
            let initLogger = logger.derive(subId: "sysinit")
            
            initLogger.info("正在初始化 Whooshing 服务", metadata: ["mode": .summaryData(mode)])
            initLogger.debug("详细参数", metadata: ["mode": .data(mode)])
            
            let config: Environment.Config
            
            var env = mode.envrionment
            
            // 修复 Vapor 在 swift test 下会错误解析 SPM 注入的参数（如 --test-bundle-path 等）
            // 如果是在 testing 环境，或是检测到有 xctest 相关的参数，直接清理参数
            if env == .testing || env.arguments.contains(where: { $0.contains("xctest") || $0.hasPrefix("--test") }) {
                env.arguments = ["vapor"]
            }
            
            if ![Environment.production, .development, .testing].contains(env) {
                fatalError("环境变量 \(env.name) 无法识别")
            }
            
            var strategies: [LoggerStrategy] = []
            
            var debugPara: Https.Debuging? = nil
            if let dp = mode.debuging {
                if [Environment.development, .testing].contains(env) {
                    initLogger.info("启动无依赖独立运行模式")
                    debugPara = dp
                    config = dp.config
                } else {
                    config = try required(throws: Self.Errcase.environmentFailed, category: .inherit) {
                        try Environment.get(with: Https.envPrefix, driverKeys: driverKeys)
                    }
                }
            } else {
                if env == .testing {
                    fatalError("未提供调试数据，无法进入 testing 模式")
                } else {
                    config = try required(throws: Self.Errcase.environmentFailed, category: .inherit) {
                        try Environment.get(with: Https.envPrefix, driverKeys: driverKeys)
                    }
                }
            }
            
            let logDir = config.log.directory.appendingPathComponent(Https.name.lowercased())
            initLogger.debug("准备日志轮转系统", metadata: ["directory": .stringConvertible(logDir)])
            
            let errorLogDir = logDir.appendingPathComponent("error_logs")
            try required(throws: Errcase.loggingSystemFailed, metadata: ["directory": .stringConvertible(errorLogDir)], category: .inherit) {
                try strategies.append(
                    .init(
                        label: "error",
                        level: .error,
                        config: .file(logPrefix: "", directory: errorLogDir, name: "error.log")
                    )
                )
            }
            
            let businessLogDir = logDir.appendingPathComponent("business_logs")
            try required(throws: Errcase.loggingSystemFailed, metadata: ["directory": .stringConvertible(businessLogDir)], category: .inherit) {
                try strategies.append(
                    .init(
                        label: "business",
                        level: .trace,
                        config: .file(
                            match: {
                                $0.contains("vapor") ||
                                $0.hasPrefix(logger.label + "." + "woo")
                            },
                            directory: businessLogDir,
                            name: "business.log"
                        )
                    )
                )
            }
            
            for driverKey in driverKeys {
                strategies += driverKey.loggerStrategies(for: logDir)
            }
            
            let factory = switch loggingFactory {
            case .none: LoggingFactory(strategies: strategies)
            case .some(let f): f.append(strategies: strategies)
            }
            
            return BootstrapParas(
                debuging: debugPara,
                logger: logger,
                environment: env,
                config: config,
                driverKeys: driverKeys,
                loggingFactory: factory
            )
        }
    }
}

extension Whooshing {
    /// 构建 Https 服务的运行实例
    /// - Parameters:
    ///   - env: 启动环境
    ///   - driverKeys: 要注入的驱动列表
    ///   - logger: 该服务要使用的日志记录器
    ///   - loggingFactory: 该服务将配置的日志工厂，whooshing 实例不主动启动其 bootstrap 函数，仅配置日志策略，但不启动，由外部调用者自行决定合适启用
    @inlinable
    public static func make(
        _ paras: BootstrapParas
    ) async -> Result<Whooshing, Failure> {
        await makeService(paras: paras) { woo throws(Https.Errcase.ErrType) in
            try await Https.config(woo)
        }
    }
}

extension Whooshing {
    @inlinable
    static func makeService(
        paras: BootstrapParas,
        config conf: (Whooshing) async throws(Https.Errcase.ErrType) -> Void
    ) async -> Result<Whooshing, Failure> {
        await .async() { () throws(Failure) in
            let debugPara = paras.debuging
            let logger = paras.logger
            let env = paras.environment
            let config = paras.config
            
            let initLogger = logger.derive(subId: "sysinit")
            
            initLogger.debug("准备 Vapor 实例")

            let app = try await required(throws: Self.Errcase.vaporAppCreateFailed, category: .internal) {
                try await Application.make(env)
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
            let service = Self(app: app, config: config, debugingData: debugPara, logger: logger.derive(subId: "woo"))
            do {
                try await conf(service)
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
