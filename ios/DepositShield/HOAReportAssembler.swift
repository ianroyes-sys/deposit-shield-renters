import Foundation
import UIKit

/// Shared plumbing for turning `hoa_photos` rows into the UIImage-backed
/// structures HOAPDFGenerator expects (violations, inspections both need this).
enum HOAReportAssembler {
    static func reportPhotos(for photos: [HOAPhoto]) async -> [ReportPhotoData] {
        let signed = await DataStore.signedURLs(bucket: "photos", paths: photos.map(\.storage_path))
        var result: [ReportPhotoData] = []
        for p in photos {
            let image = await downloadImage(signed[p.storage_path])
            result.append(ReportPhotoData(image: image, capturedAt: Formatters.dateTime(p.captured_at), condition: .good, note: p.note, sha256: p.sha256))
        }
        return result
    }

    private static func downloadImage(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    static func persist(data: Data, associationId: UUID, category: String, id: UUID) async throws -> (localURL: URL, storagePath: String) {
        let storagePath = HOADataStore.hoaReportStoragePath(associationId: associationId, category: category, id: id)
        try await HOADataStore.uploadHOAReport(data: data, path: storagePath)
        let fileName = "\(category)-\(id.uuidString.prefix(8)).pdf"
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: localURL, options: .atomic)
        return (localURL, storagePath)
    }
}
