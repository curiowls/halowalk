import Foundation
import CoreLocation
import Combine
import UIKit

/// Evaluates active triggers against incoming location/region events and
/// produces AppNotifications + delivers local notifications. This is the
/// "set & forget" engine the wireframes promise.
///
/// Build 11 implements the geofence-driven conditions (leavesHub, entersHub,
/// awayFromAllHubs). Time-window conditions (lateArrivingAtHub, noPing) get
/// scheduled via timers and ship in Build 12.
@MainActor
final class TriggerEngine {
    static let shared = TriggerEngine()

    private let triggers: TriggerStore = .shared
    private let hubs: HubStore = .shared
    private let family: FamilyStore = .shared
    private let presence: PresenceStore = .shared
    private let notifications: NotificationStore = .shared
    private let delivery: NotificationDelivery = .shared

    /// Per-trigger debounce — last fire time. Triggers can fire at most
    /// once per cooldown window per wearer.
    private var lastFire: [String: Date] = [:]
    private let cooldown: TimeInterval = 60 * 5  // 5 minutes

    /// Pending "leaves hub" timers. Some conditions (e.g. awayFromAllHubs)
    /// only fire after a duration; we hold these here and cancel if the
    /// wearer re-enters before the timer pops.
    private var pendingTimers: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Region events

    /// Called by LocationManager when the wearer enters a hub region.
    func didEnter(hubId: UUID) {
        let wearerId = family.account.memberId
        // Update the wearer's reading state
        var reading = presence.reading(for: wearerId) ?? defaultReading(for: wearerId)
        reading.inHubId = hubId
        reading.state = .inHalo
        reading.timestamp = Date()
        presence.ingest(reading)

        // Cancel any pending "wandering" timers
        pendingTimers.values.forEach { $0.cancel() }
        pendingTimers.removeAll()

        // Fire any matching `entersHub` triggers
        evaluate(eventHubId: hubId, kind: .entered)
    }

    /// Called by LocationManager when the wearer exits a hub region.
    func didExit(hubId: UUID) {
        let wearerId = family.account.memberId
        let stillInside = LocationManager.shared.insideHubIds
        var reading = presence.reading(for: wearerId) ?? defaultReading(for: wearerId)
        if stillInside.isEmpty {
            reading.inHubId = nil
            reading.state = .wandering
        } else if let next = stillInside.first {
            reading.inHubId = next
            reading.state = .inHalo
        }
        reading.timestamp = Date()
        presence.ingest(reading)

        evaluate(eventHubId: hubId, kind: .left)

        // Schedule "awayFromAllHubs" check after the longest configured
        // window — fires only if the wearer is still outside everything
        // when the timer pops.
        if stillInside.isEmpty {
            scheduleAwayFromAllChecks()
        }
    }

    // MARK: - Trigger evaluation

    private enum EventKind { case entered, left }

    private func evaluate(eventHubId: UUID, kind: EventKind) {
        let wearerId = family.account.memberId
        for trigger in triggers.triggers where trigger.enabled
            && trigger.affectsMemberIds.contains(wearerId) {
            switch trigger.condition {
            case .entersHub(let id) where kind == .entered && id == eventHubId:
                fire(trigger: trigger, hubId: eventHubId)
            case .leavesHub(let id) where kind == .left && id == eventHubId:
                fire(trigger: trigger, hubId: eventHubId)
            case .extendedHalo, .sosTapped, .batteryUnder, .noPing,
                 .awayFromAllHubs, .lateArrivingAtHub, .offCorridor,
                 .entersHub, .leavesHub, .devicesDiverged:
                continue
            }
        }
    }

