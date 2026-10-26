import Foundation
import Supabase

// Ported from src/lib/queries.ts + the various "use server" actions.ts files —
// a thin, static data-access layer over the Supabase client.

struct PropertyWithStats: Identifiable, Hashable {
    var property: Property
    var moveInPhotoCount: Int
    var moveOutPhotoCount: Int
    var roomCount: Int
    var id: UUID { property.id }
}

enum StatusTone { case neutral, progress, success, brass }

struct PropertyStatusInfo {
    var label: String
    var tone: StatusTone
}

func propertyStatus(_ p: PropertyWithStats) -> PropertyStatusInfo {
    if p.property.move_out_completed_at != nil {
        return PropertyStatusInfo(label: "Move-out documented", tone: .success)
    }
    if p.property.move_in_completed_at != nil {
        return p.property.is_paid
            ? PropertyStatusInfo(label: "Move-in documented \u{b7} Protected", tone: .success)
            : PropertyStatusInfo(label: "Move-in documented", tone: .progress)
    }
    if p.moveInPhotoCount > 0 {
        return PropertyStatusInfo(label: "Move-in in progress", tone: .progress)
    }
    return PropertyStatusInfo(label: "Not started", tone: .neutral)
}

struct RoomWithPhotos: Identifiable, Hashable {
    var room: Room
    var moveInPhotos: [Photo]
    var moveOutPhotos: [Photo]
    var id: UUID { room.id }

    func photos(for phase: Phase) -> [Photo] {
        phase == .move_in ? moveInPhotos : moveOutPhotos
    }
}

struct PropertyDetail {
    var property: Property
    var rooms: [RoomWithPhotos]
    var totalMoveInPhotos: Int
    var totalMoveOutPhotos: Int
}

enum DataStoreError: LocalizedError {
    case notSignedIn
    case notFound
    case freePhotoLimitReached

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Your session expired — please sign in again."
        case .notFound: return "That property could not be found."
        case .freePhotoLimitReached: return "You've hit the free limit of \(FreeTier.photoLimit) photos on this property."
        }
    }
}

enum DataStore {
    static func currentUserID() async throws -> UUID {
        guard let user = supabase.auth.currentUser else { throw DataStoreError.notSignedIn }
        return user.id
    }

    // MARK: Dashboard

    static func fetchPropertiesWithStats() async throws -> [PropertyWithStats] {
        let properties: [Property] = try await supabase.from("properties")
            .select()
            .order("created_at", ascending: false)
            .execute().value

        if properties.isEmpty { return [] }
        let ids = properties.map { $0.id.uuidString }

        async let photosTask: [PhotoStub] = supabase.from("photos")
            .select("property_id, phase")
            .in("property_id", values: ids)
            .execute().value
        async let roomsTask: [RoomStub] = supabase.from("rooms")
            .select("property_id")
            .in("property_id", values: ids)
            .execute().value

        let (photos, rooms) = try await (photosTask, roomsTask)

        return properties.map { p in
            PropertyWithStats(
                property: p,
                moveInPhotoCount: photos.filter { $0.property_id == p.id && $0.phase == .move_in }.count,
                moveOutPhotoCount: photos.filter { $0.property_id == p.id && $0.phase == .move_out }.count,
                roomCount: rooms.filter { $0.property_id == p.id }.count
            )
        }
    }

    // MARK: Property detail

    static func fetchPropertyDetail(propertyId: UUID) async throws -> PropertyDetail? {
        let properties: [Property] = try await supabase.from("properties")
            .select()
            .eq("id", value: propertyId.uuidString)
            .execute().value
        guard let property = properties.first else { return nil }

        async let roomsTask: [Room] = supabase.from("rooms")
            .select()
            .eq("property_id", value: propertyId.uuidString)
            .order("sort", ascending: true)
            .execute().value
        async let photosTask: [Photo] = supabase.from("photos")
            .select()
            .eq("property_id", value: propertyId.uuidString)
            .order("created_at", ascending: true)
            .execute().value

        let (rooms, photos) = try await (roomsTask, photosTask)

        let roomsWithPhotos = rooms.map { r in
            RoomWithPhotos(
                room: r,
                moveInPhotos: photos.filter { $0.room_id == r.id && $0.phase == .move_in },
                moveOutPhotos: photos.filter { $0.room_id == r.id && $0.phase == .move_out }
            )
        }

        return PropertyDetail(
            property: property,
            rooms: roomsWithPhotos,
            totalMoveInPhotos: photos.filter { $0.phase == .move_in }.count,
            totalMoveOutPhotos: photos.filter { $0.phase == .move_out }.count
        )
    }

    static func fetchProperty(propertyId: UUID) async throws -> Property? {
        let properties: [Property] = try await supabase.from("properties")
            .select()
            .eq("id", value: propertyId.uuidString)
            .execute().value
        return properties.first
    }

    // MARK: Create property

    struct NewPropertyInput {
        var nickname: String
        var addressLine1: String
        var addressLine2: String
        var city: String
        var state: String
        var zip: String
        var depositAmountDollars: String
        var leaseStart: String
        var landlordName: String
        var landlordEmail: String
        var rooms: [String]
    }

