import SwiftUI
import UIKit

@main
struct HaloWalkApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var familyStore = FamilyStore.shared
    @StateObject private var hubStore = HubStore.shared
    @StateObject private var notificationStore = NotificationStore.shared
    @StateObject private var triggerStore = TriggerStore.shared
    @StateObject private var presenceStore = PresenceStore.shared
    @StateObject private var notificationDelivery = NotificationDelivery.shared

    @AppStorage("halowalk.onboarding.complete") private var onboardingComplete = false

    /// Pilot kill-switches. If a launch is freezing, the user can disable any
    /// of these from Privacy & permissions → Diagnostics, then relaunch.
    @AppStorage("halowalk.safe.locationStart") private var safeLocationStart = true
    @AppStorage("halowalk.safe.regionMonitoring") private var safeRegionMonitoring = true
    @AppStorage("halowalk.safe.notifications") private var safeNotifications = true
    @AppStorage("halowalk.safe.watchConnectivity") private var safeWatchConnectivity = true
    @AppStorage("halowalk.safe.cloudSync") private var safeCloudSync = true

    init() {
        LaunchLog.reset()
        LaunchLog.step("app.init")

        let paperUIColor = UIColor(
            red: 251.0 / 255.0, green: 248.0 / 255.0, blue: 242.0 / 255.0, alpha: 1.0
        )
        UIWindow.appearance().backgroundColor = paperUIColor

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = paperUIColor
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        LaunchLog.step("app.init.complete")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    RootTabView()
                } else {
                    OnboardingFlow()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.palette.paper.ignoresSafeArea())
            .environmentObject(themeManager)
            .environmentObject(locationManager)
            .environmentObject(familyStore)
            .environmentObject(hubStore)
            .environmentObject(notificationStore)
            .environmentObject(triggerStore)
            .environmentObject(presenceStore)
            .environmentObject(notificationDelivery)
            .environment(\.theme, themeManager.theme)
            .preferredColorScheme(.light)
            .task {
                await deferredActivations()
            }
        }
    }

    /// Run all the heavy / permission-requesting subsystem activations
    /// AFTER the first frame has been painted. iOS 26 has been observed to
    /// hang the watchdog timer if WCSession.activate() / region monitoring
    /// fires synchronously during launch. A small delay lets the UI render
    /// and clears the watchdog window. Each subsystem is wrapped in a
    /// breadcrumb + kill-switch so the user can disable any one of them if
    /// it turns out to be the freeze culprit.
    private func deferredActivations() async {
        LaunchLog.step("app.task.begin")
        // Let SwiftUI render before any heavy work.
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        LaunchLog.step("app.task.afterDelay")

        // Build A: re-check Sign in with Apple credential state. If the
        // user revoked HaloWalk's Apple ID access in System Settings,
        // this drops us back to signed-out so the UI is honest.
        AppleAuthManager.shared.revalidateOnLaunch()
        LaunchLog.step("appleAuth.revalidate")

        if safeLocationStart {
            LaunchLog.step("location.start.begin")
            // Build 23: tier-driven location services. The Coordinator
            // owns "what fidelity should be running right now"; the
            // LocationManager owns "how to make CLLocationManager match."
            // applyFidelity is no longer called directly — the
            // coordinator's start() does an initial recompute.
            LocationFidelityCoordinator.shared.start()
            // Forward CLLocation updates → PresenceStore so the local
            // user's pin actually moves on the family map. Throttled.
            IPhoneLocationReporter.shared.start()
            LaunchLog.step("location.start.complete")
        } else {
            LaunchLog.step("location.start.SKIPPED (safe-mode flag off)")
        }

        if safeRegionMonitoring {
            LaunchLog.step("regions.start.begin")
            MonitoringCoordinator.shared.start()
            LaunchLog.step("regions.start.complete")
        } else {
            LaunchLog.step("regions.start.SKIPPED (safe-mode flag off)")
        }

        if safeNotifications {
            LaunchLog.step("notifications.permission.begin")
            await notificationDelivery.requestPermission()
            LaunchLog.step("notifications.permission.complete")
        } else {
            LaunchLog.step("notifications.permission.SKIPPED")
        }

        if safeWatchConnectivity {
            LaunchLog.step("wcsession.activate.begin")
            WatchSync.shared.activate()
            WatchSyncCoordinator.shared.start()
            LaunchLog.step("wcsession.activate.complete")
        } else {
            LaunchLog.step("wcsession.activate.SKIPPED (safe-mode flag off)")
        }

        // Build B: CloudKit sync. Gated behind a kill-switch like the
        // other heavy subsystems — if CKSyncEngine ever hangs a launch
        // the user can disable it from Privacy & permissions and relaunch.
        if safeCloudSync {
            LaunchLog.step("cloudSync.start.begin")
            HaloCloudSync.shared.start()
            LaunchLog.step("cloudSync.start.complete")
        } else {
            LaunchLog.step("cloudSync.start.SKIPPED (safe-mode flag off)")
        }

        // Forward-geocode seed addresses to real Apple Maps coordinates so
        // pin positions agree with the address text. Runs once per install.
        LaunchLog.step("hubs.geocode.begin")
        await hubStore.geocodeSeedHubsIfNeeded()
        LaunchLog.step("hubs.geocode.complete")

        LaunchLog.step("app.task.complete")
    }
}
