import FluentPostgresDriver
import Vapor
import Cryptos
import LoggingAdvanced
import OrderedCollections
import NIOConcurrencyHelpers
import Foundation

public extension Environment {
    /// 代表服务模块当前环境的配置项，例如服务端口、数据库信息、域名等。
    @frozen
    struct Config: @unchecked Sendable, CustomStringConvertible, Loggerable {
        /// 模块 ID，又名 moduleId，仅用于模块区分，与 Inline 模块的 ServiceId 不同，切勿混用
        /// 所有三个子模块(https, inline, api)的模块 ID 必须相同
        public let id: UUID
        /// 模块名称，所有三个子模块(https, inline, api)的模块名称必须相同
        public let name: String
        /// 当前服务监听的端口号
        public let port: Int
        /// 当前服务的监听地址
        public let hostname: String
        /// 所配置的数据库列表，仅支持 PostgreSQL 数据库
        public let dbServices: [DBService]
        /// 服务管理平台的基础 URL，用于内部通信
        public let managerUrl: URL
        /// 可选的域名信息
        public let domain: String?
        /// 日志输出配置
        /// 提供 Rotating 功能，单个文件过大将输出至新文件中且备份旧日志
        public let log: Log
        
        /// 存储所有的 storage key，可用于遍历 storage 的内容
        public let driverKeys: [any DriverKey.Type]
        /// 提供额外的 storage，用于存储扩展参数
        public var storage: Storage {
            get { lock.withLock { __storage } }
            set { lock.withLock { __storage = newValue } }
        }
        
        private let lock = NIOLock()
        private var __storage = Storage()
        
        /// 初始化环境配置，仅在 ``Whooshing.Env`` 为 `.independentDebug(...)` 时才可能使用
        /// 这些参数在非 `.independentDebug(...)` 模式下会自动从环境变量中读取
        /// - Parameters:
        ///   - id: 模块 ID，又名 moduleId，仅用于模块区分，与 Inline 模块的 ServiceId 不同，切勿混用。所有三个子模块(https, inline, api)的模块 ID 必须相同
        ///   - name: 模块名称，所有三个子模块(https, inline, api)的模块名称必须相同
        ///   - hostname: 服务监听地址
        ///   - port: 服务监听端口
        ///   - dbServices: 数据库服务列表
        ///   - managerUrl: 模块管理器的 URL 链接
        ///   - domain: 可选域名信息
        ///   - log: 日志输出配置，若指定为 nil(仅测试及独立开发环境)，则在用户目录下创建 ~/whooshing_logs/项目名_logs 文件夹
        ///   - driverKeys: 要注入的驱动列表
        public init(
            id: UUID,
            name: String,
            port: Int = 6500,
            hostname: String = "127.0.0.1",
            dbServices: [DBService] = [],
            managerUrl: URL = .init(string: "http://testing.com")!,
            domain: String? = nil,
            log: Log? = nil,
            driverKeys: [any DriverKey.Type] = [],
        ) {
            self.id = id
            self.name = name
            self.port = port
            self.hostname = hostname
            self.dbServices = dbServices
            self.managerUrl = managerUrl
            self.domain = domain
            self.log = log ?? .init(
                directory: .homeDirectoryURL.appending(component: "whooshing_logs").appending(
                    component: (name.split(separator: " ").joined(separator: "_") + "_logs").snakeCase
                )
            )
            self.driverKeys = driverKeys
        }
        
        @inlinable
        public var json: [String: AnyCodable] {
            var paras: [String: AnyCodable] = [:]
            for key in driverKeys {
                paras[key.label] = AnyCodable(storage[key])
            }
            
            return [
                "id": AnyCodable(id),
                "name": AnyCodable(name),
                "port": AnyCodable(port),
                "hostname": AnyCodable(hostname),
                "db_services": AnyCodable(dbServices.map { $0.json }),
                "manager_url": AnyCodable(managerUrl),
                "domain": AnyCodable(domain),
                "log": AnyCodable(log.json),
                "storage": AnyCodable(paras)
            ]
        }
        
        @inlinable
        public var description: String {
            formatJson(json)
        }
    }
    
