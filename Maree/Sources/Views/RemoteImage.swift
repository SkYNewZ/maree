import SwiftUI

/// Displays a cached or remote image. Offline and missing images both render the
/// same quiet placeholder — never a spinner that hangs or a blocking error.
struct RemoteImage: View {
    private let kind: ImageKind
    private let contentMode: ContentMode

    @Environment(\.imageStore) private var store
    @State private var image: UIImage?
    @State private var didAttempt = false

    init(_ kind: ImageKind, contentMode: ContentMode = .fill) {
        self.kind = kind
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: kind) {
            // A paged gallery reuses one view across positions: without this reset the
            // previous species' photo would stay on screen until the new one resolves.
            image = nil
            didAttempt = false
            image = await store.image(for: kind)
            didAttempt = true
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if didAttempt {
                Image(systemName: "fish")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Photo indisponible hors ligne")
            } else {
                ProgressView()
            }
        }
    }
}
