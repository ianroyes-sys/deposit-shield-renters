import SwiftUI

struct BoardRoomView: View {
    let associationId: UUID
    let isBoard: Bool
    let membership: MembershipRow
    @Binding var path: [CommunityRoute]

    private enum Section { case announcements, motions }

    @State private var section: Section = .announcements
    @State private var loadState: LoadState = .loading
    @State private var announcements: [Announcement] = []
    @State private var motions: [Motion] = []
    @State private var votes: [MotionVote] = []
    @State private var error: String?
    @State private var acting: UUID?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    Text("Announcements").tag(Section.announcements)
                    Text("Motions").tag(Section.motions)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let error {
                                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                            }
                            if section == .announcements {
                                announcementsList
                            } else {
                                motionsList
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Board Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isBoard {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(section == .announcements ? .newAnnouncement : .newMotion)
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(DS.brass)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var announcementsList: some View {
        if announcements.isEmpty {
            EmptyStateCard(icon: "megaphone", title: "No announcements yet", description: isBoard ? "Share updates with residents \u{2014} they'll see them here." : "The board hasn't posted anything yet.")
        } else {
            ForEach(announcements) { ann in
                LedgerCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if ann.pinned {
                                Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(DS.brass)
                            }
                            Text(ann.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                            Spacer()
                            Text(Formatters.date(ann.created_at)).font(.system(size: 11)).foregroundStyle(DS.ink.opacity(0.4))
                        }
                        if let body = ann.body, !body.isEmpty {
                            Text(body).font(.system(size: 13.5)).foregroundStyle(DS.ink.opacity(0.65))
                        }
                        if isBoard {
                            HStack(spacing: 14) {
                                Button(ann.pinned ? "Unpin" : "Pin") { togglePin(ann) }
                                Button("Delete", role: .destructive) { delete(ann) }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.brass)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var motionsList: some View {
        if motions.isEmpty {
            EmptyStateCard(icon: "checkmark.circle", title: "No motions yet", description: isBoard ? "Bring a decision to the board for a documented yes/no/abstain vote." : "There are no board motions to review right now.")
        } else {
            ForEach(motions) { motion in
                MotionCard(
                    motion: motion,
                    tally: tally(for: motion.id),
                    isBoard: isBoard,
                    myVote: votes.first { $0.motion_id == motion.id && $0.voter == membership.user_id }?.vote,
                    acting: acting == motion.id,
                    onVote: { choice in castVote(motion, choice: choice) },
                    onClose: { status in closeMotion(motion, status: status) }
                )
            }
        }
    }

    private func tally(for motionId: UUID) -> (yes: Int, no: Int, abstain: Int) {
        let relevant = votes.filter { $0.motion_id == motionId }
        return (relevant.filter { $0.vote == .yes }.count, relevant.filter { $0.vote == .no }.count, relevant.filter { $0.vote == .abstain }.count)
    }

    private func load() async {
        loadState = .loading
        do {
            announcements = try await HOADataStore.fetchAnnouncements(associationId: associationId)
            motions = try await HOADataStore.fetchMotions(associationId: associationId)
            votes = try await HOADataStore.fetchAllVotes(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load the board room.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    private func togglePin(_ ann: Announcement) {
        Task {
            try? await HOADataStore.setAnnouncementPinned(id: ann.id, pinned: !ann.pinned)
            await load()
        }
    }

    private func delete(_ ann: Announcement) {
        Task {
            try? await HOADataStore.deleteAnnouncement(id: ann.id)
            await load()
        }
    }

    private func castVote(_ motion: Motion, choice: MotionVoteChoice) {
        error = nil
        acting = motion.id
        Task {
            do {
                try await HOADataStore.castVote(motionId: motion.id, associationId: associationId, voter: membership.user_id, vote: choice)
                await load()
                await MainActor.run { acting = nil }
            } catch {
                await MainActor.run {
                    acting = nil
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }

    private func closeMotion(_ motion: Motion, status: MotionStatus) {
        Task {
            try? await HOADataStore.setMotionStatus(id: motion.id, status: status)
            await load()
        }
    }
}

private struct MotionCard: View {
    let motion: Motion
    let tally: (yes: Int, no: Int, abstain: Int)
    let isBoard: Bool
    let myVote: MotionVoteChoice?
    let acting: Bool
    let onVote: (MotionVoteChoice) -> Void
    let onClose: (MotionStatus) -> Void

    private var tone: StatusTone {
        switch motion.status {
        case .open: return .progress
        case .passed: return .success
        case .failed, .withdrawn: return .neutral
        }
    }

    var body: some View {
        LedgerCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(motion.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                    Spacer()
                    StatusPill(label: motion.status.label, tone: tone)
                }
                if let description = motion.description, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.65))
                }

                HStack(spacing: 16) {
                    tallyBlock("Yes", tally.yes, DS.emerald)
                    tallyBlock("No", tally.no, DS.clay)
                    tallyBlock("Abstain", tally.abstain, DS.ink.opacity(0.4))
                }

                if isBoard {
                    if motion.status == .open {
                        if let myVote {
                            Text("You voted: \(myVote.rawValue.capitalized)").font(.system(size: 12, weight: .medium)).foregroundStyle(DS.brass)
                        } else {
                            HStack(spacing: 8) {
                                voteButton("Yes", .yes, DS.emerald)
                                voteButton("No", .no, DS.clay)
                                voteButton("Abstain", .abstain, DS.ink.opacity(0.5))
                            }
                        }
                        HStack(spacing: 14) {
                            Button("Mark passed") { onClose(.passed) }
                            Button("Mark failed") { onClose(.failed) }
                            Button("Withdraw") { onClose(.withdrawn) }
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DS.ink.opacity(0.45))
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func tallyBlock(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(DS.ink.opacity(0.4))
            Text("\(count)").font(DS.mono(15, weight: .semibold)).foregroundStyle(color)
        }
    }

    private func voteButton(_ title: String, _ choice: MotionVoteChoice, _ color: Color) -> some View {
        Button {
            Haptics.tap()
            onVote(choice)
        } label: {
            HStack(spacing: 4) {
                if acting { ProgressView().tint(color).scaleEffect(0.6) }
                Text(title)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(acting)
    }
}
