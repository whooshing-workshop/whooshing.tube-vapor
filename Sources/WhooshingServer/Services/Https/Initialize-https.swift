import Vapor

/// 对于 HTTPS 模块无需进行其他配置，使用默认的 HTTPS 加密即可
/// 这需要外部设置证书和 Nginx 反向代理，但在这里无需多余配置

public enum Https {
    
    public static var name: String { "https" }
    public static var envPrefix: String { "WHOOSHING_\(name.uppercased())_SERVICE" }
    
    @frozen
    public struct Debuging: DebugConfig, Sendable {
        /// 服务配置，原来通过 Whooshing 系统环境变量自动获取
        ///
        /// 指定诸如监听地址，PostgreSQL 数据库的连线参数，等等
        /// 见 ``Environment.Config``
        public let config: Environment.Config
        
        /// 提供参数初始化 Https 依赖参数
        ///
        /// - Parameters:
        ///   - config: 服务配置
        /// - Returns:
        ///   初始化的 Https 依赖参数
        @inlinable
        public init(config: Environment.Config) {
            self.config = config
        }
    }
    
    @usableFromInline
    internal static func config(_ woo: Whooshing) async throws(Errcase.ErrType) {}
}
