# Whooshing Vapor 传输层

本项目为 [Whooshing](https://github.com/whooshing-workshop/whooshing) 系统的 **Vapor 传输层（Tube）**，是 [whooshing.nexus](https://github.com/whooshing-workshop/whooshing.nexus) 中 `Tube` 协议基于 [Vapor](https://vapor.codes/) 的实现。它把 Nexus 解析出的模块配置落实为一个可运行的 Vapor `Application`：绑定监听地址、按配置注册 PostgreSQL 数据库、注入配置中间件、装配服务间来源校验，并统一路由末端的错误转译。

所有 Whooshing 服务模块模版（如 [whooshing.template-basic](https://github.com/whooshing-workshop/whooshing.template-basic)、[whooshing.template-privilege-module](https://github.com/whooshing-workshop/whooshing.template-privilege-module)）均以本库作为启动入口。

### 特性

- **一步构建 Vapor 应用**：`VaporTube.make(paras)` 根据 `Bootstrap.Paras` 完成 `Application` 创建、hostname / port 绑定与生命周期封装（`execute` / `asyncShutdown` / `executeWithAsyncShutdown`）。
- **数据库自动注册**：遍历配置中的所有 `Environment.DBService`，以 `数据库服务名/数据库名` 为 `DatabaseID` 注册 Fluent PostgreSQL 连接；测试环境自动切换到 `testingConfig` 并开启 SQL debug 日志。
- **配置注入**：`ConfigInjector` 中间件把模块配置挂载到每个请求上，路由内可直接使用 `req.config`；`app.nexus` 可取得当前的 `AnyNexus`。
- **服务间来源校验**：`ServiceValidator` 中间件校验请求头 `X-Module-ID`，本地缓存未命中时向 Manager 询问，`RoutesBuilder.inlineProtectGrouped()` 一行即可开启受保护的 `/inline` 路由组。
- **统一错误处理**：自动挂载 `RouteEndErrorHandler`，`ErrorHandle` 体系中的错误会按类别转译为合适的 HTTP 状态码。
- **Content 扩展**：为 `Data`、`SendableSymmKey` 及各类非对称密钥类型补充 `Content` 实现，可直接作为请求体 / 响应体编解码。
- **JSON 日期策略**：全局 JSON 解码器统一使用 ISO 8601 日期格式。

----------

### 导入该依赖库

在你的 `Package.swift` 加入：

``` swift
.package(url: "https://github.com/whooshing-workshop/whooshing.tube-vapor.git", from: "1.0.0")
```

在依赖模块中引入:

```swift
.product(name: "VaporTube", package: "whooshing.tube-vapor")
```

在需要的地方:

```swift
import VaporTube
```

> `VaporTube` 已通过 `@_exported` 重新导出了 `Nexus`、`Vapor`、`AnyCodable`、`Cryptos` 与 `LoggingAdvanced`，导入 `VaporTube` 后无需再单独导入这些模块。

--------

### 使用介绍

#### 1. 启动一个服务模块

``` swift
import VaporTube

// 1. 选择运行模式并执行 Bootstrap（详见 whooshing.nexus）
let config = Environment.Config(
    id: UUID(),
    name: "my-module",
    port: 6500
)
let paras = try await Bootstrap.run(
    .detect(config),          // 根据 --env 自动识别；有调试配置时 development 即为独立调试模式
    driverKeys: [],           // 需要注入的驱动
    logger: Logger(label: "app")
).get()

// 2. 启动日志系统（Bootstrap 只负责装配，不会自动 bootstrap）
paras.loggingFactory
    .append(strategies: [.init(label: "console", level: .trace)])
    .bootstrap()

// 3. 构建 VaporTube 与 Nexus
let tube = try await VaporTube.make(paras).get()
let nexus = Nexus(tube: tube, bootstrap: paras)

// 4. 像普通 Vapor 项目一样注册路由
nexus.tube.app.get("hello") { req async -> String in
    "Hello, world!"
}

// 5. 运行（阻塞直至关闭，并在退出时自动执行 asyncShutdown）
try await nexus.executeWithAsyncShutdown()
```

在 `static let` 等同步上下文中初始化时，可借助 Nexus 提供的 `asyncToSync`：

``` swift
static let nexus: Nexus<VaporTube> = {
    try! asyncToSync {
        let tube = try await VaporTube.make(bootstrap).get()
        return Nexus(tube: tube, bootstrap: bootstrap)
    }
}()
```

#### 2. 在路由中读取配置

``` swift
app.get("whoami") { req async -> String in
    // ConfigInjector 已把 Environment.Config 注入到 request.storage 中
    let config = req.config
    return "\(config.name)@\(config.hostname):\(config.port)"
}

// 也可以从 Application 取得 AnyNexus
let moduleId = app.nexus.config.id
```

数据库使用 Fluent 的标准方式，`DatabaseID` 为 `数据库服务名/数据库名`：

``` swift
let dbId = DatabaseID(string: "default/postgres")
app.migrations.add(User.MIG(), to: dbId)

app.get("users") { req async throws -> [User] in
    try await User.query(on: req.db(dbId)).all()
}
```

#### 3. 服务间通讯路由（INLINE）

Whooshing 系统中，模块之间的调用必须携带请求头 `X-Module-ID`。`ServiceValidator` 会：

1. 拒绝与本模块 ID 相同的来源；
2. 命中本地缓存则直接放行；
3. 未命中则向 Manager 询问 `GET <MANAGER_URL>/modules/<MODULE_ID>/verify`，通过后加入缓存。

``` swift
// 创建受保护的 /inline 路由组
let inline = app.inlineProtectGrouped()

inline.get("ping") { req async throws -> String in
    // 通过校验后，来源模块 ID 会以 ServiceValidator.Identifier 登录到 req.auth
    let source = try req.auth.require(ServiceValidator.Identifier.self)
    return source.incomingId.uuidString
}
```

独立调试时没有真实的 Manager，可以用 Nexus 提供的 `DebugingModuleController` 在本模块内模拟这两个 API，并把 `managerUrl` 指向自己：

``` swift
if isIndependentDebug {
    try app.register(collection: DebugingModuleController(serviceIds: allowedServiceIds))
}
```

#### 4. 错误处理

`VaporTube.make` 会在所有用户配置完成后追加 `RouteEndErrorHandler`。路由中抛出的 `ErrorHandle` 错误会依据 `ErrCategory` 被转译：

``` swift
enum MyErrcase: String, ErrList, Sendable {
    case notFound = "资源不存在"
}

app.get("item", ":id") { req async throws -> String in
    // .external 会成为 4xx 响应（默认 400，可用 userdata 指定状态码），suggestions 会附加在 reason 中
    throw MyErrcase.notFound.d(
        "未找到 id 对应的资源",
        category: .external(suggestions: ["请检查 id 是否正确"], userdata: .init(HTTPResponseStatus.notFound))
    )
    // .internal / .inherit 则会成为 500，并向客户端隐藏内部细节
}
```

-------

### 运行环境

* **macOS** (> 13.0)
* **iOS** (> 16.0)
* **Linux** (> 20)
* **Swift** (> 6.0)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS** (> 13) **[未测试]**

-------

### 注意事项

- `VaporTube.make` 的配置阶段一旦抛错，会自动执行 `asyncShutdown()` 释放 Vapor 资源后再向外抛出 `Errcase.serviceInitFailed`。
- 数据库连接池按 `maxConnectionsPerEventLoop: 1`、`connectionPoolTimeout: 10s` 配置；生产环境 SQL 日志级别为 `.info`，测试环境为 `.debug`。
- `ServiceValidator` 依赖 `Environment.Config.managerUrl`，请确保生产环境中该地址可达，否则所有 `/inline` 请求将因来源校验失败而被拒绝。
- 单元测试（`Tests/tube-vapor-Tests`）会真实启动一个 Vapor 服务（监听 6501 端口）并进行文件流、WebSocket 等回环测试，运行前请确保 `testing_files` 目录可写。

如需了解更多，请参阅模块内的源码注释与文档说明。

------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/whooshing-workshop/whooshing.tube-vapor/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
