import Foundation

/// Directed edge in the family graph: `watcherId` watches over `watchedId`.
/// The same Member can appear as both watcher and watched in different
/// relationships — e.g. a teenager who watches a younger sibling AND is
/// watched by their parents.
struct Relationship: Identifiable, Codable, Hashable {
    let id: UUID
    var watcherId: UUID
    var watchedId: UUID
    /// Optional label for the relationship — e.g. "Mom watches Andrew"
    var label: String?
    var createdAt: Date
}
