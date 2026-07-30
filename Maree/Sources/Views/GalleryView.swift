import SwiftUI

/// Full-screen photo viewer: swipe between photos, pinch to zoom.
struct GalleryView: View {
    let speciesId: Int
    let initialPosition: Int

    @Environment(\.repository) private var repository
    @State private var photos: [Photo] = []
    @State private var position: Int

    init(speciesId: Int, initialPosition: Int) {
        self.speciesId = speciesId
        self.initialPosition = initialPosition
        _position = State(initialValue: initialPosition)
    }

    var body: some View {
        TabView(selection: $position) {
            ForEach(photos) { photo in
                VStack {
                    RemoteImage(.photo(speciesId: speciesId, position: photo.position), contentMode: .fit)
                        .zoomable()
                    if let caption = photo.caption {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding()
                    }
                }
                .tag(photo.position)
            }
        }
        .tabViewStyle(.page)
        // Without the pill backdrop the page dots are dark grey on black in light mode,
        // hiding the only hint that there are more photos.
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(.black)
        .navigationTitle("\(position + 1) / \(max(photos.count, 1))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        // The bar sits on black, so its title and back button must use the dark
        // palette even when the system is in light mode.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { photos = (try? repository.detail(id: speciesId))?.photos ?? [] }
    }
}

private extension View {
    /// Pinch-to-zoom that snaps back below 1× — enough for inspecting a photo
    /// without pulling in a gesture library.
    func zoomable() -> some View {
        modifier(Zoomable())
    }
}

private struct Zoomable: ViewModifier {
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            // ponytail: two known ceilings, both fine for inspecting a photo.
            // No panning, so a zoomed photo shows only its centre — add a drag
            // offset if that proves too coarse in the water. And `magnification`
            // restarts at 1 each gesture, so pinches do not accumulate: reaching
            // 4× takes one wide pinch, not several. Multiply into a stored base
            // scale if that becomes annoying. Double tap is the way back out.
            .gesture(
                MagnifyGesture()
                    .onChanged { scale = max(1, $0.magnification) }
                    .onEnded { _ in withAnimation(.spring) { scale = max(1, min(scale, 4)) } }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring) { scale = scale > 1 ? 1 : 2.5 }
            }
    }
}
