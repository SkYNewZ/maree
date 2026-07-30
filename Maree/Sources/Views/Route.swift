import Foundation

enum Route: Hashable {
    case species(Int)
    case group(TaxonGroup)
    case groupSpecies(TaxonGroup)
    case zone(Zone)
    case gallery(speciesId: Int, position: Int)
}
