import SwiftUI

/// Mark a SwiftUI view as "needs fresh location" — applying this modifier
/// asks the LocationFidelityCoordinator to keep continuous updates running
/// while the view is on screen, and stop when it leaves.
///
/// Two flavors:
///   • `.locationAware()` — coarse, used for map & list screens that just
///     need a moving pin
///   • `.locationAware(.foregroundFine)` — fine, used by the watch's
///     active-navigation Glance where a 10-m bearing matters
///
/// Counter-based, so two screens overlapping (e.g. a sheet over a map)
/// don't fight each other on dismiss.
struct LocationAwareModifier: ViewModifier {
    let fidelity: LocationFidelity

    func body(content: Content) -> some View {
        content
            .onAppear {
                LocationFidelityCoordinator.shared.acquireScreenBoost(fidelity)
            }
            .onDisappear {
                LocationFidelityCoordinator.shared.releaseScreenBoost(fidelity)
            }
    }
}

extension View {
    /// Default to coarse — fine enough for the family map and list.
    func locationAware(_ fidelity: LocationFidelity = .foregroundCoarse) -> some View {
        modifier(LocationAwareModifier(fidelity: fidelity))
    }
}
