import Nexus

public struct AnyNexusKey: StorageKey {
    public typealias Value = AnyNexus
}

public extension Application {
    var nexus: AnyNexus { self.storage[AnyNexusKey.self]! }
}

public extension RoutesBuilder {
    func inlineProtectGrouped() -> RoutesBuilder {
        self.grouped("inline").grouped(
            ServiceValidator(),
            ServiceValidator.Identifier.guardMiddleware()
        )
    }
}
