import SwiftUI
import PhotosUI
import CoreLocation

struct HOAPendingUpload: Identifiable {
    let id = UUID()
    var image: UIImage
    var status: UploadStatus
}

/// Drives evidence capture for any HOA parent (violation / inspection / arc)
/// — same on-device compress -> hash -> geotag -> upload pipeline as the
/// renter walkthrough, reused rather than reimplemented.
@MainActor
final class HOAPhotoCaptureController: ObservableObject {
    let associationId: UUID
    let parentType: HOAPhotoParentType
    let parentId: UUID

    @Published var photos: [HOAPhoto] = []
    @Published var signedURLs: [String: URL] = [:]
    @Published var pending: [HOAPendingUpload] = []
    @Published var loadState: LoadState = .loaded

    private var coordsResolved = false
    private var coords: CLLocationCoordinate2D?
    private let locationFetcher = LocationFetcher()

    init(associationId: UUID, parentType: HOAPhotoParentType, parentId: UUID) {
        self.associationId = associationId
        self.parentType = parentType
        self.parentId = parentId
    }

    func load() async {
        loadState = .loading
        do {
            photos = try await HOADataStore.fetchHOAPhotos(parentType: parentType, parentId: parentId)
            signedURLs = await DataStore.signedURLs(bucket: "photos", paths: photos.map(\.storage_path))
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load photos.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    func handleCaptured(_ images: [UIImage]) {
        for image in images {
            let upload = HOAPendingUpload(image: image, status: .compressing)
            pending.append(upload)
            Task { await uploadOne(upload) }
        }
    }

    func retry(_ upload: HOAPendingUpload) {
        if let idx = pending.firstIndex(where: { $0.id == upload.id }) {
            pending[idx].status = .compressing
        }
        Task { await uploadOne(upload) }
    }

    func removePending(_ id: UUID) {
        pending.removeAll { $0.id == id }
    }

    private func ensureCoords() async -> CLLocationCoordinate2D? {
        if !coordsResolved {
            coords = await locationFetcher.fetchOnce()
            coordsResolved = true
        }
        return coords
    }

    private func uploadOne(_ upload: HOAPendingUpload) async {
        do {
            guard let userId = supabase.auth.currentUser?.id else { throw HOAError.notAuthenticated }
            let capturedAt = Formatters.isoTimestamp()
            guard let compressed = ImageProcessing.compress(upload.image) else {
                throw NSError(domain: "DepositShield", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not process photo."])
            }
            setStatus(upload.id, .hashing)
            let hash = Hashing.sha256Hex(compressed)
            let photoId = UUID()
            let path = HOADataStore.hoaPhotoStoragePath(associationId: associationId, parentType: parentType, parentId: parentId, photoId: photoId)

            setStatus(upload.id, .uploading)
            try await HOADataStore.uploadHOAPhoto(data: compressed, path: path)

            let coord = await ensureCoords()
            let payload = NewHOAPhotoPayload(
                id: photoId, association_id: associationId, parent_type: parentType, parent_id: parentId,
                uploaded_by: userId, storage_path: path, sha256: hash, captured_at: capturedAt,
                lat: coord?.latitude, lng: coord?.longitude, note: nil
            )
            let saved = try await HOADataStore.insertHOAPhoto(payload)
            photos.append(saved)
            pending.removeAll { $0.id == upload.id }
        } catch {
            setStatus(upload.id, .error(HOAError.from(error).localizedDescription))
        }
    }

    private func setStatus(_ id: UUID, _ status: UploadStatus) {
        if let idx = pending.firstIndex(where: { $0.id == id }) {
            pending[idx].status = status
        }
    }
}

/// The reusable capture grid — drop into any violation/inspection/ARC screen.
struct HOAPhotoCaptureSection: View {
    @ObservedObject var controller: HOAPhotoCaptureController
    var title: String = "Evidence"
    /// Whether the viewer can add new photos here. The server (RLS) only
    /// checks association membership, not per-parent authorization, so this
    /// client-side gate is the first line of defense for board-only
    /// workflows (violations, inspections) until the backend policy is
    /// tightened — set to `false` for viewers who shouldn't be attaching
    /// evidence (e.g. a resident viewing a violation case).
    var allowUpload: Bool = true

    @State private var showCamera = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showViewer = false
    @State private var viewerStartIndex = 0

    private var viewerItems: [PhotoViewerItem] {
        controller.photos.map {
            PhotoViewerItem(id: $0.id, image: nil, url: controller.signedURLs[$0.storage_path], capturedAt: $0.captured_at, sha256: $0.sha256, lat: $0.lat, lng: $0.lng, note: $0.note)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(DS.serif(17)).foregroundStyle(DS.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(Array(controller.photos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        viewerStartIndex = index
                        showViewer = true
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            Group {
                                if let url = controller.signedURLs[photo.storage_path] {
                                    AsyncImage(url: url) { p in
                                        if case .success(let img) = p { img.resizable().aspectRatio(contentMode: .fill) } else { DS.ink.opacity(0.05) }
                                    }
                                } else {
                                    DS.ink.opacity(0.05)
                                }
                            }
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            SealBadge(label: Formatters.truncateHash(photo.sha256, chars: 6))
                                .scaleEffect(0.85)
                                .padding(4)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(DS.ink.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(controller.pending) { upload in
                    ZStack {
                        Image(uiImage: upload.image).resizable().aspectRatio(contentMode: .fill)
                            .aspectRatio(1, contentMode: .fill).clipped().opacity(0.5)
                        switch upload.status {
                        case .error(let message):
                            VStack(spacing: 6) {
                                Text("Failed").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                Text(message).font(.system(size: 8)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center).lineLimit(2)
                                HStack(spacing: 6) {
                                    Button("Retry") { controller.retry(upload) }
                                    Button("Remove") { controller.removePending(upload.id) }
                                }
                                .font(.system(size: 10, weight: .semibold)).buttonStyle(.plain).foregroundStyle(.white)
                            }
                            .padding(6).background(DS.ink.opacity(0.55))
                        default:
                            VStack(spacing: 4) {
                                ProgressView().tint(.white)
                                Text(statusLabel(upload.status)).font(.system(size: 9, weight: .medium)).foregroundStyle(.white)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if allowUpload {
                    Button {
                        Haptics.tap()
                        showCamera = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill").font(.system(size: 22))
                            Text("Add photo").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(DS.brass)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fill)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(DS.brass.opacity(0.4), style: StrokeStyle(lineWidth: 1.6, dash: [6, 5])))
                    }
                    .buttonStyle(.plain)
                }
            }

            if allowUpload {
                PhotosPicker(selection: $pickerSelection, maxSelectionCount: 10, matching: .images) {
                    Text("+ Add from library").font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.brass)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(onCapture: { image in controller.handleCaptured([image]) }, onCancel: {})
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showViewer) {
            PhotoViewerView(items: viewerItems, startIndex: viewerStartIndex)
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
                    controller.handleCaptured(images)
                }
            }
        }
    }

    private func statusLabel(_ status: UploadStatus) -> String {
        switch status {
        case .compressing: return "Compressing\u{2026}"
        case .hashing: return "Hashing\u{2026}"
        case .uploading: return "Uploading\u{2026}"
        case .error: return "Error"
        }
    }
}