    /// 日志系统的配置项
    /// 日志文件提供 Rotating 功能，单个文件过大将输出至新文件中且备份旧日志
    @frozen
    struct Log: Hashable, Sendable, CustomStringConvertible, Loggerable {
        /// 日志文件要存的目录，提供 Rotating 功能，单个文件过大将输出至新文件中且备份旧日志
        /// 日志在该目录中如何分流取决于依赖的模块
        public let directory: URL
        
        /// 初始化日志配置，仅在 ``Whooshing.Env`` 为 `.independentDebug(...)` 时才可能使用
        /// 这些参数在非 `.independentDebug(...)` 模式下会自动从环境变量中读取
        @inlinable
        public init(
            directory: URL
        ) {
            self.directory = directory
        }
        
        @inlinable
        public var json: [String: AnyCodable] {[
            "directory": AnyCodable(directory)
        ]}
        
        @inlinable
        public var description: String {
            formatJson(json)
        }
    }
    
    /// 一个数据库服务连接的配置项，仅支持 PostgreSQL 数据库，一个数据库服务中可有多个数据库
    @frozen
    struct DBService: Hashable, Sendable, CustomStringConvertible, Loggerable {
        /// 数据库名称
        public let id: DatabaseID
        /// 用于连接数据库的主机名
        public let host: String
        /// 数据库监听端口号
        public let port: Int
        /// 该数据库服务中的所有数据库名称
        public let dbs: [DB]
        
        /// 永远不应直接调用该初始化函数
        @inlinable
        public init() { self = Self(name: "postgres") }
        
        /// 初始化数据库配置，仅在 ``Whooshing.Env`` 为 `.independentDebug(...)` 时才可能使用
        /// 这些参数在非 `.independentDebug(...)` 模式下会自动从环境变量中读取
        /// - Parameters:
        ///   - name: 数据库服务的名称
        ///   - host: 该数据库服务所在的主机
        ///   - databases: 该数据库服务中的所有数据库列表
        ///   - port: 监听端口
        ///   - dbParameters: 该数据库服务中的数据库的配置列表
        @inlinable
        public init(
            name: String,
            host: String = "localhost",
            port: Int = 5432,
            dbParameters: [DB.Parameter] = []
        ) {
            let id = DatabaseID(string: name)
            self.id = id
            self.host = host
            self.port = port
            self.dbs = dbParameters.map { parameter in
                DB(dbServiceId: id, port: port, parameter: parameter)
            }
        }
        
        @inlinable
        public var json: [String: AnyCodable] {[
            "id": AnyCodable(id),
            "port": AnyCodable(port),
            "dbs": AnyCodable(dbs.map { $0.json })
        ]}
        
        @inlinable
        public var description: String {
            formatJson(json)
        }
    }
    
    /// 一个数据库的配置项，仅支持 PostgreSQL 数据库
    @frozen
    struct DB: Hashable, Sendable, CustomStringConvertible, Loggerable {
        /// 该数据库所属数据库服务的 id
        public let dbServiceId: DatabaseID
        /// 用于 Fluent 识别的数据库标识符
        public let id: DatabaseID
        /// 用于连接数据库的主机名
        public let host: String
        /// 数据库监听端口号
        public let port: Int
        /// 该数据库的参数配置
        public let parameter: Parameter
        
        @frozen
        public struct Parameter: Hashable, Sendable, CustomStringConvertible, Loggerable {
            /// 该数据库的名称
            public let name: String
            /// 用于连接数据库的用户名
            public let user: String
            /// 文件存储系统的加密密钥，为 nil 表示不支持文件加密系统
            public let fileStorageKey: SendableSymmKey?
            /// 数据库访问密码（内部使用）
            /// 内部存储，不允许外界访问
            internal let password: String
            
            /// 初始化数据库配置，仅在 ``Whooshing.Env`` 为 `.independentDebug(...)` 时才可能使用
            /// 这些参数在非 `.independentDebug(...)` 模式下会自动从环境变量中读取
            /// - Parameters:
            ///   - name: 数据库服务的名称
            ///   - user: 连接用户名
            ///   - password: 连接密码
            ///   - testingHost: 用于连接数据库的主机名，只有测试时会使用。PostgreSQL 生产环境仅允许运行在本地
            ///   - fileStorageKey: 文件存储系统的加密密钥，为 nil 表示不支持文件加密系统
            public init(
                name: String,
                user: String = "postgres",
                password: String = "password",
                fileStorageKey: SendableSymmKey? = nil
            ) {
                self.name = name
                self.user = user
                self.password = password
                self.fileStorageKey = fileStorageKey
            }
            
