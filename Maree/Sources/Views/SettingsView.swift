import SwiftUI

struct SettingsView: View {
    @Environment(\.repository) private var repository
    @Environment(\.favorites) private var favorites
    @Environment(\.imageStore) private var imageStore
    @Environment(\.thumbnailPack) private var pack

    /// Shared with the « Préparer » action on a group: whichever starts the run,
    /// this screen is where it is followed and cancelled.
    @Environment(\.tripPreparation) private var trip
    @State private var scope: TripScope?
    @State private var estimate: (photos: Int, bytes: Int64)?
    @State private var zones: [Zone] = []
    @State private var dorisDate = "—"
    @State private var speciesCount = "—"
    @State private var cacheSize: Int64 = 0

    var body: some View {
        NavigationStack {
            List {
                // `Section` on its own resolves to our database record, which shadows
                // SwiftUI's type module-wide.
                SwiftUI.Section("Hors ligne") {
                    LabeledContent("Vignettes") { packStatus }
                    if let fraction = pack.state.fraction {
                        ProgressView(value: fraction)
                    }
                    // ~46 Mo, possibly on a metered connection. Suspending is safe and
                    // resumable in the same session: the cache directory is the progress
                    // state, and `startIfNeeded()` only refuses while a run is in flight.
                    if pack.state.isRunning {
                        Button("Suspendre", role: .destructive) { pack.cancel() }
                    } else if pack.state == .cancelled {
                        Button("Reprendre") { Task { await pack.startIfNeeded() } }
                    }
                    // A bucket outage 404ing part of the pack is recorded permanently:
                    // without this the app would keep reporting « complètes » over a
                    // cache that is missing whatever was down that day. Vignettes and
                    // photos de sortie share one registry, so this clears both.
                    Button("Revérifier les images") { Task { await pack.recheck() } }
                        .disabled(pack.state.isRunning)
                    LabeledContent("Images en cache", value: cacheSize.formattedBytes)
                }
                .listRowBackground(Theme.surface)

                SwiftUI.Section("Préparer une sortie") {
                    Picker("Contenu", selection: $scope) {
                        Text("Choisir…").tag(TripScope?.none)
                        Text("Mes favoris (\(favorites.ids.count))").tag(TripScope?.some(.favorites))
                        ForEach(zones) { zone in
                            Text(zone.name).tag(TripScope?.some(.zone(zone)))
                        }
                    }
                    if let estimate {
                        LabeledContent("À télécharger", value: TripPreparation.summary(of: estimate))
                    }
                    if trip.state.isRunning {
                        if let fraction = trip.state.fraction { ProgressView(value: fraction) }
                        Button("Annuler", role: .destructive) { trip.cancel() }
                    } else {
                        Button("Télécharger") { startTrip() }
                            .disabled(scope == nil || (estimate?.photos ?? 0) == 0)
                    }
                }
                .listRowBackground(Theme.surface)

                SwiftUI.Section("À propos") {
                    LabeledContent("Base DORIS", value: dorisDate)
                    LabeledContent("Espèces", value: speciesCount)
                    Text("Fiches et photos : DORIS / FFESSM. Application personnelle, non affiliée.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Réglages")
        }
        .task {
            zones = (try? repository.zones()) ?? []
            dorisDate = (try? repository.meta("dorisDate")) ?? "—"
            speciesCount = (try? repository.meta("speciesCount")).flatMap(Int.init)?.formatted() ?? "—"
        }
        // The pack keeps downloading while this screen is open, so the cache size is
        // read again when the run starts and when it stops.
        .task(id: pack.state.isRunning) {
            cacheSize = await imageStore.cacheSizeInBytes()
        }
        .task(id: scope) {
            guard let scope else { estimate = nil; return }
            estimate = try? await trip.estimate(for: scope)
        }
    }

    @ViewBuilder
    private var packStatus: some View {
        switch pack.state {
        case .running(let done, let total): Text("\(done) / \(total)")
        // Failures here are network ones, retried on the next launch. Thumbnails the
        // bucket simply does not have are recorded, not reported as a problem.
        case .finished(let failed) where failed > 0: Text("\(failed) à reprendre")
        case .finished: Text("complètes")
        case .cancelled: Text("suspendues")
        case .idle: Text("en attente")
        }
    }

    private func startTrip() {
        guard let scope else { return }
        Task {
            await trip.start(scope)
            // Both walk the cache directory, and neither needs the other's answer.
            async let size = imageStore.cacheSizeInBytes()
            async let remaining = trip.estimate(for: scope)
            cacheSize = await size
            estimate = try? await remaining
        }
    }
}
