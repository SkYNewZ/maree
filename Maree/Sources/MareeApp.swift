import SwiftUI

@main
struct MareeApp: App {
    var body: some Scene {
        WindowGroup {
            DatabaseProbeView()
        }
    }
}

/// Temporary smoke screen: proves the bundled database opens on device.
/// Replaced by RootView in the next task.
private struct DatabaseProbeView: View {
    @Environment(\.repository) private var repository
    @State private var summary = "…"

    var body: some View {
        Text(summary)
            .task {
                do {
                    let count = try repository.search("oursin").count
                    let date = try repository.meta("dorisDate") ?? "?"
                    summary = "Base DORIS du \(date) — \(count) résultats pour « oursin »"
                } catch {
                    summary = "Erreur : \(error.localizedDescription)"
                }
            }
    }
}
