import SwiftUI
import PhotosUI
import CoreLocation

// MARK: - Local types

struct WalkPhoto: Identifiable, Hashable {
    var id: UUID
    var storagePath: String
    var note: String
    var condition: PhotoCondition
    var sha256: String
    var capturedAt: String
    var localImage: UIImage?
    var remoteURL: URL?

    static func == (lhs: WalkPhoto, rhs: WalkPhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct WalkRoom: Identifiable {
    var room: Room
    var photos: [WalkPhoto]
    var id: UUID { room.id }
}

enum UploadStatus: Equatable {
    case compressing, hashing, uploading
    case error(String)
}

struct PendingUpload: Identifiable {
    let id = UUID()
    var roomId: UUID
    var image: UIImage
    var status: UploadStatus
}

/// Ports walkthrough-client.tsx — the core room-by-room native capture flow.
struct WalkthroughView: View {
    let propertyId: UUID
    let phase: Phase
    @Binding var path: [AppRoute]

    @State private var loadState: LoadState = .loading
    @State private var isPaid = false
    @State private var walkRooms: [WalkRoom] = []
    @State private var roomIndex = 0
    @State private var pending: [PendingUpload] = []
    @State private var totalExistingPhotos = 0
    @State private var sessionUploaded = 0
    @State private var propertyName = ""
    @State private var propertyState: String?
    @State private var showPaywall = false
    @State private var showComplete = false
    @State private var finishing = false
    @State private var showCamera = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var editingPhoto: WalkPhoto?
    @State private var toast: String?
    @State private var showViewer = false
    @State private var viewerItems: [PhotoViewerItem] = []
    @State private var viewerStartIndex = 0

    @State private var coordsResolved = false
    @State private var coords: CLLocationCoordinate2D?
    private let locationFetcher = LocationFetcher()

    private var room: WalkRoom? { walkRooms.indices.contains(roomIndex) ? walkRooms[roomIndex] : nil }
    private var isLastRoom: Bool { roomIndex == walkRooms.count - 1 }
    private var totalUsed: Int { totalExistingPhotos + sessionUploaded }
    private var atLimit: Bool { !isPaid && totalUsed >= FreeTier.photoLimit }
    private var roomPending: [PendingUpload] {
        guard let room else { return [] }
        return pending.filter { $0.roomId == room.id }
    }
    private var totalDocumented: Int { walkRooms.reduce(0) { $0 + $1.photos.count } }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if showComplete {
                    completionView
                } else if walkRooms.isEmpty {
                    EmptyStateCard(icon: "square.on.square", title: "No rooms yet", description: "Add rooms to this property before starting a walkthrough.", actionTitle: "Back to property") {
                        path.removeLast()
                    }
                    .padding(24)
                } else {
                    walkthroughBody
                }
            }
        }
        .toastOverlay($toast)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Exit") { path.removeLast() }
                    .font(.system(size: 14)).foregroundStyle(DS.ink.opacity(0.5))
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(onCapture: { image in handleCaptured([image]) }, onCancel: {})
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showViewer) {
            PhotoViewerView(items: viewerItems, startIndex: viewerStartIndex)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(propertyId: propertyId) {
                isPaid = true
                showPaywall = false
            }
        }
        .sheet(item: $editingPhoto) { photo in
            PhotoEditSheet(photo: photo, onSave: { note, condition in
                updatePhoto(photo.id, note: note, condition: condition)
            }, onDelete: {
                deletePhoto(photo)
            })
        }
        .onChange(of: pickerSelection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    pickerSelection = []
                    handleCaptured(images)
                }
            }
        }
    }

    // MARK: Load

    private func load() async {
        loadState = .loading
        do {
            guard let detail = try await DataStore.fetchPropertyDetail(propertyId: propertyId) else {
                loadState = .failed("This property could not be found.")
                return
            }
            isPaid = detail.property.is_paid
            totalExistingPhotos = detail.totalMoveInPhotos + detail.totalMoveOutPhotos
            propertyName = Formatters.propertyDisplayName(detail.property)
            propertyState = detail.property.state

            let allPaths = detail.rooms.flatMap { $0.photos(for: phase).map(\.storage_path) }
            let signed = await DataStore.signedURLs(bucket: "photos", paths: allPaths)

            walkRooms = detail.rooms.map { r in
                WalkRoom(room: r.room, photos: r.photos(for: phase).map { p in
                    WalkPhoto(id: p.id, storagePath: p.storage_path, note: p.note ?? "", condition: p.condition, sha256: p.sha256, capturedAt: p.captured_at, localImage: nil, remoteURL: signed[p.storage_path])
                })
            }
            // Resume where a previous session left off: the first room with
            // no photos yet, rather than always restarting at room one.
            roomIndex = walkRooms.firstIndex { $0.photos.isEmpty } ?? 0
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this property.\n\(error.localizedDescription)")
        }
    }

    // MARK: Capture -> compress -> hash -> upload

    private func handleCaptured(_ images: [UIImage]) {
        guard let room else { return }
        if atLimit { showPaywall = true; return }
        guard let userId = supabase.auth.currentUser?.id else {
            toast = "Your session expired \u{2014} please sign in again."
            return
        }

        for image in images {
            if !isPaid && totalExistingPhotos + sessionUploaded >= FreeTier.photoLimit {
                showPaywall = true
                break
            }
            let upload = PendingUpload(roomId: room.id, image: image, status: .compressing)
            pending.append(upload)
            Task { await uploadOne(upload, userId: userId) }
        }
    }

    private func ensureCoords() async -> CLLocationCoordinate2D? {
        if !coordsResolved {
            coords = await locationFetcher.fetchOnce()
            coordsResolved = true
        }
        return coords
    }

    private func uploadOne(_ upload: PendingUpload, userId: UUID) async {
        do {
            let capturedAt = Formatters.isoTimestamp()
            guard let compressed = ImageProcessing.compress(upload.image) else {
                throw NSError(domain: "DepositShield", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not process photo."])
            }
            updateStatus(upload.id, .hashing)
            let hash = Hashing.sha256Hex(compressed)
            let photoId = UUID()
            let storagePath = DataStore.photoStoragePath(userId: userId, propertyId: propertyId, photoId: photoId)

            updateStatus(upload.id, .uploading)
            try await DataStore.uploadPhoto(data: compressed, path: storagePath)

            let coord = await ensureCoords()
            let payload = NewPhotoPayload(
                id: photoId, property_id: propertyId, room_id: upload.roomId, user_id: userId,
                phase: phase, storage_path: storagePath, sha256: hash, captured_at: capturedAt,
                lat: coord?.latitude, lng: coord?.longitude, condition: .good
            )
            try await DataStore.insertPhoto(payload)

            await MainActor.run {
                let newPhoto = WalkPhoto(id: photoId, storagePath: storagePath, note: "", condition: .good, sha256: hash, capturedAt: capturedAt, localImage: upload.image, remoteURL: nil)
                if let idx = walkRooms.firstIndex(where: { $0.id == upload.roomId }) {
                    walkRooms[idx].photos.append(newPhoto)
                }
                sessionUploaded += 1
                pending.removeAll { $0.id == upload.id }
            }
        } catch {
            updateStatus(upload.id, .error(error.localizedDescription))
        }
    }

    private func updateStatus(_ id: UUID, _ status: UploadStatus) {
        Task { @MainActor in
            if let idx = pending.firstIndex(where: { $0.id == id }) {
                pending[idx].status = status
            }
        }
    }

    private func retryUpload(_ upload: PendingUpload) {
        guard let userId = supabase.auth.currentUser?.id else { return }
        updateStatus(upload.id, .compressing)
        Task { await uploadOne(upload, userId: userId) }
    }

    private func removePending(_ id: UUID) {
        pending.removeAll { $0.id == id }
    }

    // MARK: Photo edits

    private func updatePhoto(_ id: UUID, note: String, condition: PhotoCondition) {
        for i in walkRooms.indices {
            if let pi = walkRooms[i].photos.firstIndex(where: { $0.id == id }) {
                walkRooms[i].photos[pi].note = note
                walkRooms[i].photos[pi].condition = condition
            }
        }
        Task {
            try? await DataStore.updatePhotoNote(photoId: id, note: note)
            try? await DataStore.updatePhotoCondition(photoId: id, condition: condition)
        }
    }

    private func deletePhoto(_ photo: WalkPhoto) {
        for i in walkRooms.indices {
            walkRooms[i].photos.removeAll { $0.id == photo.id }
        }
        Task { try? await DataStore.deletePhoto(photoId: photo.id, storagePath: photo.storagePath) }
    }

    // MARK: Navigation

    private func goNext() {
        Haptics.tap()
        if isLastRoom {
            finish()
        } else {
            withAnimation { roomIndex = min(roomIndex + 1, walkRooms.count - 1) }
        }
    }

    private func goPrev() {
        Haptics.tap()
        withAnimation { roomIndex = max(roomIndex - 1, 0) }
    }

    private func finish() {
        finishing = true
        Task {
            do {
                try await DataStore.markPhaseComplete(propertyId: propertyId, phase: phase)
                if phase == .move_out {
                    await NotificationManager.scheduleDeadlineReminders(propertyId: propertyId, propertyName: propertyName, state: propertyState)
                }
                await MainActor.run {
                    finishing = false
                    Haptics.success()
                    withAnimation { showComplete = true }
                }
            } catch {
                await MainActor.run {
                    finishing = false
                    toast = error.localizedDescription
                }
            }
        }
    }

    // MARK: Views

    private var walkthroughBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("\(phase.label) \u{b7} Room \(roomIndex + 1) of \(walkRooms.count)")
                    .font(DS.mono(11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(DS.brass)
                HStack(spacing: 4) {
                    ForEach(walkRooms.indices, id: \.self) { i in
                        // Per-room completion tick: emerald once that room has
                        // photos, brass while it's the active (undocumented) room.
                        let documented = !walkRooms[i].photos.isEmpty
                        Capsule()
                            .fill(documented ? DS.emerald : (i == roomIndex ? DS.brass : DS.ink.opacity(0.1)))
                            .frame(height: 3)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)

            ScrollView {
                if let room {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(room.room.name).font(DS.serif(24)).foregroundStyle(DS.ink)
                            Text("\(room.photos.count + roomPending.count) photo\(room.photos.count + roomPending.count == 1 ? "" : "s") in this room")
                                .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.5))
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                            ForEach(Array(room.photos.enumerated()), id: \.element.id) { index, photo in
                                PhotoGridCell(photo: photo, onEdit: { editingPhoto = photo }, onExpand: {
                                    viewerItems = room.photos.map { PhotoViewerItem(id: $0.id, image: $0.localImage, url: $0.remoteURL, capturedAt: $0.capturedAt, sha256: $0.sha256, lat: nil, lng: nil, note: $0.note.isEmpty ? nil : $0.note) }
                                    viewerStartIndex = index
                                    showViewer = true
                                })
                            }
                            ForEach(roomPending) { p in
                                PendingGridCell(upload: p, onRetry: { retryUpload(p) }, onRemove: { removePending(p.id) })
                            }
                            Button {
                                Haptics.tap()
                                if atLimit { showPaywall = true } else { showCamera = true }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill").font(.system(size: 26))
                                    Text("Take photo").font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(DS.ink.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(DS.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.6, dash: [6, 5]))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if atLimit {
                            Button {
                                Haptics.tap()
                                showPaywall = true
                            } label: {
                                Text("+ Add from library")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DS.emeraldDark)
                            }
                            .buttonStyle(.plain)
                        } else {
                            PhotosPicker(selection: $pickerSelection, maxSelectionCount: 10, matching: .images) {
                                Text("+ Add from library")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DS.emeraldDark)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }

            Divider().overlay(DS.ink.opacity(0.08))
            HStack(spacing: 12) {
                Button {
                    goPrev()
                } label: {
                    Text("Back").font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.ink.opacity(roomIndex == 0 ? 0.25 : 0.7))
                        .padding(.vertical, 15).padding(.horizontal, 22)
                }
                .buttonStyle(.plain)
                .disabled(roomIndex == 0)

                Button {
                    goNext()
                } label: {
                    HStack(spacing: 6) {
                        if finishing { ProgressView().tint(.white).scaleEffect(0.8) }
                        Text(isLastRoom ? (finishing ? "Finishing\u{2026}" : "Finish walkthrough") : "Next room")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(DS.emerald, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(finishing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(DS.emerald50).frame(width: 96, height: 96)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44)).foregroundStyle(DS.emerald)
            }
            Text("\(phase.label) walkthrough complete")
                .font(DS.serif(28)).foregroundStyle(DS.ink).multilineTextAlignment(.center)
            Text("\(totalDocumented) photos hashed and timestamped across \(walkRooms.count) rooms. Your record is locked in.")
                .font(.system(size: 14)).foregroundStyle(DS.ink.opacity(0.6)).multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                LedgerButton(title: "Generate report") {
                    path.removeLast()
                    path.append(.report(propertyId: propertyId))
                }
                Button {
                    Haptics.tap()
                    path.removeLast()
                } label: {
                    Text("Back to property").font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid cells

private struct PhotoGridCell: View {
    let photo: WalkPhoto
    let onEdit: () -> Void
    let onExpand: () -> Void

    var body: some View {
        Button(action: onEdit) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let image = photo.localImage {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else if let url = photo.remoteURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                DS.ink.opacity(0.05)
                            }
                        }
                    } else {
                        DS.ink.opacity(0.05)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()

                ConditionBadge(condition: photo.condition).padding(6)

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DS.ink.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

private struct PendingGridCell: View {
    let upload: PendingUpload
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            Image(uiImage: upload.image).resizable().aspectRatio(contentMode: .fill)
                .aspectRatio(1, contentMode: .fill).clipped().opacity(0.5)

            switch upload.status {
            case .error(let message):
                VStack(spacing: 8) {
                    Text("Upload failed").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    Text(message).font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineLimit(2)
                    HStack(spacing: 8) {
                        Button("Retry", action: onRetry).font(.system(size: 11, weight: .semibold))
                        Button("Remove", action: onRemove).font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                .padding(8)
                .background(DS.ink.opacity(0.55))
            default:
                VStack(spacing: 6) {
                    ProgressView().tint(.white)
                    Text(statusLabel).font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
                }
                .padding(8)
                .background(DS.ink.opacity(0.35))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusLabel: String {
        switch upload.status {
        case .compressing: return "Compressing\u{2026}"
        case .hashing: return "Hashing\u{2026}"
        case .uploading: return "Uploading\u{2026}"
        case .error: return "Error"
        }
    }
}

// MARK: - Edit sheet

private struct PhotoEditSheet: View {
    let photo: WalkPhoto
    let onSave: (String, PhotoCondition) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var condition: PhotoCondition
    @State private var confirmingDelete = false

    init(photo: WalkPhoto, onSave: @escaping (String, PhotoCondition) -> Void, onDelete: @escaping () -> Void) {
        self.photo = photo
        self.onSave = onSave
        self.onDelete = onDelete
        _note = State(initialValue: photo.note)
        _condition = State(initialValue: photo.condition)
    }

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(DS.ink.opacity(0.15)).frame(width: 40, height: 5).padding(.top, 10)

            Group {
                if let image = photo.localImage {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else if let url = photo.remoteURL {
                    AsyncImage(url: url) { p in
                        if case .success(let img) = p { img.resizable().aspectRatio(contentMode: .fill) } else { DS.ink.opacity(0.05) }
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                Text("Condition").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                Picker("Condition", selection: $condition) {
                    ForEach(PhotoCondition.allCases, id: \.self) { c in Text(c.label).tag(c) }
                }
                .pickerStyle(.segmented)

                Text("Note (optional)").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                TextField("e.g. Scuff on the wall by the door", text: $note).ledgerFieldStyle()

                SealBadge(label: Formatters.truncateHash(photo.sha256, chars: 8))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                LedgerButton(title: "Save") {
                    onSave(note, condition)
                    dismiss()
                }
                if confirmingDelete {
                    HStack(spacing: 10) {
                        Button {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Yes, delete photo").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 9).background(DS.clay, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button("Cancel") { confirmingDelete = false }
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.5))
                    }
                } else {
                    Button {
                        Haptics.tap()
                        confirmingDelete = true
                    } label: {
                        Text("Delete photo").font(.system(size: 14, weight: .medium)).foregroundStyle(DS.clay)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
