import SwiftUI

/// A generic full-screen photo item — renter walkthrough photos, HOA
/// evidence photos, and comparison photos all map into this one shape.
struct PhotoViewerItem: Identifiable {
    let id: UUID
    var image: UIImage?
    var url: URL?
    var capturedAt: String
    var sha256: String
    var lat: Double?
    var lng: Double?
    var note: String?
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer with a toggleable
/// hash / timestamp / GPS evidence overlay.
struct PhotoViewerView: View {
    let items: [PhotoViewerItem]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showOverlay = true

    init(items: [PhotoViewerItem], startIndex: Int) {
        self.items = items
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    ZoomableImage(item: item)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() } }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    Spacer()
                    if items.count > 1 {
                        Text("\(currentIndex + 1) / \(items.count)")
                            .font(DS.mono(12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer()

                if showOverlay, items.indices.contains(currentIndex) {
                    overlayPanel(items[currentIndex])
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .statusBarHidden()
    }

    private func overlayPanel(_ item: PhotoViewerItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 12)).foregroundStyle(DS.brassLight)
                Text(Formatters.truncateHash(item.sha256, chars: 12)).font(DS.mono(11.5)).foregroundStyle(.white)
            }
            Label(Formatters.dateTime(item.capturedAt), systemImage: "clock")
                .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.85))
            if let lat = item.lat, let lng = item.lng {
                Label(String(format: "%.5f, %.5f", lat, lng), systemImage: "location.fill")
                    .font(DS.mono(11.5)).foregroundStyle(.white.opacity(0.7))
            }
            if let note = item.note, !note.isEmpty {
                Text(note).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.9)).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        )
    }
}

private struct ZoomableImage: View {
    let item: PhotoViewerItem

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, min(lastScale * value, 5))
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= 1 {
                                    withAnimation { scale = 1; offset = .zero; lastOffset = .zero }
                                    lastScale = 1
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                        } else {
                            scale = 2.5; lastScale = 2.5
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let image = item.image {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
        } else if let url = item.url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fit)
                case .failure: Image(systemName: "photo").font(.system(size: 40)).foregroundStyle(.white.opacity(0.3))
                default: ProgressView().tint(.white)
                }
            }
        } else {
            Image(systemName: "photo").font(.system(size: 40)).foregroundStyle(.white.opacity(0.3))
        }
    }
}
