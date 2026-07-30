import Foundation
import GRDB
import SwiftUI

/// `nonisolated` against the module's MainActor default: these are synchronous
/// SQLite reads on a connection GRDB already serialises, and the widest of them
/// walks 20 048 rows. Pinned to the main actor they could only ever block it.
nonisolated struct SpeciesRepository {
    let reader: DatabaseReader

    // MARK: - Search

    /// Full-text search over common, scientific and vernacular names.
    ///
    /// FTS5 has its own query syntax, so raw user input is tokenised by GRDB
    /// instead of being interpolated — otherwise a stray quote or `*` would
    /// raise a syntax error. Input holding no token at all (blank, or pure
    /// punctuation) yields no pattern, and therefore no results rather than
    /// every species.
    func search(_ text: String, limit: Int = 100) throws -> [Species] {
        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: text) else { return [] }
        return try reader.read { db in
            try Species.fetchAll(db, sql: """
                SELECT species.* FROM species
                JOIN speciesSearch ON speciesSearch.speciesId = species.id
                    AND speciesSearch MATCH ?
                ORDER BY speciesSearch.rank
                LIMIT ?
                """, arguments: [pattern, limit])
        }
    }

    // MARK: - Browsing

    func rootGroups() throws -> [TaxonGroup] {
        try reader.read { db in
            try TaxonGroup.fetchAll(db, sql: """
                SELECT * FROM taxonGroup WHERE parentId IS NULL ORDER BY name
                """)
        }
    }

    func childGroups(of groupId: Int) throws -> [TaxonGroup] {
        try reader.read { db in
            try TaxonGroup.fetchAll(db, sql: """
                SELECT * FROM taxonGroup WHERE parentId = ? ORDER BY name
                """, arguments: [groupId])
        }
    }

    /// Species of a group, including every descendant group.
    func species(inGroup groupId: Int) throws -> [Species] {
        try reader.read { db in
            try Species.fetchAll(db, sql: """
                WITH RECURSIVE subtree(id) AS (
                  SELECT ?
                  UNION ALL
                  SELECT g.id FROM taxonGroup g JOIN subtree s ON g.parentId = s.id
                )
                SELECT * FROM species WHERE groupId IN (SELECT id FROM subtree)
                ORDER BY commonName
                """, arguments: [groupId])
        }
    }

    func zones() throws -> [Zone] {
        try reader.read { db in
            try Zone.fetchAll(db, sql: "SELECT * FROM zone ORDER BY parentId IS NOT NULL, name")
        }
    }

    func species(inZone zoneId: Int) throws -> [Species] {
        try reader.read { db in
            try Species.fetchAll(db, sql: """
                SELECT species.* FROM species
                JOIN speciesZone ON speciesZone.speciesId = species.id
                WHERE speciesZone.zoneId = ?
                ORDER BY species.commonName
                """, arguments: [zoneId])
        }
    }

    /// Fetches species by id, preserving the order of `ids` (used by favourites,
    /// which are ordered by when they were added).
    func species(ids: [Int]) throws -> [Species] {
        guard !ids.isEmpty else { return [] }
        let found = try reader.read { db in
            try Species.fetchAll(db, sql: """
                SELECT * FROM species WHERE id IN (\(databaseQuestionMarks(count: ids.count)))
                """, arguments: StatementArguments(ids))
        }
        let byId = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
        return ids.compactMap { byId[$0] }
    }

    // MARK: - Detail

    func detail(id: Int) throws -> SpeciesDetail? {
        try reader.read { db in
            guard let species = try Species.fetchOne(db, sql: "SELECT * FROM species WHERE id = ?", arguments: [id]),
                  let group = try TaxonGroup.fetchOne(db, sql: "SELECT * FROM taxonGroup WHERE id = ?",
                                                      arguments: [species.groupId])
            else { return nil }

            // `SectionKind.allCases` is the display order, so walking it is both
            // the sort and the filter — a species has at most one of each kind.
            let fetched = try Section.fetchAll(
                db, sql: "SELECT * FROM section WHERE speciesId = ?", arguments: [id])
            let sections = SectionKind.allCases.compactMap { kind in
                fetched.first { $0.kind == kind }
            }

            let photos = try Photo.fetchAll(db, sql: """
                SELECT * FROM photo WHERE speciesId = ? ORDER BY position
                """, arguments: [id])

            let names = try Row.fetchAll(db, sql: """
                SELECT name, isFrench FROM vernacularName WHERE speciesId = ? ORDER BY name
                """, arguments: [id])

            let ranks = try TaxonRank.fetchAll(db, sql: """
                SELECT * FROM taxonRank WHERE speciesId = ? ORDER BY position
                """, arguments: [id])

            let zones = try Zone.fetchAll(db, sql: """
                SELECT zone.* FROM zone
                JOIN speciesZone ON speciesZone.zoneId = zone.id
                WHERE speciesZone.speciesId = ? ORDER BY zone.name
                """, arguments: [id])

            return SpeciesDetail(
                species: species,
                group: group,
                sections: sections,
                photos: photos,
                frenchNames: names.filter { $0["isFrench"] }.map { $0["name"] },
                otherNames: names.filter { !($0["isFrench"] as Bool) }.map { $0["name"] },
                ranks: ranks,
                zones: zones
            )
        }
    }

    /// Ids of every species that has a thumbnail to download. Today all 2 837 rows
    /// carry photos, but a species without any has no `0_maree.heic` in the bucket.
    func allSpeciesIds() throws -> [Int] {
        try reader.read { db in
            try Int.fetchAll(db, sql: "SELECT id FROM species WHERE photoCount > 0 ORDER BY id")
        }
    }

    func meta(_ key: String) throws -> String? {
        try reader.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [key])
        }
    }
}

extension EnvironmentValues {
    @Entry var repository = SpeciesRepository(reader: AppDatabase.shared.reader)
}
