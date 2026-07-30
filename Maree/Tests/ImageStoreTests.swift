import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Maree

@Suite("Cache d'images")
@MainActor
struct ImageStoreTests {
    @Test("les URLs distantes suivent la convention du bucket")
    func remoteURLs() {
        #expect(ImageKind.thumbnail(speciesId: 1437).remoteURL.absoluteString
            == "https://s3.us-east-005.backblazeb2.com/doris-production/images/1437/0_maree.heic")
        #expect(ImageKind.photo(speciesId: 1437, position: 3).remoteURL.absoluteString
            == "https://s3.us-east-005.backblazeb2.com/doris-production/images/1437/3.jpg")
    }

    @Test("les noms de fichiers de cache sont uniques et sans conflit")
    func cacheFileNames() {
        #expect(ImageKind.thumbnail(speciesId: 12).cacheFileName != ImageKind.photo(speciesId: 12, position: 0).cacheFileName)
        #expect(ImageKind.photo(speciesId: 1, position: 20).cacheFileName != ImageKind.photo(speciesId: 12, position: 0).cacheFileName)
    }

    @Test("le cache vit dans un répertoire persistant, jamais dans Caches")
    func cacheDirectoryIsPersistent() throws {
        let store = ImageStore()
        let path = store.directory.path
        #expect(path.contains("Application Support"))
        #expect(!path.contains("/Caches/"))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("un fichier écrit est retrouvé, un absent ne l'est pas")
    func fileExistenceTracking() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory)
        let kind = ImageKind.thumbnail(speciesId: 999_001)
        #expect(store.cachedFileExists(for: kind) == false)
        try Data("x".utf8).write(to: directory.appending(path: kind.cacheFileName))
        #expect(store.cachedFileExists(for: kind) == true)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("la taille du cache additionne les fichiers présents")
    func cacheSizeAddsUpFiles() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory)
        #expect(store.cacheSizeInBytes() == 0)
        try Data(repeating: 0, count: 300).write(to: directory.appending(path: "t-1.heic"))
        try Data(repeating: 0, count: 700).write(to: directory.appending(path: "p-1-0.jpg"))
        #expect(store.cacheSizeInBytes() == 1000)
        try? FileManager.default.removeItem(at: directory)
    }

    /// Stays offline: the file is already on disk, so the network branch is never
    /// reached — which is also what makes the second read prove the memory cache.
    @Test("une image en cache est lue sur le disque puis gardée en mémoire")
    func diskThenMemory() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory)
        let kind = ImageKind.photo(speciesId: 999_002, position: 0)
        let file = directory.appending(path: kind.cacheFileName)
        try #require(makePNG()).write(to: file)

        let fromDisk = await store.image(for: kind)
        #expect(fromDisk != nil)

        try FileManager.default.removeItem(at: file)
        let fromMemory = await store.image(for: kind)
        #expect(fromMemory != nil)

        try? FileManager.default.removeItem(at: directory)
    }

    private func makePNG() -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.pngData()
    }

    /// `@Entry` environment defaults are computed, so a fresh `ImageStore()` there
    /// would give every reader its own cache — and its own in-flight table.
    @Test("l'environnement expose l'unique instance partagée")
    func environmentExposesSharedStore() {
        #expect(EnvironmentValues().imageStore === ImageStore.shared)
    }
}
