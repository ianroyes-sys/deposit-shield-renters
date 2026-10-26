import Foundation

/// Navigation path for everything inside a single association, once the
/// user has picked (or created/joined) a community.
enum CommunityRoute: Hashable {
    case violations
    case newViolation
    case violationDetail(UUID)
    case ledger
    case inspections
    case newInspectionArea
    case logInspection(areaId: UUID)
    case arc
    case newARC
    case boardRoom
    case newAnnouncement
    case newMotion
    case members
    case codes
}
