import Foundation

// Mirrors src/lib/types.ts exactly — property names match Postgres column
// names (snake_case) so Codable needs no key mapping against PostgREST JSON.

enum Phase: String, Codable, CaseIterable, Hashable {
    case move_in = "move_in"
    case move_out = "move_out"

    var label: String { self == .move_in ? "Move-in" : "Move-out" }
}

enum PhotoCondition: String, Codable, CaseIterable, Hashable {
    case good, fair, damaged

    var label: String { rawValue.capitalized }
}

enum ReportKind: String, Codable, Hashable {
    case move_in = "move_in"
    case move_out = "move_out"
    case evidence_packet = "evidence_packet"
}

struct Property: Codable, Identifiable, Hashable {
    var id: UUID
    var user_id: UUID
    var nickname: String?
    var address_line1: String?
    var address_line2: String?
    var city: String?
    var state: String?
    var zip: String?
    var landlord_name: String?
    var landlord_email: String?
    var deposit_amount_cents: Int?
    var lease_start: String?
    var move_in_completed_at: String?
    var move_out_completed_at: String?
    var is_paid: Bool
    var stripe_session_id: String?
    var created_at: String
}

struct Room: Codable, Identifiable, Hashable {
    var id: UUID
    var property_id: UUID
    var user_id: UUID
    var name: String
    var sort: Int
    var created_at: String
}

struct Photo: Codable, Identifiable, Hashable {
    var id: UUID
    var property_id: UUID
    var room_id: UUID
    var user_id: UUID
    var phase: Phase
    var storage_path: String
    var sha256: String
    var captured_at: String
    var lat: Double?
    var lng: Double?
    var note: String?
    var condition: PhotoCondition
    var created_at: String
}

struct Report: Codable, Identifiable, Hashable {
    var id: UUID
    var property_id: UUID
    var user_id: UUID
    var kind: ReportKind
    var storage_path: String?
    var sent_to: String?
    var sent_at: String?
    var created_at: String
}

let DEFAULT_ROOM_NAMES = ["Entry", "Living Room", "Kitchen", "Bedroom", "Bathroom"]

// MARK: - Insert / update payloads (Postgres fills id/created_at defaults)

struct NewPropertyPayload: Encodable {
    var user_id: UUID
    var nickname: String?
    var address_line1: String?
    var address_line2: String?
    var city: String?
    var state: String?
    var zip: String?
    var landlord_name: String?
    var landlord_email: String?
    var deposit_amount_cents: Int?
    var lease_start: String?
}

struct NewRoomPayload: Encodable {
    var property_id: UUID
    var user_id: UUID
    var name: String
    var sort: Int
}

struct RoomRenamePayload: Encodable {
    var name: String
    var sort: Int
}

struct NewPhotoPayload: Encodable {
    var id: UUID
    var property_id: UUID
    var room_id: UUID
    var user_id: UUID
    var phase: Phase
    var storage_path: String
    var sha256: String
    var captured_at: String
    var lat: Double?
    var lng: Double?
    var condition: PhotoCondition
}

struct NoteUpdatePayload: Encodable {
    var note: String?
}

struct ConditionUpdatePayload: Encodable {
    var condition: PhotoCondition
}

struct NewReportPayload: Encodable {
    var property_id: UUID
    var user_id: UUID
    var kind: ReportKind
    var storage_path: String?
}

struct PaidStatusPayload: Encodable {
    var is_paid: Bool
    var stripe_session_id: String?
}

// Slim row shapes for the aggregate stats query (mirrors the `.select("property_id, phase")`
// / `.select("property_id")` partial selects in queries.ts).
struct PhotoStub: Codable, Hashable {
    var property_id: UUID
    var phase: Phase
}

struct RoomStub: Codable, Hashable {
    var property_id: UUID
}
