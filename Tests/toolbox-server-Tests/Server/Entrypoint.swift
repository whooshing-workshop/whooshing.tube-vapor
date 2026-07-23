import Vapor
import VaporTube
import Cryptos
import Testing
import LoggingAdvanced

enum Entrypoint {
    nonisolated(unsafe) static var httpsApp: Whooshing!
    
    private enum WatchdogResult: Sendable {
        case shouldStop
    }

    static func runServices(
        shouldStop: @escaping @Sendable () async -> Bool,
        onReady: @escaping @Sendable () async -> Void
    ) async throws {
        let httpsBootstrapPara = try await HttpsService.bootstrap()
        
        LoggingFactory(factories: [
            httpsBootstrapPara.loggingFactory
        ]).append(strategies: [
            .init(label: "console", level: .trace)
        ]).bootstrap()
        
        httpsApp = try await HttpsService.makeService(paras: httpsBootstrapPara)
        
        try await withThrowingTaskGroup(of: WatchdogResult?.self) { group in
            
            group.addTask {
                try await ServiceBootstrap.run(woo: httpsApp)
                return nil
            }
            
            // 2. 💡 核心魔法：启动一个“就绪监测任务”
            // 假设你的这些服务类里可以拿到对应的 Vapor Application 实例
            group.addTask {
                while !isTCPPortOpen(TestingShared.httpsListenPort) {
                    try await Task.sleep(nanoseconds: 250_000_000)
                }
                
                print("🚀 所有服务确认启动就绪！触发外部访问回调...")
                await onReady()
                return nil
            }
            
            // 3. 启动看门狗轮询终止信号
            group.addTask {
                while true {
                    if await shouldStop() {
                        print("看门狗检查到终止信号（shouldStop == true），通知外层控制中心...")
                        return .shouldStop
                    }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            
            // 4. 监听所有子任务的状态
            while let result = try await group.next() {
                if case .shouldStop = result {
                    print("外层控制中心收到信号，正在安全取消所有服务...")
                    group.cancelAll()
                    try! await httpsApp.asyncShutdown().get()
                    break
                }
            }
        }
        
        print("所有服务已安全终止，函数正常返回。")
    }
}
