import ActivityKit
import Combine
import CoreLocation
import Foundation
import os

@MainActor
final class LiveTrackingActivityCoordinator: ObservableObject {
    static let shared = LiveTrackingActivityCoordinator()

    struct Diagnostics: Equatable {
        var activitiesEnabled: Bool = false
        var activeWatchCount: Int = 0
        var systemActivityCount: Int = 0
        var lastStateSummary: String = "Not started"
        var lastUpdatedAt: Date?

        var copyText: String {
            [
                "Live Activities enabled: \(activitiesEnabled ? "yes" : "no")",
                "Active watch sessions: \(activeWatchCount)",
                "System Live Activities: \(systemActivityCount)",
                "Last state: \(lastStateSummary)",
                "Last updated: \(lastUpdatedAt?.formatted(date: .abbreviated, time: .standard) ?? "never")"
            ].joined(separator: "\n")
        }
    }

    @Published private(set) var diagnostics = Diagnostics()

    private let logger = Logger(subsystem: "com.halowalk.guardian", category: "LiveActivity")
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?
    private var started = false
    private var lastStateSummary = "Not started"

    private init() {}

    func start() {
        guard !started else {
            refresh()
            return
        }
        started = true

        ContinuousWatchStore.shared.$active
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        PresenceStore.shared.$readings
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        FamilyStore.shared.$members
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        HubStore.shared.$hubs
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        refresh()
    }

    func refresh() {
        Task { await reconcileActivities() }
    }

