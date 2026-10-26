import Foundation
import Supabase

/// Errors the HOA backend raises by name (trigger/RPC `RAISE EXCEPTION`s) —
/// mapped to friendly copy rather than shown as raw Postgres text.
enum HOAError: LocalizedError, Equatable {
    case notAuthenticated
    case invalidJoinCode
    case freeViolationLimit
    case freeAreaLimit
    case notFound
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Your session expired \u{2014} please sign in again."
        case .invalidJoinCode: return "That join code isn't valid. Double-check it with your board."
        case .freeViolationLimit: return "Free communities can track 2 open violations at a time. Upgrade to Communities Pro for unlimited enforcement tracking."
        case .freeAreaLimit: return "Free communities can track 1 inspection area. Upgrade to Communities Pro for unlimited areas."
        case .notFound: return "That record could not be found."
        case .underlying(let message): return message
        }
    }

    static func from(_ error: Error) -> HOAError {
        if let pg = error as? PostgrestError {
            if pg.message.contains(HOAServerError.notAuthenticated) { return .notAuthenticated }
            if pg.message.contains(HOAServerError.invalidJoinCode) { return .invalidJoinCode }
            if pg.message.contains(HOAServerError.freeViolationLimit) { return .freeViolationLimit }
            if pg.message.contains(HOAServerError.freeAreaLimit) { return .freeAreaLimit }
            return .underlying(pg.message)
        }
        return .underlying(error.localizedDescription)
    }
}

/// A membership row joined with its parent association (Postgrest embed).
struct MembershipRow: Codable, Identifiable, Hashable {
    var id: UUID
    var association_id: UUID
    var user_id: UUID
    var role: MemberRole
    var unit_label: String?
    var display_name: String?
    var created_at: String
    var associations: Association
}

enum HOADataStore {
    // MARK: Memberships / associations

    static func fetchMemberships() async throws -> [MembershipRow] {
        do {
            let rows: [MembershipRow] = try await supabase.from("association_members")
                .select("*, associations(*)")
                .order("created_at", ascending: true)
                .execute().value
            return rows
        } catch { throw HOAError.from(error) }
    }

    static func createAssociation(name: String, city: String?, state: String?, displayName: String?, unitLabel: String?) async throws -> UUID {
        do {
            let params = CreateAssociationParams(p_name: name, p_city: city, p_state: state, p_display_name: displayName, p_unit_label: unitLabel)
            let id: UUID = try await supabase.rpc("create_association", params: params).execute().value
            return id
        } catch { throw HOAError.from(error) }
    }

    static func joinAssociation(code: String, displayName: String?, unitLabel: String?) async throws -> UUID {
        do {
            let params = JoinAssociationParams(p_code: code, p_display_name: displayName, p_unit_label: unitLabel)
            let id: UUID = try await supabase.rpc("join_association", params: params).execute().value
            return id
        } catch { throw HOAError.from(error) }
    }

