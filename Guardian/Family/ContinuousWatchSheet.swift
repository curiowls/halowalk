import SwiftUI

/// "Watch [Member] until ___" picker. Five options, mapped to the
/// `UntilCondition` enum:
///   • Until they arrive at a chosen hub
///   • Until they leave a chosen hub
///   • For 30 min / 1 hr / 2 hr / 4 hr
///   • Until a specific time today
///   • Until I stop manually
struct ContinuousWatchSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore

    let watchedMemberId: UUID

    @State private var pickedHubId: UUID?
    @State private var pickedHubMode: HubMode = .arrive
    @State private var pickedDuration: TimeInterval = 30 * 60
    @State private var pickedTime: Date = Date().addingTimeInterval(60 * 60)

    private var watched: Member? { familyStore.member(watchedMemberId) }
    private var watcherId: UUID { familyStore.account.memberId }
    private var assignedHubs: [Hub] {
        hubStore.hubs.filter { $0.assignedMemberIds.contains(watchedMemberId) }
    }

    private enum HubMode: String, CaseIterable {
        case arrive = "arrives at"
        case leave  = "leaves"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let watched {
                    Section {
                        HStack(spacing: 10) {
                            Circle().fill(watched.accentColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(watched.initial)
                                        .font(theme.typography.font(.handTight, size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            VStack(alignment: .leading) {
                                Text("Watching \(watched.displayName)")
                                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                                Text("Boosts location updates while active.")
                                    .font(theme.typography.font(.handFlow, size: 12))
                                    .foregroundColor(theme.palette.ink3)
                            }
                        }
                    }
                }

                if !assignedHubs.isEmpty {
                    Section("Until they arrive / leave a hub") {
                        Picker("When", selection: $pickedHubMode) {
                            ForEach(HubMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker("Hub", selection: $pickedHubId) {
                            Text("None").tag(UUID?.none)
                            ForEach(assignedHubs) { h in
                                Text(h.name).tag(UUID?.some(h.id))
                            }
                        }
                        if let hubId = pickedHubId {
                            Button {
                                start(.hub(hubId, mode: pickedHubMode))
                            } label: {
                                Text("Start watching")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }

                Section("For a fixed duration") {
                    Picker("Duration", selection: $pickedDuration) {
                        Text("30 min").tag(TimeInterval(30 * 60))
                        Text("1 hour").tag(TimeInterval(60 * 60))
                        Text("2 hours").tag(TimeInterval(2 * 60 * 60))
                        Text("4 hours").tag(TimeInterval(4 * 60 * 60))
                    }
                    .pickerStyle(.segmented)
                    Button {
                        start(.duration(pickedDuration))
                    } label: {
                        Text("Start watching")
                            .fontWeight(.bold)
                    }
                }

                Section("Until a specific time") {
                    DatePicker("Stop at",
                               selection: $pickedTime,
                               displayedComponents: .hourAndMinute)
                    Button {
                        start(.time(pickedTime))
                    } label: {
                        Text("Start watching")
                            .fontWeight(.bold)
                    }
                }

                Section {
                    Button {
                        start(.manual)
                    } label: {
                        Text("Start watching — until I stop")
                            .fontWeight(.bold)
                    }
                } footer: {
                    Text("Active watches keep running during quiet hours and can boost your watched person's device too.")
                        .font(theme.typography.font(.handFlow, size: 12))
                }
            }
            .navigationTitle("Watch live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private enum Choice {
        case hub(UUID, mode: HubMode)
        case duration(TimeInterval)
        case time(Date)
        case manual
    }

    private func start(_ choice: Choice) {
        let until: UntilCondition = {
            switch choice {
            case .hub(let id, .arrive): return .arrivesAtHub(hubId: id)
            case .hub(let id, .leave):  return .leavesHub(hubId: id)
            case .duration(let s):      return .forDuration(seconds: s)
            case .time(let d):          return .untilTime(date: d)
            case .manual:               return .manualStop
            }
        }()
        let watch = ContinuousWatch(
            id: UUID(),
            watcherId: watcherId,
            watchedId: watchedMemberId,
            until: until,
            startedAt: Date()
        )
        ContinuousWatchStore.shared.start(watch)
        // Try to bump the watched device's tier too. Only the paired-watch
        // path works in Build 23; iPhone↔iPhone needs CloudKit (Build 24).
        WatchSync.shared.sendBoostRequest(
            forMemberIds: [watchedMemberId],
            fidelity: .foregroundCoarse,
            ttl: 60 * 60 * 4   // 4-hour expiry, will be replaced/extended on next foreground tick
        )
        dismiss()
    }
}
