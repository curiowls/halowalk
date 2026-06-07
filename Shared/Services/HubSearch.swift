import Foundation
import MapKit
import CoreLocation
import Combine

/// Apple Maps-quality autocomplete search. Uses MKLocalSearchCompleter for
/// live partial-match suggestions (the same engine that powers the search
/// bar in Apple Maps). When the user taps a suggestion we fetch the full
/// MKMapItem to get coordinate + POI category for the hub.
@MainActor
final class HubSearchCompleter: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var suggestions: [Suggestion] = []
    @Published private(set) var isSearching: Bool = false

    /// Bias suggestions toward this region so "Belmont Library" prefers
    /// the local one. Set on appear.
    var biasRegion: MKCoordinateRegion? {
        didSet {
            if let r = biasRegion { completer.region = r }
        }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Resolve a tapped suggestion to coordinates + POI category.
    func resolve(_ suggestion: Suggestion) async -> Resolved? {
        let request = MKLocalSearch.Request(completion: suggestion.raw)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            return Resolved(
                name: item.name ?? suggestion.title,
                address: Self.address(from: item),
                coordinate: item.placemark.coordinate,
                poiCategory: item.pointOfInterestCategory
            )
        } catch {
            return nil
        }
    }

    private static func address(from item: MKMapItem) -> String {
        let p = item.placemark
        var parts: [String] = []
        if let thoroughfare = p.thoroughfare {
            if let sub = p.subThoroughfare {
                parts.append("\(sub) \(thoroughfare)")
            } else {
                parts.append(thoroughfare)
            }
        }
        if let locality = p.locality { parts.append(locality) }
        if let admin = p.administrativeArea { parts.append(admin) }
        return parts.joined(separator: ", ")
    }

    struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
        let raw: MKLocalSearchCompletion
        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool { lhs.id == rhs.id }
    }

    struct Resolved {
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
        let poiCategory: MKPointOfInterestCategory?
    }
}

extension HubSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let raw = completer.results
        Task { @MainActor in
            self.suggestions = raw.map {
                Suggestion(title: $0.title, subtitle: $0.subtitle, raw: $0)
            }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }
}