    static func fetchMembers(associationId: UUID) async throws -> [AssociationMember] {
        do {
            return try await supabase.from("association_members")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("created_at", ascending: true)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func removeMember(memberId: UUID) async throws {
        do {
            _ = try await supabase.from("association_members").delete().eq("id", value: memberId.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    /// Board-only per RLS — residents get an empty array back rather than an error.
    static func fetchCodes(associationId: UUID) async throws -> [AssociationCode] {
        do {
            return try await supabase.from("association_codes")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func setAssociationPaid(associationId: UUID, plan: String) async throws {
        do {
            _ = try await supabase.from("associations")
                .update(AssociationPaidPayload(is_paid: true, plan: plan))
                .eq("id", value: associationId.uuidString)
                .execute()
        } catch { throw HOAError.from(error) }
    }

    // MARK: Violations

    static func fetchViolations(associationId: UUID) async throws -> [Violation] {
        do {
            return try await supabase.from("violations")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("opened_at", ascending: false)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func fetchViolation(id: UUID) async throws -> Violation? {
        do {
            let rows: [Violation] = try await supabase.from("violations").select().eq("id", value: id.uuidString).execute().value
            return rows.first
        } catch { throw HOAError.from(error) }
    }

    static func createViolation(associationId: UUID, createdBy: UUID, unitLabel: String?, address: String?, category: String, ruleReference: String?, description: String?) async throws -> Violation {
        do {
            let payload = NewViolationPayload(association_id: associationId, created_by: createdBy, unit_label: unitLabel, address: address, category: category, rule_reference: ruleReference, description: description)
            let created: [Violation] = try await supabase.from("violations").insert(payload).select().execute().value
            guard let v = created.first else { throw HOAError.notFound }
            return v
        } catch { throw HOAError.from(error) }
    }

    static func updateViolationStatus(id: UUID, status: ViolationStatus) async throws {
        do {
            let resolvedAt = status.isClosed ? Formatters.isoTimestamp() : nil
            _ = try await supabase.from("violations")
                .update(ViolationStatusPayload(status: status, resolved_at: resolvedAt))
                .eq("id", value: id.uuidString)
                .execute()
        } catch { throw HOAError.from(error) }
    }

    static func fetchViolationEvents(violationId: UUID) async throws -> [ViolationEvent] {
        do {
            return try await supabase.from("violation_events")
                .select()
                .eq("violation_id", value: violationId.uuidString)
                .order("created_at", ascending: true)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    @discardableResult
    static func insertViolationEvent(violationId: UUID, associationId: UUID, actor: UUID, kind: ViolationEventKind, note: String?, fineAmountCents: Int?, pdfPath: String?) async throws -> ViolationEvent {
        do {
            let payload = NewViolationEventPayload(violation_id: violationId, association_id: associationId, actor: actor, kind: kind, note: note, fine_amount_cents: fineAmountCents, pdf_path: pdfPath)
            let created: [ViolationEvent] = try await supabase.from("violation_events").insert(payload).select().execute().value
            guard let e = created.first else { throw HOAError.notFound }
            return e
        } catch { throw HOAError.from(error) }
    }

    static func fetchAllViolationEvents(associationId: UUID) async throws -> [ViolationEvent] {
        do {
            return try await supabase.from("violation_events")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("created_at", ascending: true)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    // MARK: HOA photos (shared by violations / inspections / arc)

    static func hoaPhotoStoragePath(associationId: UUID, parentType: HOAPhotoParentType, parentId: UUID, photoId: UUID) -> String {
        let folder: String
        switch parentType {
        case .violation: folder = "violations"
        case .inspection: folder = "inspections"
        case .arc: folder = "arc"
        }
        return "assoc/\(associationId.uuidString)/\(folder)/\(parentId.uuidString)/\(photoId.uuidString).jpg"
    }

    static func fetchHOAPhotos(parentType: HOAPhotoParentType, parentId: UUID) async throws -> [HOAPhoto] {
        do {
            return try await supabase.from("hoa_photos")
                .select()
                .eq("parent_type", value: parentType.rawValue)
                .eq("parent_id", value: parentId.uuidString)
                .order("created_at", ascending: true)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func uploadHOAPhoto(data: Data, path: String) async throws {
        do {
            _ = try await supabase.storage.from("photos").upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        } catch { throw HOAError.from(error) }
    }

    @discardableResult
    static func insertHOAPhoto(_ payload: NewHOAPhotoPayload) async throws -> HOAPhoto {
        do {
            let created: [HOAPhoto] = try await supabase.from("hoa_photos").insert(payload).select().execute().value
            guard let p = created.first else { throw HOAError.notFound }
            return p
        } catch { throw HOAError.from(error) }
    }

    static func hoaReportStoragePath(associationId: UUID, category: String, id: UUID) -> String {
        "assoc/\(associationId.uuidString)/reports/\(category)-\(id.uuidString)-\(Int(Date().timeIntervalSince1970)).pdf"
    }

    static func uploadHOAReport(data: Data, path: String) async throws {
        do {
            _ = try await supabase.storage.from("reports").upload(path, data: data, options: FileOptions(contentType: "application/pdf", upsert: true))
        } catch { throw HOAError.from(error) }
    }

    static func signedURL(bucket: String, path: String, expiresIn: Int = 3600) async -> URL? {
        try? await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn)
    }

    // MARK: Inspection areas / inspections

    static func fetchInspectionAreas(associationId: UUID) async throws -> [InspectionArea] {
        do {
            return try await supabase.from("inspection_areas")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("sort", ascending: true)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func createInspectionArea(associationId: UUID, name: String, cadenceDays: Int?, sort: Int) async throws -> InspectionArea {
        do {
            let payload = NewInspectionAreaPayload(association_id: associationId, name: name, cadence_days: cadenceDays, sort: sort)
            let created: [InspectionArea] = try await supabase.from("inspection_areas").insert(payload).select().execute().value
            guard let a = created.first else { throw HOAError.notFound }
            return a
        } catch { throw HOAError.from(error) }
    }

    static func deleteInspectionArea(id: UUID) async throws {
        do {
            _ = try await supabase.from("inspection_areas").delete().eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    static func fetchInspections(associationId: UUID) async throws -> [Inspection] {
        do {
            return try await supabase.from("inspections")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("performed_at", ascending: false)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func createInspection(associationId: UUID, areaId: UUID, performedBy: UUID, condition: InspectionCondition, notes: String?) async throws -> Inspection {
        do {
            let payload = NewInspectionPayload(association_id: associationId, area_id: areaId, performed_by: performedBy, condition: condition, notes: notes)
            let created: [Inspection] = try await supabase.from("inspections").insert(payload).select().execute().value
            guard let i = created.first else { throw HOAError.notFound }
            return i
        } catch { throw HOAError.from(error) }
    }

    static func setInspectionPDFPath(id: UUID, path: String) async throws {
        do {
            _ = try await supabase.from("inspections").update(InspectionPDFPathPayload(pdf_path: path)).eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    // MARK: ARC requests

    static func fetchARCRequests(associationId: UUID) async throws -> [ARCRequest] {
        do {
            return try await supabase.from("arc_requests")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("created_at", ascending: false)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func createARCRequest(associationId: UUID, requester: UUID, unitLabel: String?, title: String, description: String?) async throws -> ARCRequest {
        do {
            let payload = NewARCRequestPayload(association_id: associationId, requester: requester, unit_label: unitLabel, title: title, description: description)
            let created: [ARCRequest] = try await supabase.from("arc_requests").insert(payload).select().execute().value
            guard let r = created.first else { throw HOAError.notFound }
            return r
        } catch { throw HOAError.from(error) }
    }

    static func decideARCRequest(id: UUID, status: ARCStatus, note: String?) async throws {
        do {
            let payload = ARCDecisionPayload(status: status, decision_note: note, decided_at: Formatters.isoTimestamp())
            _ = try await supabase.from("arc_requests").update(payload).eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    static func withdrawARCRequest(id: UUID) async throws {
        do {
            let payload = ARCDecisionPayload(status: .withdrawn, decision_note: nil, decided_at: nil)
            _ = try await supabase.from("arc_requests").update(payload).eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    // MARK: Announcements

    static func fetchAnnouncements(associationId: UUID) async throws -> [Announcement] {
        do {
            return try await supabase.from("announcements")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("pinned", ascending: false)
                .order("created_at", ascending: false)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func createAnnouncement(associationId: UUID, author: UUID, title: String, body: String?, pinned: Bool) async throws -> Announcement {
        do {
            let payload = NewAnnouncementPayload(association_id: associationId, author: author, title: title, body: body, pinned: pinned)
            let created: [Announcement] = try await supabase.from("announcements").insert(payload).select().execute().value
            guard let a = created.first else { throw HOAError.notFound }
            return a
        } catch { throw HOAError.from(error) }
    }

    static func setAnnouncementPinned(id: UUID, pinned: Bool) async throws {
        do {
            _ = try await supabase.from("announcements").update(AnnouncementPinPayload(pinned: pinned)).eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    static func deleteAnnouncement(id: UUID) async throws {
        do {
            _ = try await supabase.from("announcements").delete().eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    // MARK: Motions / voting

    static func fetchMotions(associationId: UUID) async throws -> [Motion] {
        do {
            return try await supabase.from("motions")
                .select()
                .eq("association_id", value: associationId.uuidString)
                .order("created_at", ascending: false)
                .execute().value
        } catch { throw HOAError.from(error) }
    }

    static func createMotion(associationId: UUID, createdBy: UUID, title: String, description: String?, closesAt: String?) async throws -> Motion {
        do {
            let payload = NewMotionPayload(association_id: associationId, created_by: createdBy, title: title, description: description, closes_at: closesAt)
            let created: [Motion] = try await supabase.from("motions").insert(payload).select().execute().value
            guard let m = created.first else { throw HOAError.notFound }
            return m
        } catch { throw HOAError.from(error) }
    }

    static func setMotionStatus(id: UUID, status: MotionStatus) async throws {
        do {
            _ = try await supabase.from("motions").update(MotionStatusPayload(status: status)).eq("id", value: id.uuidString).execute()
        } catch { throw HOAError.from(error) }
    }

    static func fetchVotes(motionId: UUID) async throws -> [MotionVote] {
        do {
            return try await supabase.from("motion_votes").select().eq("motion_id", value: motionId.uuidString).execute().value
        } catch { throw HOAError.from(error) }
    }

    static func fetchAllVotes(associationId: UUID) async throws -> [MotionVote] {
        do {
            return try await supabase.from("motion_votes").select().eq("association_id", value: associationId.uuidString).execute().value
        } catch { throw HOAError.from(error) }
    }

    static func castVote(motionId: UUID, associationId: UUID, voter: UUID, vote: MotionVoteChoice) async throws {
        do {
            let payload = NewMotionVotePayload(motion_id: motionId, association_id: associationId, voter: voter, vote: vote)
            _ = try await supabase.from("motion_votes").insert(payload).execute()
        } catch { throw HOAError.from(error) }
    }
}
