import Foundation

enum Route: Hashable {
    case species(Int)
    case group(TaxonGroup)
    case groupSpecies(TaxonGroup)
    case zone(Zone)
    /// Carries the photos rather than an id: the fiche has just fetched them, and
    /// re-running the 7-part detail query to read one field of it is the only thing
    /// the gallery would use an id for.
    case gallery(photos: [Photo], position: Int)
}
