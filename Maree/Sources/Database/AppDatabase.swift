import Foundation
import GRDB

/// Not named `DatabaseError`: GRDB already exports a public `DatabaseError`, and a
/// module-local type of that name would win unqualified lookup everywhere, so a
/// `catch let error as DatabaseError` meant for a SQLite failure would compile and
/// never match.
enum AppDatabaseError: LocalizedError {
    case bundledDatabaseMissing

    var errorDescription: String? {
        switch self {
        case .bundledDatabaseMissing:
            "La base de données de l'application est introuvable."
        }
    }

    var failureReason: String? {
        switch self {
        case .bundledDatabaseMissing:
            "Le fichier maree.db n'a pas été inclus dans l'application. Exécutez « node tools/prepare-db.mjs » puis recompilez."
        }
    }
}

/// Read-only access to the bundled species database. The file ships inside the
/// app bundle and is never written to, so a single reader is enough.
struct AppDatabase {
    /// The one connection the app uses. `@Entry` environment defaults are computed,
    /// so they re-evaluate on every read — without this stored `static let` each
    /// `@Environment(\.repository)` read would open another queue on the 20 MB file.
    static let shared = makeShared()

    let reader: DatabaseReader

    init() throws {
        guard let path = Bundle.main.path(forResource: "maree", ofType: "db") else {
            throw AppDatabaseError.bundledDatabaseMissing
        }
        var configuration = Configuration()
        configuration.readonly = true
        reader = try DatabaseQueue(path: path, configuration: configuration)
    }

    /// The app cannot function without its database, and a missing bundled file
    /// is a packaging mistake rather than a runtime condition — so this traps
    /// instead of propagating. Use `init()` where the failure is recoverable.
    static func makeShared() -> AppDatabase {
        do {
            return try AppDatabase()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
