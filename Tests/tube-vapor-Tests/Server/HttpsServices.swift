import Vapor
import NIOFileSystem
import VaporTube
import Cryptos

struct FilePreparePaths: Content {
    let small: String
    let large: String
    let smallSize: Int
    let largeSize: Int
    let smallChunk: Int
    let largeChunk: Int
}

struct FilePrepareRes: Content {
    let smallPath: String
    let largetPath: String
}

struct HttpsService {
    static func bootstrap() async throws -> Bootstrap.Paras {
        let testPara = Environment.Config(
            id: ServiceBootstrap.moduleId,
            name: "testing-module",
            port: TestingShared.httpsListenPort
        )
        
        var logger = Logger(label: "server.https")
        logger.logLevel = TestingShared.logLevel
        return try await Bootstrap.run(.independentDebug(testPara), logger: logger).get()
    }
    
    static func makeService(paras: Bootstrap.Paras) async throws -> VaporTube {
        let woo = try await VaporTube.make(paras).get()
        try routes(woo, app: woo.app)
        return woo
    }
        
    static func routes(_ woo: VaporTube, app: Application) throws {
        struct Query: Content {
            let value: String
        }

        app.get("string-echo") { req in
            let str = try req.query.decode(Query.self).value
            return str
        }
        
        app.post("file-prepare") { req in
            let filePaths = try req.content.decode(FilePreparePaths.self)
            
            let sp = try await TestFileGenerator.generateDummyFile(
                at: filePaths.small,
                chunkSize: filePaths.smallChunk,
                totalSize: filePaths.smallSize,
                on: req.eventLoop
            )
            
            let lp = try await TestFileGenerator.generateDummyFile(
                at: filePaths.large,
                chunkSize: filePaths.largeChunk,
                totalSize: filePaths.largeSize,
                on: req.eventLoop
            )
            
            return FilePrepareRes(smallPath: sp, largetPath: lp)
        }

        for method in [HTTPMethod.POST, .PATCH, .PUT, .DELETE] {
            app.on(method, "string-echo") { req in
                let str = try req.content.decode(String.self)
                return str
            }
        }

        for method in [HTTPMethod.GET, .POST, .PATCH, .PUT, .DELETE] {
            app.on(method, "no-body") { req in
                return "NO-BODY"
            }
        }

        for method in [HTTPMethod.POST, .PATCH, .PUT] {
            app.on(method, "streaming-echo", body: .stream) { req in
                let response = Response(status: .ok)
                response.body = .init(asyncStream: { writer in
                    do {
                        for try await chunk in req.body {
                            try await writer.write(.buffer(chunk))
                        }
                        try await writer.write(.end)
                    } catch {
                        try await writer.write(.end)
                        throw error
                    }
                })
                return response 
            }
        }

        for method in [HTTPMethod.POST, .PATCH, .PUT] {
            app.on(method, "file-echo", body: .stream) { req in
                guard 
                    let fileName = req.headers.first(name: .contentDisposition)
                else { 
                    throw Abort(.badRequest) 
                }
                let response = Response(status: .ok)
                response.body = .init(asyncStream: { writer in
                    do {
                        for try await chunk in req.body {
                            try await writer.write(.buffer(chunk))
                        }
                        try await writer.write(.end)
                    } catch {
                        try await writer.write(.end)
                        throw error
                    }
                })
                response.headers.replaceOrAdd(name: .contentDisposition, value: fileName)
                return response 
            }
        }

        for (suffix, size) in [
            ("normal", 16384),
            ("largest", Int(UInt32.max))
        ] {
            app.webSocket("websocket-echo-\(suffix)", maxFrameSize: .init(integerLiteral: size)) { req, ws in
                ws.onBinary { ws, data in
                    ws.send(data)
                }
                ws.onClose.whenComplete { result in
                    switch result {
                    case .success:
                        ws.close(promise: nil)
                        print("WebSocket 正常关闭")
                    case .failure(let error):
                        ws.close(promise: nil)
                        print("WebSocket 错误关闭: \(error)")
                    }
                }
            }
        }
    }
}
