import Foundation

/// A single, typed navigation path shared by the whole authenticated app
/// shell so any screen can push/pop/replace without boolean-flag sprawl.
enum AppRoute: Hashable {
    case newProperty
    case property(UUID)
    case walkthrough(propertyId: UUID, phase: Phase)
    case compare(propertyId: UUID)
    case report(propertyId: UUID)
    case evidence(propertyId: UUID)
}
