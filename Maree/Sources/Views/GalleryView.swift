import SwiftUI

// Placeholder, replaced in a later task.
struct GalleryView: View {
    let speciesId: Int
    let initialPosition: Int
    var body: some View { RemoteImage(.photo(speciesId: speciesId, position: initialPosition), contentMode: .fit) }
}