    private func scheduleAwayFromAllChecks() {
        let wearerId = family.account.memberId
        for trigger in triggers.triggers where trigger.enabled
            && trigger.affectsMemberIds.contains(wearerId) {
            if case .awayFromAllHubs(let mins) = trigger.condition {
                let key = "away.\(trigger.id)"
                pendingTimers[key]?.cancel()
                pendingTimers[key] = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(mins) * 60_000_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        // Still outside everything? Fire.
                        if LocationManager.shared.insideHubIds.isEmpty {
                            self.fire(trigger: trigger, hubId: nil)
                        }
                        self.pendingTimers.removeValue(forKey: key)
                    }
                }
            }
        }
    }

    // MARK: - Firing

    private func fire(trigger: Trigger, hubId: UUID?) {
        let key = "\(trigger.id).\(hubId?.uuidString ?? "all")"
        if let last = lastFire[key], Date().timeIntervalSince(last) < cooldown {
            return  // debounced
        }
        lastFire[key] = Date()

        let wearer = family.member(family.account.memberId)
        let hub = hubId.flatMap { id in hubs.hubs.first(where: { $0.id == id }) }

        let (title, body, suggestedRespond, severity, category) = composeContent(
            trigger: trigger, wearer: wearer, hub: hub
        )

        let notification = AppNotification(
            id: UUID(),
            severity: severity,
            category: category,
            title: title,
            body: body,
            timestamp: Date(),
            aboutMemberId: wearer?.id,
            triggeredByTriggerId: trigger.id,
            suggestedRespond: suggestedRespond,
            read: false,
            dismissed: false
        )
        notifications.add(notification)
        delivery.deliver(notification)
    }

    private func composeContent(
        trigger: Trigger, wearer: Member?, hub: Hub?
    ) -> (String, String, AppNotification.RespondKind?, AppNotification.Severity, AppNotification.Category) {
        let name = wearer?.displayName ?? "A wearer"
        let severity: AppNotification.Severity = {
            switch trigger.notifyMode {
            case .critical: return .critical
            case .headsUp:  return .headsUp
            case .quiet:    return .quiet
            }
        }()
        switch trigger.condition {
        case .entersHub:
            return ("\(name) arrived \(hub?.name ?? "their halo")",
                    "Safe at base ♡",
                    nil,
                    severity, .enteredHalo)
        case .leavesHub:
            return ("\(name) left \(hub?.name ?? "the halo")",
                    "Last seen at \(Date().formatted(date: .omitted, time: .shortened))",
                    .quickReply,
                    severity, .leftHalo)
        case .awayFromAllHubs(let mins):
            return ("\(name) is wandering",
                    "Off all halos for \(mins)+ min",
                    .nudgeHome,
                    severity, .wanderingTooLong)
        case .lateArrivingAtHub(_, let mins, _):
            return ("\(name) is late",
                    "Hasn't reached the destination in \(mins) min",
                    .nudgeHome,
                    severity, .lateArriving)
        case .noPing(let mins):
            return ("\(name)'s watch hasn't pinged",
                    "No location update for \(mins)+ min",
                    nil,
                    severity, .noPingFromWatch)
        case .batteryUnder(let pct):
            return ("\(name)'s watch is low",
                    "Battery dropped below \(pct)%",
                    nil,
                    .quiet, .watchBatteryLow)
        case .extendedHalo:
            return ("\(name) extended their halo",
                    "Still exploring ♡",
                    .quickReply,
                    severity, .extendedHalo)
        case .sosTapped:
            return ("⚠ \(name) tapped SOS",
                    "Tap to call or head out",
                    .headOut,
                    .critical, .sos)
        case .offCorridor:
            return ("\(name) left a safe corridor",
                    "Off the planned route",
                    .quickReply,
                    severity, .offCorridor)
        case .devicesDiverged(let m):
            return ("\(name)'s devices are apart",
                    "Phone and watch \(m)+ m apart",
                    .quickReply,
                    severity, .devicesDiverged)
        }
    }

    private func defaultReading(for memberId: UUID) -> LocationReading {
        // Use the first known device for this member, or a synthetic one.
        let firstDeviceId = FamilyStore.shared.devices(for: memberId).first?.id ?? memberId
        return LocationReading(
            memberId: memberId,
            deviceId: firstDeviceId,
            latitude: 0, longitude: 0,
            horizontalAccuracy: 0,
            timestamp: Date(),
            inHubId: nil,
            state: .unknown,
            batteryPercent: nil,
            isOnWrist: nil,
            isMoving: nil
        )
    }
}
