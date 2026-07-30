import Foundation

/// A UserDefaults suite of its own, emptied before use.
///
/// `defaults.description` is the object's debug description (e.g.
/// `<UserDefaults: 0x...>`), never the suite name — passing it to
/// `removePersistentDomain(forName:)` clears nothing. Each caller still gets its
/// own UUID-named suite, so tests don't leak into each other even with that bug,
/// but the domain then lingers on disk forever. Naming the suite once and reusing
/// the name here actually clears it.
func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
