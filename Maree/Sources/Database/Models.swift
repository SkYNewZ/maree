import Foundation
import GRDB

enum SpeciesStatus: String, Codable, DatabaseValueConvertible {
    case published, inProgress, proposed
}

/// Section kinds, mirroring the keys of tools/lib/sections.mjs. The order of
/// `allCases` is the display order on the species screen, and lives only here —
/// the pipeline stores a kind per section and has no say in how they are shown.
enum SectionKind: String, Codable, CaseIterable, DatabaseValueConvertible {
    case identification, distribution, biotope, description
    case feeding, reproduction, biologyMisc, associatedLife
    case additionalInfo, regulation
    case frenchNameOrigin, scientificNameOrigin, invalidSynonyms, similarSpecies

    var title: String {
        switch self {
        case .identification: "Critères de reconnaissance"
        case .distribution: "Distribution"
        case .biotope: "Biotope"
        case .description: "Description"
        case .feeding: "Alimentation"
        case .reproduction: "Reproduction"
        case .biologyMisc: "Divers biologie"
        case .associatedLife: "Vie associée"
        case .additionalInfo: "Informations complémentaires"
        case .regulation: "Réglementation"
        case .frenchNameOrigin: "Origine du nom français"
        case .scientificNameOrigin: "Origine du nom scientifique"
        case .invalidSynonyms: "Autres noms scientifiques"
        case .similarSpecies: "Espèces ressemblantes"
        }
    }
}

struct Species: Codable, FetchableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "species"
    var id: Int
    var commonName: String
    var scientificName: String
    var groupId: Int
    var status: SpeciesStatus
    var regulated: Bool
    var dangerous: Bool
    var photoCount: Int
    var depthMin: Int?
    var depthMax: Int?
    var tempMin: Int?
    var tempMax: Int?
    var updatedAt: String?
    var sourceUrl: String

    /// 4 species (all diatoms) ship with a blank commonName; the scientific name is
    /// the only identity they have. `isEmpty` rather than a trim: those 4 store an
    /// empty string, and no row in the column has surrounding whitespace.
    var displayName: String { commonName.isEmpty ? scientificName : commonName }

    var depthRange: ClosedRange<Int>? {
        guard let depthMin, let depthMax else { return nil }
        return depthMin...depthMax
    }

    var temperatureRange: ClosedRange<Int>? {
        guard let tempMin, let tempMax else { return nil }
        return tempMin...tempMax
    }
}

struct Section: Codable, FetchableRecord, TableRecord, Hashable {
    static let databaseTableName = "section"
    var speciesId: Int
    var kind: SectionKind
    var text: String
}

struct Photo: Codable, FetchableRecord, TableRecord, Hashable, Identifiable {
    static let databaseTableName = "photo"
    var speciesId: Int
    var position: Int
    var caption: String?

    /// Identity within one species' gallery, for `ForEach`. The table's primary key
    /// is composite (speciesId, position), so never use GRDB's id-based requests
    /// (`Photo.fetchOne(db, id:)` and friends) — they trap on a composite key.
    var id: Int { position }
}

struct TaxonGroup: Codable, FetchableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "taxonGroup"
    var id: Int
    var parentId: Int?
    var name: String
    var scientificHint: String?
    var speciesCount: Int
}

struct Zone: Codable, FetchableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "zone"
    var id: Int
    var parentId: Int?
    var name: String
}

struct TaxonRank: Codable, FetchableRecord, TableRecord, Hashable {
    static let databaseTableName = "taxonRank"
    var speciesId: Int
    var position: Int
    var rank: String
    var name: String
}

struct SpeciesDetail {
    var species: Species
    var group: TaxonGroup
    var sections: [Section]
    var photos: [Photo]
    var frenchNames: [String]
    var otherNames: [String]
    var ranks: [TaxonRank]
    var zones: [Zone]

    func section(_ kind: SectionKind) -> String? {
        sections.first { $0.kind == kind }?.text
    }
}
