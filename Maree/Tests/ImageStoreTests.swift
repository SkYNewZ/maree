import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Maree

/// Answers every request without a network: the thumbnail path 404s, and anything
/// else gets a 200 carrying HTML — what an intercepting portal sends back.
private nonisolated final class CaptivePortalStub: URLProtocol {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CaptivePortalStub.self]
        return URLSession(configuration: configuration)
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url,
                                             statusCode: url.lastPathComponent == "0_maree.heic" ? 404 : 200,
                                             httpVersion: nil, headerFields: nil)
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>Connectez-vous au réseau</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

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
    func cacheSizeAddsUpFiles() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory)
        #expect(await store.cacheSizeInBytes() == 0)
        try Data(repeating: 0, count: 300).write(to: directory.appending(path: "t-1.heic"))
        try Data(repeating: 0, count: 700).write(to: directory.appending(path: "p-1-0.jpg"))
        #expect(await store.cacheSizeInBytes() == 1000)
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

    /// A captive portal answers 200 with its own login page. Writing that body to the
    /// cache would leave a species permanently « téléchargée » over a file that is not
    /// an image — silent, and undoable only by reinstalling.
    @Test("une réponse 200 qui n'est pas une image n'est jamais écrite en cache")
    func poisonedPayloadIsRefused() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory, session: CaptivePortalStub.session)
        let kind = ImageKind.photo(speciesId: 999_010, position: 1)

        await #expect(throws: ImageError.self) { try await store.download(kind) }
        #expect(store.cachedFileExists(for: kind) == false)
        try? FileManager.default.removeItem(at: directory)
    }

    /// The pack guarantees one thumbnail per species offline; the full-size `0.jpg`
    /// is never prefetched. Without the fallback, a fresh install in airplane mode
    /// opens every fiche on a placeholder while the thumbnail sits on disk.
    @Test("la photo de tête retombe sur la vignette déjà en cache")
    func headerPhotoFallsBackToThumbnail() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ImageStore(directory: directory, session: CaptivePortalStub.session)
        let speciesId = 999_011
        try #require(makePNG())
            .write(to: directory.appending(path: ImageKind.thumbnail(speciesId: speciesId).cacheFileName))

        #expect(await store.image(for: .photo(speciesId: speciesId, position: 0)) != nil)
        // Only the first photo stands in for the fiche header; the gallery keeps its
        // placeholders rather than repeating the same image under every position.
        #expect(await store.image(for: .photo(speciesId: speciesId, position: 1)) == nil)
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