    static func createProperty(_ input: NewPropertyInput) async throws -> Property {
        let userId = try await currentUserID()
        let depositCents = Double(input.depositAmountDollars).map { Int(($0 * 100).rounded()) }

        let payload = NewPropertyPayload(
            user_id: userId,
            nickname: input.nickname.isEmpty ? nil : input.nickname,
            address_line1: input.addressLine1.isEmpty ? nil : input.addressLine1,
            address_line2: input.addressLine2.isEmpty ? nil : input.addressLine2,
            city: input.city.isEmpty ? nil : input.city,
            state: input.state.isEmpty ? nil : input.state,
            zip: input.zip.isEmpty ? nil : input.zip,
            landlord_name: input.landlordName.isEmpty ? nil : input.landlordName,
            landlord_email: input.landlordEmail.isEmpty ? nil : input.landlordEmail,
            deposit_amount_cents: depositCents,
            lease_start: input.leaseStart.isEmpty ? nil : input.leaseStart
        )

        let created: [Property] = try await supabase.from("properties")
            .insert(payload)
            .select()
            .execute().value
        guard let property = created.first else { throw DataStoreError.notFound }

        let roomNames = input.rooms.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !roomNames.isEmpty {
            let roomPayloads = roomNames.enumerated().map { i, name in
                NewRoomPayload(property_id: property.id, user_id: userId, name: name, sort: i)
            }
            _ = try await supabase.from("rooms").insert(roomPayloads).execute()
        }

        return property
    }

    // MARK: Phase / photo mutations

    static func markPhaseComplete(propertyId: UUID, phase: Phase) async throws {
        let now = Formatters.isoTimestamp()
        let column = phase == .move_in ? "move_in_completed_at" : "move_out_completed_at"
        _ = try await supabase.from("properties")
            .update([column: now])
            .eq("id", value: propertyId.uuidString)
            .execute()
    }

    static func insertPhoto(_ payload: NewPhotoPayload) async throws {
        _ = try await supabase.from("photos").insert(payload).execute()
    }

    static func updatePhotoNote(photoId: UUID, note: String) async throws {
        _ = try await supabase.from("photos")
            .update(NoteUpdatePayload(note: note.isEmpty ? nil : note))
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    static func updatePhotoCondition(photoId: UUID, condition: PhotoCondition) async throws {
        _ = try await supabase.from("photos")
            .update(ConditionUpdatePayload(condition: condition))
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    static func deletePhoto(photoId: UUID, storagePath: String) async throws {
        _ = try? await supabase.storage.from("photos").remove(paths: [storagePath])
        _ = try await supabase.from("photos")
            .delete()
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    static func countExistingPhotos(propertyId: UUID) async throws -> Int {
        let photos: [PhotoStub] = try await supabase.from("photos")
            .select("property_id, phase")
            .eq("property_id", value: propertyId.uuidString)
            .execute().value
        return photos.count
    }

    // MARK: Paid status (set by StoreManager after a verified StoreKit purchase)

    static func setPaid(propertyId: UUID, sessionId: String) async throws {
        _ = try await supabase.from("properties")
            .update(PaidStatusPayload(is_paid: true, stripe_session_id: sessionId))
            .eq("id", value: propertyId.uuidString)
            .execute()
    }

    // MARK: Reports

    static func insertReport(propertyId: UUID, kind: ReportKind, storagePath: String) async throws -> Report {
        let userId = try await currentUserID()
        let payload = NewReportPayload(property_id: propertyId, user_id: userId, kind: kind, storage_path: storagePath)
        let created: [Report] = try await supabase.from("reports")
            .insert(payload)
            .select()
            .execute().value
        guard let report = created.first else { throw DataStoreError.notFound }
        return report
    }

    // MARK: Storage

    static func photoStoragePath(userId: UUID, propertyId: UUID, photoId: UUID) -> String {
        "\(userId.uuidString)/\(propertyId.uuidString)/\(photoId.uuidString).jpg"
    }

    static func reportStoragePath(userId: UUID, propertyId: UUID, kind: ReportKind) -> String {
        "\(userId.uuidString)/\(propertyId.uuidString)/\(kind.rawValue)-\(Int(Date().timeIntervalSince1970 * 1000)).pdf"
    }

    static func uploadPhoto(data: Data, path: String) async throws {
        _ = try await supabase.storage.from("photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
    }

    static func uploadReport(data: Data, path: String) async throws {
        _ = try await supabase.storage.from("reports")
            .upload(path, data: data, options: FileOptions(contentType: "application/pdf", upsert: true))
    }

    static func signedURL(bucket: String, path: String, expiresIn: Int = 3600) async -> URL? {
        try? await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn)
    }

    static func signedURLs(bucket: String, paths: [String], expiresIn: Int = 3600) async -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        guard let results = try? await supabase.storage.from(bucket).createSignedURLs(paths: paths, expiresIn: expiresIn) else {
            return [:]
        }
        var map: [String: URL] = [:]
        for r in results {
            if case let .success(path, signedURL) = r {
                map[path] = signedURL
            }
        }
        return map
    }
}
