import Foundation
import Observation
import SwiftUI
import UIKit

enum ImageKind: Hashable {
    case thumbnail(speciesId: Int)
    case photo(speciesId: Int, position: Int)

    private static let base = URL(string: "https://s3.us-east-005.backblazeb2.com/doris-production/images")!

    /// Paths are derived from the bundled database — the bucket's JSON index is
    /// never fetched, so browsing works with no network at all.
    var remoteURL: URL {
        switch self {
        case .thumbnail(let speciesId):
            Self.base.appending(path: "\(speciesId)/0_maree.heic")
        case .photo(let speciesId, let position):
            Self.base.appending(path: "\(speciesId)/\(position).jpg")
        }
    }

    var cacheFileName: String {
        switch self {
        case .thumbnail(let speciesId): "t-\(speciesId).heic"
        case .photo(let speciesId, let position): "p-\(speciesId)-\(position).jpg"
        }
    }
}

/// Persistent image cache. Files live in Application Support, never in Caches:
/// iOS may evict Caches under storage pressure, which is exactly the failure
/// mode this app exists to avoid.
@Observable
@MainActor
final class ImageStore {
    /// The instance the environment hands out. `@Entry` defaults are computed, so
    /// without this stored `static let` every `@Environment(\.imageStore)` read
    /// would build a store with an empty memory cache and its own in-flight table.
    static let shared = ImageStore()

    let directory: URL

    /// A cache, not a dictionary: a 400 px thumbnail decodes to ~640 KB, so scrolling
    /// a thousand-species group with an unbounded map would hold hundreds of MB.
    /// NSCache also drops its contents on memory pressure — the files stay on disk.
    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [ImageKind: Task<UIImage?, Never>] = [:]

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appending(path: "Images")
        memory.countLimit = 200
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func cachedFileExists(for kind: ImageKind) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: kind).path)
    }

    /// Returns the image, loading from memory, then disk, then the network.
    /// Never throws: a missing image renders a placeholder instead of an error.
    ///
    /// Concurrent callers for the same kind share one task: reaching `inFlight[kind] = task`
    /// takes no `await`, so on the main actor no second caller can interleave before the
    /// entry is published.
    func image(for kind: ImageKind) async -> UIImage? {
        let key = kind.cacheFileName as NSString
        if let cached = memory.object(forKey: key) { return cached }
        if let existing = inFlight[kind] { return await existing.value }

        let task = Task<UIImage?, Never> { [directory] in
            let url = directory.appending(path: kind.cacheFileName)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
            guard let data = try? await Self.fetch(kind), let image = UIImage(data: data) else {
                return nil
            }
            try? data.write(to: url, options: .atomic)
            return image
        }
        inFlight[kind] = task
        let image = await task.value
        inFlight[kind] = nil
        if let image { memory.setObject(image, forKey: key) }
        return image
    }

    /// Downloads to disk without decoding — used by bulk prefetching, where
    /// holding thousands of decoded images in memory would be pointless.
    func download(_ kind: ImageKind) async throws {
        guard !cachedFileExists(for: kind) else { return }
        let data = try await Self.fetch(kind)
        try data.write(to: fileURL(for: kind), options: .atomic)
    }

    func cacheSizeInBytes() -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)
        ) else { return 0 }
        return files.reduce(into: Int64(0)) { total, url in
            total += Int64((try? url.resourceValues(forKeys: keys).fileSize) ?? 0)
        }
    }

    private func fileURL(for kind: ImageKind) -> URL {
        directory.appending(path: kind.cacheFileName)
    }

    /// Only a 200 body is ever returned, so a 404 page is never written to the cache
    /// as if it were a photo. `.atomic` writes then rule out a truncated file.
    private static func fetch(_ kind: ImageKind) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: kind.remoteURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ImageError.notAvailable
        }
        return data
    }
}

enum ImageError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable: "Cette photo n'est pas disponible."
        }
    }
}

extension EnvironmentValues {
    @Entry var imageStore = ImageStore.shared
}
