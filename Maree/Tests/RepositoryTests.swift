import Testing
import GRDB
@testable import Maree

@Suite("Requêtes")
struct RepositoryTests {
    let repository = SpeciesRepository(reader: try! AppDatabase().reader)

    @Test("la recherche ignore les accents")
    func searchIgnoresDiacritics() throws {
        let results = try repository.search("elephant")
        #expect(!results.isEmpty)
        #expect(results.contains { $0.commonName.lowercased().contains("éléphant") })
    }

    @Test("la recherche accepte les préfixes")
    func searchMatchesPrefixes() throws {
        #expect(try repository.search("oursi").count > 5)
    }

    @Test("la recherche trouve par nom scientifique")
    func searchMatchesScientificName() throws {
        let results = try repository.search("Paracentrotus")
        #expect(results.contains { $0.id == 1437 })
    }

    @Test("la recherche accepte plusieurs mots")
    func searchMatchesMultipleTokens() throws {
        let results = try repository.search("oursin viol")
        #expect(results.contains { $0.id == 1437 })
    }

    @Test("une recherche vide ne renvoie rien")
    func emptySearchReturnsNothing() throws {
        #expect(try repository.search("").isEmpty)
        #expect(try repository.search("   ").isEmpty)
    }

    @Test("un terme sans résultat renvoie une liste vide, pas une erreur")
    func unmatchedSearchIsEmpty() throws {
        #expect(try repository.search("zzzzzqqqq").isEmpty)
    }

    @Test("la recherche tolère la ponctuation et les guillemets")
    func searchToleratesPunctuation() throws {
        // FTS5 treats unescaped quotes as syntax; the repository must not throw.
        #expect(try repository.search("\"oursin").isEmpty == false)
        #expect(try repository.search("d'éléphant").contains { $0.id == 881 })
        _ = try repository.search("a * b ^ c")
        #expect(try repository.search("*").isEmpty)
    }

    @Test("l'arbre des groupes a des racines non vides")
    func groupTreeHasRoots() throws {
        let roots = try repository.rootGroups()
        #expect(!roots.isEmpty)
        #expect(roots.allSatisfy { $0.speciesCount > 0 })
    }

    @Test("les espèces d'un groupe incluent celles des sous-groupes")
    func groupSpeciesAreRecursive() throws {
        let root = try repository.rootGroups().max { $0.speciesCount < $1.speciesCount }!
        let species = try repository.species(inGroup: root.id)
        #expect(species.count == root.speciesCount)
    }

    @Test("les sous-groupes d'une racine ont cette racine pour parent")
    func childGroupsBelongToTheirParent() throws {
        let root = try repository.rootGroups().max { $0.speciesCount < $1.speciesCount }!
        let children = try repository.childGroups(of: root.id)
        #expect(!children.isEmpty)
        #expect(children.allSatisfy { $0.parentId == root.id })
    }

    @Test("les zones renvoient des espèces")
    func zonesReturnSpecies() throws {
        let zones = try repository.zones()
        #expect(!zones.isEmpty)
        #expect(try repository.species(inZone: zones[0].id).isEmpty == false)
    }

    @Test("le détail d'une fiche est complet et ordonné")
    func detailIsCompleteAndOrdered() throws {
        let detail = try #require(try repository.detail(id: 1437))
        #expect(detail.species.commonName == "Oursin violet")
        #expect(!detail.sections.isEmpty)
        #expect(!detail.photos.isEmpty)
        #expect(detail.photos.map(\.position) == Array(0..<detail.photos.count))
        #expect(!detail.ranks.isEmpty)
        #expect(!detail.zones.isEmpty)

        let order = SectionKind.allCases
        let positions = detail.sections.compactMap { order.firstIndex(of: $0.kind) }
        #expect(positions == positions.sorted())
    }

    @Test("le détail sépare les noms français des noms étrangers")
    func detailSplitsVernacularNames() throws {
        let detail = try #require(try repository.detail(id: 1437))
        #expect(!detail.frenchNames.isEmpty)
        #expect(!detail.otherNames.isEmpty)
        #expect(Set(detail.frenchNames).isDisjoint(with: Set(detail.otherNames)))
        #expect(detail.group.id == detail.species.groupId)
        #expect(detail.section(.identification) != nil)
    }

    @Test("un identifiant inconnu renvoie nil")
    func unknownDetailIsNil() throws {
        #expect(try repository.detail(id: 999_999) == nil)
    }

    @Test("la récupération par identifiants préserve l'ordre demandé")
    func speciesByIdsKeepsOrder() throws {
        let ids = [1437, 133, 881]
        #expect(try repository.species(ids: ids).map(\.id) == ids)
        #expect(try repository.species(ids: []).isEmpty)
        #expect(try repository.species(ids: [1437, 999_999]).map(\.id) == [1437])
    }
}
