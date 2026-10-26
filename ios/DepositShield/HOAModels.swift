import Foundation

// Mirrors supabase/migrations/0004_hoa_communities.sql exactly — property
// names match Postgres column names so Codable needs no key mapping.

enum MemberRole: String, Codable, Hashable {
    case board, resident
}

enum ViolationStatus: String, Codable, CaseIterable, Hashable {
    case open, courtesy_sent, warning_sent, fine_issued, resolved, dismissed

    var label: String {
        switch self {
        case .open: return "Open"
        case .courtesy_sent: return "Courtesy sent"
        case .warning_sent: return "Warning sent"
        case .fine_issued: return "Fine issued"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }

    var isClosed: Bool { self == .resolved || self == .dismissed }
}

enum ViolationCategory: String, CaseIterable, Identifiable, Hashable {
    case landscaping = "Landscaping"
    case parking = "Parking"
    case exterior = "Exterior"
    case trash = "Trash"
    case pets = "Pets"
    case noise = "Noise"
    case architectural = "Architectural"
    case other = "Other"

    var id: String { rawValue }
}

enum ViolationEventKind: String, Codable, Hashable {
    case courtesy_notice, warning, fine, comment, resolved, dismissed
}

enum HOAPhotoParentType: String, Codable, Hashable {
    case violation, inspection, arc
}

enum InspectionCondition: String, Codable, CaseIterable, Hashable {
    case good, fair, attention

    var label: String { rawValue.capitalized }
}

enum ARCStatus: String, Codable, CaseIterable, Hashable {
    case pending, approved, denied, withdrawn

    var label: String { rawValue.capitalized }
}

enum MotionStatus: String, Codable, CaseIterable, Hashable {
    case open, passed, failed, withdrawn

    var label: String { rawValue.capitalized }
}

enum MotionVoteChoice: String, Codable, CaseIterable, Hashable {
    case yes, no, abstain
}

struct Association: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var city: String?
    var state: String?
    var created_by: UUID
    var is_paid: Bool
    var plan: String?
    var created_at: String
}

struct AssociationMember: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var user_id: UUID
    var role: MemberRole
    var unit_label: String?
    var display_name: String?
    var created_at: String
}

struct AssociationCode: Codable, Hashable {
    var association_id: UUID
    var role: MemberRole
    var code: String
}

struct Violation: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var created_by: UUID
    var unit_label: String?
    var address: String?
    var category: String
    var rule_reference: String?
    var description: String?
    var status: ViolationStatus
    var opened_at: String
    var resolved_at: String?
}

struct ViolationEvent: Codable, Identifiable, Hashable {
    var id: UUID
    var violation_id: UUID
    var association_id: UUID
    var actor: UUID
    var kind: ViolationEventKind
    var note: String?
    var fine_amount_cents: Int?
    var pdf_path: String?
    var created_at: String
}

struct HOAPhoto: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var parent_type: HOAPhotoParentType
    var parent_id: UUID
    var uploaded_by: UUID
    var storage_path: String
    var sha256: String
    var captured_at: String
    var lat: Double?
    var lng: Double?
    var note: String?
    var created_at: String
}

struct InspectionArea: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var name: String
    var cadence_days: Int?
    var sort: Int
}

struct Inspection: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var area_id: UUID
    var performed_by: UUID
    var performed_at: String
    var condition: InspectionCondition
    var notes: String?
    var pdf_path: String?
}

struct ARCRequest: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var requester: UUID
    var unit_label: String?
    var title: String
    var description: String?
    var status: ARCStatus
    var decision_note: String?
    var decided_at: String?
    var created_at: String
}

struct Announcement: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var author: UUID
    var title: String
    var body: String?
    var pinned: Bool
    var created_at: String
}

struct Motion: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var created_by: UUID
    var title: String
    var description: String?
    var status: MotionStatus
    var closes_at: String?
    var created_at: String
}

struct MotionVote: Codable, Identifiable, Hashable {
    var id: UUID
    var motion_id: UUID
    var association_id: UUID
    var voter: UUID
    var vote: MotionVoteChoice
    var created_at: String
}

// MARK: - Insert / update payloads

struct NewViolationPayload: Encodable {
    var association_id: UUID
    var created_by: UUID
    var unit_label: String?
    var address: String?
    var category: String
    var rule_reference: String?
    var description: String?
}

struct ViolationStatusPayload: Encodable {
    var status: ViolationStatus
    var resolved_at: String?
}

struct NewViolationEventPayload: Encodable {
    var violation_id: UUID
    var association_id: UUID
    var actor: UUID
    var kind: ViolationEventKind
    var note: String?
    var fine_amount_cents: Int?
    var pdf_path: String?
}

struct NewHOAPhotoPayload: Encodable {
    var id: UUID
    var association_id: UUID
    var parent_type: HOAPhotoParentType
    var parent_id: UUID
    var uploaded_by: UUID
    var storage_path: String
    var sha256: String
    var captured_at: String
    var lat: Double?
    var lng: Double?
    var note: String?
}

struct NewInspectionAreaPayload: Encodable {
    var association_id: UUID
    var name: String
    var cadence_days: Int?
    var sort: Int
}

struct NewInspectionPayload: Encodable {
    var association_id: UUID
    var area_id: UUID
    var performed_by: UUID
    var condition: InspectionCondition
    var notes: String?
}

struct InspectionPDFPathPayload: Encodable {
    var pdf_path: String
}

struct NewARCRequestPayload: Encodable {
    var association_id: UUID
    var requester: UUID
    var unit_label: String?
    var title: String
    var description: String?
}

struct ARCDecisionPayload: Encodable {
    var status: ARCStatus
    var decision_note: String?
    var decided_at: String?
}

struct NewAnnouncementPayload: Encodable {
    var association_id: UUID
    var author: UUID
    var title: String
    var body: String?
    var pinned: Bool
}

struct AnnouncementPinPayload: Encodable {
    var pinned: Bool
}

struct NewMotionPayload: Encodable {
    var association_id: UUID
    var created_by: UUID
    var title: String
    var description: String?
    var closes_at: String?
}

struct MotionStatusPayload: Encodable {
    var status: MotionStatus
}

struct NewMotionVotePayload: Encodable {
    var motion_id: UUID
    var association_id: UUID
    var voter: UUID
    var vote: MotionVoteChoice
}

struct AssociationPaidPayload: Encodable {
    var is_paid: Bool
    var plan: String?
}

// MARK: - RPC params

struct CreateAssociationParams: Encodable {
    var p_name: String
    var p_city: String?
    var p_state: String?
    var p_display_name: String?
    var p_unit_label: String?
}

struct JoinAssociationParams: Encodable {
    var p_code: String
    var p_display_name: String?
    var p_unit_label: String?
}

// MARK: - Known server-raised error codes

enum HOAServerError {
    static let notAuthenticated = "NOT_AUTHENTICATED"
    static let invalidJoinCode = "INVALID_JOIN_CODE"
    static let freeViolationLimit = "FREE_VIOLATION_LIMIT_REACHED"
    static let freeAreaLimit = "FREE_AREA_LIMIT_REACHED"
}
