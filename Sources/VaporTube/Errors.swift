import ErrorHandle

public extension VaporTube {
    @frozen
    enum Errcase: String, ErrList, Sendable {
        case vaporAppCreateFailed = "Vapor App 创建失败"
        case serviceInitFailed = "服务初始化配置失败"
        case executionFailed = "运行时出错，错误未被处理"
        case shutdownFailed = "关闭服务时出错"
        case serviceValidateFailed = "来源服务验证失败"
    }
}
