import Nexus

public struct AnyNexusKey: StorageKey {
    public typealias Value = AnyNexus
}

public extension Application {
    var nexus: AnyNexus { self.storage[AnyNexusKey.self]! }
}
