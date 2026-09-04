import Cryptos
import Foundation
import VaporTube
import Vapor
import Logging
import LoggingAdvanced

struct ServiceBootstrap {
    static let moduleId = UUID("F02F2803-BF88-4B51-A743-B3AA0F3FF804")!
    
    static func run(nexus: Nexus<VaporTube>) async throws {
        do {
            try await nexus.execute()
        } catch {
            try await nexus.asyncShutdown()
            throw error
        }
    }
}