            @inlinable
            public var json: [String: AnyCodable] {[
                "name": AnyCodable(name),
                "user": AnyCodable(user)
            ]}
            
            @inlinable
            public var description: String {
                formatJson(json)
            }
        }
        
        @usableFromInline
        internal init(
            dbServiceId: DatabaseID,
            host: String = "localhost",
            port: Int = 5432,
            parameter: Parameter
        ) {
            self.dbServiceId = dbServiceId
            self.id = DatabaseID(string: "\(dbServiceId.string)/\(parameter.name)")
            self.host = host
            self.port = port
            self.parameter = parameter
        }
        
        /// 返回当前数据库的实际连接配置对象
        /// 仅仅在测试时使用
        public var testingConfig: SQLPostgresConfiguration {

            let host: String
            
            // 如果用于测试的 db 服务在本机，则 Github CI 由于 docker 的部署问题，host 需要指定为 docker 网络域名
            // 如果该服务在远端，则无需修改
            if self.host != "localhost" {
                host = self.host
            } else {
                host = ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
            }
            
            return .init(
                hostname: host,
                port: port,
                username: parameter.user,
                password: parameter.password,
                database: parameter.name,
                tls: .disable
            )
        }
        
        public var config: SQLPostgresConfiguration {
            .init(
                hostname: host,
                port: port,
                username: parameter.user,
                password: parameter.password,
                database: parameter.name,
                tls: .disable
            )
        }
        
        @inlinable
        public var json: [String: AnyCodable] {[
            "db_service_id": AnyCodable(dbServiceId.string),
            "db_fluent_id": AnyCodable(id.string),
            "host": AnyCodable(host),
            "port": AnyCodable(port),
            "parameter": AnyCodable(parameter.json)
        ]}
        
        @inlinable
        public var description: String {
            formatJson(json)
        }
    }
}

public extension Environment {
    protocol DriverKey: StorageKey, Sendable {
        static var label: String { get }
        static var valueType: Environment.Types { get }
        static func loggerStrategies(for directory: URL) -> [LoggerStrategy]
        static func apply(on storage: Storage, value: Any?) -> Storage
    }
}

extension Environment.DriverKey {
    @inlinable
    public static func apply(on storage: Storage, value: Any?) -> Storage {
        var new = storage
        guard let v = value as? Value else {
            fatalError("\(self.label) 环境变量值解析失败")
        }
        new[self] = v
        return new
    }
}

public extension String {
    /// 将任意字符串转换为规范的小写蛇形命名法（snake_case）
    /// - Parameter string: 待转换的不规范字符串
    /// - Returns: 规整后的标准 snake_case 字符串
    @inlinable
    var snakeCase: String {
        guard !self.isEmpty else { return "" }
        
        var result = ""
        result.reserveCapacity(self.utf8.count) // 🚀 性能优化：提前分配内存，避免数组频繁扩容
        
        var lastWasUnderscore = false
        
        for char in self {
            // 如果是字母或数字，保留并转为小写
            if char.isLetter || char.isNumber {
                result.append(char.lowercased())
                lastWasUnderscore = false
            } else {
                // 如果是特殊字符、空格或标点符号，统一准备替换为下划线
                // 如果前一个字符已经是下划线了，这里就跳过，防止出现连续的多个 "___"
                if !result.isEmpty && !lastWasUnderscore {
                    result.append("_")
                    lastWasUnderscore = true
                }
            }
        }
        
        // 如果字符串末尾正好是一个因特殊字符转换而来的下划线，直接把它切掉
        if result.hasSuffix("_") {
            result.removeLast()
        }
        
        return result
    }
}

public extension URL {
    static var homeDirectoryURL: URL {
        #if os(iOS)
        // iOS / iOS 模拟器环境：使用沙盒内的 Caches 或者是 Documents 目录
        // 对于日志文件，推荐放在 Caches 目录下，防止被 iCloud 自动备份浪费空间
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        #else
        // macOS / Linux 服务器环境：大方使用用户主目录
        return FileManager.default.homeDirectoryForCurrentUser
        #endif
    }

}
