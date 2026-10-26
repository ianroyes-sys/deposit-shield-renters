import Foundation
import UIKit

/// Shared plumbing between ReportView and EvidenceView: turns Supabase rows
/// into the UIImage-backed structures PDFReportGenerator expects, then
/// persists the rendered PDF both locally (for the share sheet) and in the
/// `reports` storage bucket (for the `reports` table's audit trail).
enum ReportAssembler {
    static func propertyInfo(property: Property, tenantEmail: String, law: StateDepositLaw?) -> ReportPropertyInfo {
        let line1 = [property.address_line1, property.address_line2].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let line2 = [property.city, property.state, property.zip].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return ReportPropertyInfo(
            displayName: Formatters.propertyDisplayName(property),
            addressLines: [line1, line2].filter { !$0.isEmpty },
            tenantEmail: tenantEmail,
            depositAmountLabel: Formatters.cents(property.deposit_amount_cents),
            dateLabel: Formatters.date(Date()),
            stateName: law?.name,
            stateDeadlineDays: law?.returnDeadlineDays
        )
    }

    static func rooms(detail: PropertyDetail, phase: Phase) async throws -> [ReportRoomData] {
        let allPaths = detail.rooms.flatMap { $0.photos(for: phase).map(\.storage_path) }
        let signed = await DataStore.signedURLs(bucket: "photos", paths: allPaths)
        var result: [ReportRoomData] = []
        for room in detail.rooms {
            var photos: [ReportPhotoData] = []
            for p in room.photos(for: phase) {
                let image = await downloadImage(signed[p.storage_path])
                photos.append(ReportPhotoData(image: image, capturedAt: Formatters.dateTime(p.captured_at), condition: p.condition, note: p.note, sha256: p.sha256))
            }
            result.append(ReportRoomData(name: room.room.name, photos: photos))
        }
        return result
    }

    private static func downloadImage(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// Writes the PDF to a local temp file (for the share sheet) and uploads
    /// it to the `reports` bucket, returning both locations.
    static func persist(data: Data, propertyId: UUID, kind: ReportKind) async throws -> (localURL: URL, storagePath: String) {
        let userId = try await DataStore.currentUserID()
        let storagePath = DataStore.reportStoragePath(userId: userId, propertyId: propertyId, kind: kind)
        try await DataStore.uploadReport(data: data, path: storagePath)

        let fileName = "\(kind.rawValue)-\(propertyId.uuidString.prefix(8)).pdf"
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: localURL, options: .atomic)
        return (localURL, storagePath)
    }
}
