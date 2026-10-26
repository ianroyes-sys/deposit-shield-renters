import SwiftUI

/// Entry point for the "Communities" tab: shows the premium empty state for
/// users in no association, a picker if they belong to more than one, or
/// routes straight into the single community they're part of.
struct CommunitiesRootView: View {
    @State private var loadState: LoadState = .loading
    @State private var memberships: [MembershipRow] = []
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        ZStack {
            CommunityDesign.background.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if memberships.isEmpty {
                    emptyState
                } else if memberships.count == 1 {
                    CommunityShellView(membership: memberships[0])
                } else {
                    pickerList
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COMMUNITIES")
                    .font(DS.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(DS.brass)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            CreateAssociationView { await load() }
        }
        .sheet(isPresented: $showJoin) {
            JoinAssociationView { await load() }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(DS.brass.opacity(0.12)).frame(width: 92, height: 92)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(LinearGradient(colors: [DS.brassLight, DS.brass], startPoint: .top, endPoint: .bottom))
                }
                .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("Enforcement that holds up.")
                        .font(DS.serif(26))
                        .foregroundStyle(DS.ink)
                        .multilineTextAlignment(.center)
                    Text("Run your association's rule enforcement, inspections, and board business on a hash-verified paper trail \u{2014} not group texts and spreadsheets.")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        showCreate = true
                    } label: {
                        Text("Start your association")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [DS.brass, DS.brassLight], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                            .shadow(color: DS.brass.opacity(0.3), radius: 18, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.tap()
                        showJoin = true
                    } label: {
                        Text("Join with a code")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().strokeBorder(DS.ink.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)

                Text("Residents are always free \u{2014} every notice and report still carries the Deposit Shield mark.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(DS.ink.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }
            .padding(.bottom, 40)
        }
    }

    private var pickerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your communities").font(DS.serif(24)).foregroundStyle(DS.ink).padding(.horizontal, 20).padding(.top, 12)
                ForEach(memberships) { membership in
                    NavigationLink {
                        CommunityShellView(membership: membership)
                    } label: {
                        LedgerCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(membership.associations.name).font(DS.serif(17)).foregroundStyle(DS.ink)
                                    Text(membership.role == .board ? "Board member" : "Resident").font(.system(size: 12)).foregroundStyle(DS.brass)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(DS.ink.opacity(0.3))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                HStack(spacing: 10) {
                    Button("+ New") { showCreate = true }
                    Button("Join code") { showJoin = true }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.brass)
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            .padding(.bottom, 40)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            memberships = try await HOADataStore.fetchMemberships()
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load your communities.\n\(HOAError.from(error).localizedDescription)")
        }
    }
}

/// A subtly distinct accent treatment for Communities — same Ledger family,
/// leaning harder on brass/seal "governance" energy per the board-mode brief.
enum CommunityDesign {
    static let background = DS.paper
}
