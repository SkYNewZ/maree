import Testing
import GRDB
import SwiftUI
@testable import Maree

@Suite("Contrat de la base embarquée")
struct DatabaseContractTests {
    let database = try! AppDatabase()

    @Test("la base contient le sous-ensemble européen attendu")
    func speciesCount() throws {
        // fetchAll, not fetchCount: decoding every row also proves every column
        // decodes without throwing, which a count would never touch.
        let species = try database.reader.read { db in
            try Species.fetchAll(db)
        }
        #expect(species.count == 2837)
    }

    @Test("aucun markup DORIS résiduel dans les textes affichés")
    func noResidualMarkup() throws {
        let dirty = try database.reader.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM (
                  SELECT text AS t FROM section
                  UNION ALL SELECT commonName FROM species
                  UNION ALL SELECT scientificName FROM species
                ) WHERE t LIKE '%{{%'
                """) ?? -1
        }
        #expect(dirty == 0)
    }

    @Test("chaque enum SectionKind existe dans la base")
    func sectionKindsAreKnown() throws {
        let kinds = try database.reader.read { db in
            try String.fetchSet(db, sql: "SELECT DISTINCT kind FROM section")
        }
        let declared = Set(SectionKind.allCases.map(\.rawValue))
        #expect(kinds.subtracting(declared).isEmpty, "clés inconnues du code Swift : \(kinds.subtracting(declared))")
        #expect(declared.subtracting(kinds).isEmpty, "clés Swift absentes de la base : \(declared.subtracting(kinds))")
    }

    @Test("l'instance partagée ouvre la base embarquée")
    func sharedDatabaseOpens() throws {
        let count = try AppDatabase.shared.reader.read { db in
            try Species.fetchCount(db)
        }
        #expect(count == 2837)
    }

    @Test("chaque lecture de l'environnement partage la même connexion")
    func environmentReadsShareOneConnection() {
        // `@Entry` defaults are computed, so a non-stored default would open a new
        // DatabaseQueue on every read — one file descriptor per row of a List.
        let readers = (0..<3).map { _ in EnvironmentValues().repository.reader }
        #expect(readers.allSatisfy { $0 === readers[0] })
        #expect(readers[0] === AppDatabase.shared.reader)
    }

    @Test("la date de la base DORIS est renseignée")
    func metaIsPresent() throws {
        let repository = SpeciesRepository(reader: database.reader)
        #expect(try repository.meta("dorisDate") != nil)
    }
}
