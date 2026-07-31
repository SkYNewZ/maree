import SwiftUI

/// The empty-state scaffold shared by `SearchView.startScreen` (no query yet) and
/// `SpeciesListView`'s empty branch (no results): a `ContentUnavailableView` wrapped
/// in `GeometryReader` + `ScrollView` so the description scrolls into view instead of
/// hiding behind the tab bar once it no longer fits at accessibility sizes (checked
/// at AX3, Task 7).
struct EmptyState: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
                    .frame(minHeight: proxy.size.height)
            }
        }
        .foregroundStyle(Theme.inkSoft)
        .background(Theme.paper)
    }
}