    private func reconcileActivities() async {
        let myId = FamilyStore.shared.account.memberId
        let active = ContinuousWatchStore.shared
            .watches(by: myId)
            .sorted { $0.startedAt > $1.startedAt }
        let activeIds = Set(active.map(\.id))
        let activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

        guard activitiesEnabled else {
            lastStateSummary = active.isEmpty
                ? "Live Activities disabled; no active watches"
                : "Live Activities disabled for \(active.count) active watch session(s)"
            logger.notice("\(self.lastStateSummary, privacy: .public)")
            updateDiagnostics(activeWatchCount: active.count)
            return
        }

        for activity in Activity<HaloWalkLiveActivityAttributes>.activities
        where !activeIds.contains(activity.attributes.watchId) {
            await activity.end(
                ActivityContent(
                    state: endedState(for: activity),
                    staleDate: Date()
                ),
                dismissalPolicy: .after(Date().addingTimeInterval(60 * 5))
            )
            LaunchLog.step("liveActivity.end \(activity.attributes.watchedName)")
            logger.notice("end \(activity.attributes.watchedName, privacy: .public)")
        }

        for watch in active {
            guard let member = FamilyStore.shared.member(watch.watchedId) else { continue }
            let state = contentState(for: watch, member: member)
            lastStateSummary = "\(member.displayName): \(state.statusLine) · \(state.locationLine)"
            if let activity = Activity<HaloWalkLiveActivityAttributes>.activities.first(where: {
                $0.attributes.watchId == watch.id
            }) {
                await activity.update(
                    ActivityContent(
                        state: state,
                        staleDate: Date().addingTimeInterval(60 * 5)
                    )
                )
                LaunchLog.step("liveActivity.update \(member.displayName)")
                logger.notice("update \(member.displayName, privacy: .public): \(state.statusLine, privacy: .public) | \(state.locationLine, privacy: .public)")
            } else {
                let attributes = HaloWalkLiveActivityAttributes(
                    watchId: watch.id,
                    watchedMemberId: watch.watchedId,
                    watcherId: watch.watcherId,
                    watchedName: member.displayName,
                    watchedInitial: member.initial,
                    accentHex: member.accentColorHex,
                    startedAt: watch.startedAt
                )
                do {
                    _ = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(
                            state: state,
                            staleDate: Date().addingTimeInterval(60 * 5)
                        ),
                        pushType: nil
                    )
                    LaunchLog.step("liveActivity.request \(member.displayName)")
                    logger.notice("request \(member.displayName, privacy: .public): \(state.statusLine, privacy: .public) | \(state.locationLine, privacy: .public)")
                } catch {
                    lastStateSummary = "Request failed: \(error.localizedDescription)"
                    LaunchLog.step("liveActivity.request.failed \(error.localizedDescription)")
                    logger.error("request failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if active.isEmpty {
            lastStateSummary = "No active watch sessions"
        }
        updateDiagnostics(activeWatchCount: active.count)
    }

    private func updateDiagnostics(activeWatchCount: Int) {
        diagnostics = Diagnostics(
            activitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled,
            activeWatchCount: activeWatchCount,
            systemActivityCount: Activity<HaloWalkLiveActivityAttributes>.activities.count,
            lastStateSummary: lastStateSummary,
            lastUpdatedAt: Date()
        )
    }

    private func endedState(
        for activity: Activity<HaloWalkLiveActivityAttributes>
    ) -> HaloWalkLiveActivityAttributes.ContentState {
        HaloWalkLiveActivityAttributes.ContentState(
            statusLine: "Live watch ended",
            locationLine: "\(activity.attributes.watchedName) is no longer being actively watched.",
            freshnessLine: "Stopped now",
            conditionLine: "Open HaloWalk to start again",
            accuracyLine: nil,
            stateKind: .stale,
            progress: nil,
            updatedAt: Date(),
            endsAt: Date()
        )
    }

    private func contentState(
        for watch: ContinuousWatch,
        member: Member
    ) -> HaloWalkLiveActivityAttributes.ContentState {
        let reading = PresenceStore.shared.reading(for: member.id)
        let statusLine = statusLine(member: member, reading: reading)
        let locationLine = locationLine(member: member, reading: reading)
        return HaloWalkLiveActivityAttributes.ContentState(
            statusLine: statusLine,
            locationLine: locationLine,
            freshnessLine: freshnessLine(for: reading),
            conditionLine: watch.describeUntil(
                memberDisplayName: member.displayName,
                hubName: { hubId in HubStore.shared.hubs.first(where: { $0.id == hubId })?.name }
            ),
            accuracyLine: reading.map { Units.accuracy(meters: $0.horizontalAccuracy) },
            stateKind: stateKind(for: reading),
            progress: progress(for: watch),
            updatedAt: Date(),
            endsAt: endDate(for: watch)
        )
    }

    private func statusLine(member: Member, reading: LocationReading?) -> String {
        guard let reading else { return "Locating \(member.displayName)" }
        if isStale(reading) { return "\(member.displayName) was last seen" }
        if let hubId = reading.inHubId,
           let hub = HubStore.shared.hubs.first(where: { $0.id == hubId }) {
            return "\(member.displayName) is at \(hub.name)"
        }
        switch reading.state {
        case .leftOrbit:
            return "\(member.displayName) is away"
        case .wandering, .onCorridor:
            return "\(member.displayName) is moving"
        case .inHalo:
            return "\(member.displayName) is nearby"
        case .noPing, .unknown:
            return "Waiting for \(member.displayName)"
        }
    }

    private func locationLine(member: Member, reading: LocationReading?) -> String {
        guard let reading else { return "Waiting for the next location update." }
        let location = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
        if let hubId = reading.inHubId,
           let hub = HubStore.shared.hubs.first(where: { $0.id == hubId }) {
            return "Inside \(hub.name)'s halo"
        }
        if let nearest = HubStore.shared.nearestHub(to: location, forMember: member.id) {
            return Units.distanceFrom(nearest.meters, hub: nearest.hub.name)
        }
        return "Latest location received"
    }

    private func freshnessLine(for reading: LocationReading?) -> String {
        guard let reading else { return "No live ping yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: reading.timestamp, relativeTo: Date())
        if let battery = reading.batteryPercent {
            return "\(relative) · \(battery)%"
        }
        return relative
    }

    private func stateKind(for reading: LocationReading?) -> TrackingStateKind {
        guard let reading else { return .unknown }
        if isStale(reading) { return .stale }
        if reading.inHubId != nil { return .atHub }
        switch reading.state {
        case .leftOrbit: return .away
        case .wandering, .onCorridor: return .moving
        case .inHalo: return .live
        case .noPing, .unknown: return .unknown
        }
    }

    private func isStale(_ reading: LocationReading) -> Bool {
        Date().timeIntervalSince(reading.timestamp) > 10 * 60
    }

    private func endDate(for watch: ContinuousWatch) -> Date? {
        switch watch.until {
        case .untilTime(let date):
            return date
        case .forDuration(let seconds):
            return watch.startedAt.addingTimeInterval(seconds)
        case .arrivesAtHub, .leavesHub, .manualStop:
            return nil
        }
    }

    private func progress(for watch: ContinuousWatch) -> Double? {
        guard let end = endDate(for: watch) else { return nil }
        let total = end.timeIntervalSince(watch.startedAt)
        guard total > 0 else { return 1 }
        return max(0, min(1, Date().timeIntervalSince(watch.startedAt) / total))
    }
}
