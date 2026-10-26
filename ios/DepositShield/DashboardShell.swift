import SwiftUI

/// Top-level authenticated app shell: My Places (renter mode, unchanged) +
/// Communities (HOA board mode) + Settings. Each owns its own typed
/// NavigationStack path so screens within a mode push/pop independently.
struct DashboardShell: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                DashboardView(path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem { Label("My Places", systemImage: "house.fill") }

            NavigationStack {
                CommunitiesRootView()
            }
            .tabItem { Label("Communities", systemImage: "building.2.fill") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(DS.emerald)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .newProperty:
            NewPropertyView(path: $path)
        case .property(let id):
            PropertyOverviewView(propertyId: id, path: $path)
        case .walkthrough(let propertyId, let phase):
            WalkthroughView(propertyId: propertyId, phase: phase, path: $path)
        case .compare(let propertyId):
            CompareView(propertyId: propertyId)
        case .report(let propertyId):
            ReportView(propertyId: propertyId)
        case .evidence(let propertyId):
            EvidenceView(propertyId: propertyId)
        }
    }
}
