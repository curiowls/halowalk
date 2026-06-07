import SwiftUI
import MapKit
import CoreLocation

/// Adds a new hub. Two creation paths:
///   • Search (default) — MKLocalSearchCompleter live suggestions, same as
///     Apple Maps. Type a partial name → tap a suggestion → its coordinates
///     and POI category come from Apple Maps directly.
///   • "Use where I'm standing" — drop at current GPS coordinate.
///
/// Configure stage previews the picked place on a small map, lets the user
/// adjust the icon (which carries its own pre-assigned color), set halo
/// radius, and assign which Members it tracks.
struct AddHubSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var search = HubSearchCompleter()

    enum Stage { case pick, configure }
    @State private var stage: Stage = .pick

    // Picked location
    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @State private var pickedAddress: String = ""

    // Editable fields in configure stage
    @State private var name: String = ""
    @State private var iconOption: HubIconCatalog.Option = HubIconCatalog.fallback
    @State private var haloMeters: Double = 80
    @State private var assignedMembers: Set<UUID> = []
    @State private var showIconPicker: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick: pickStage
                case .configure: configureStage
                }
            }
            .navigationTitle(stage == .pick ? "Add a hub" : "Set up the hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(stage == .pick ? "Cancel" : "Back") {
                        if stage == .pick { dismiss() } else { stage = .pick }
                    }
                }
                if stage == .configure {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { save() }
                            .disabled(!canSave)
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selected: $iconOption)
                    .presentationDetents([.medium])
            }
        }
        .onAppear {
            if let loc = locationManager.current {
                search.biasRegion = MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
        }
    }

    // MARK: - Stage: pick (autocomplete)

    @ViewBuilder
    private var pickStage: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(theme.palette.ink3)
                TextField("Search address or place", text: $search.query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !search.query.isEmpty {
                    Button { search.query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.palette.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.palette.paper2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.palette.lineSoft, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if search.query.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick add")
                            .font(theme.typography.font(.handTight, size: 11))
                            .tracking(0.6)
                            .foregroundColor(theme.palette.ink3)
                            .padding(.horizontal, 4)
                        CurrentLocationCard {
                            pickCurrentLocation()
                        }
                        Text("Or search for an address or place above. Suggestions update as you type, like Apple Maps.")
                            .font(theme.typography.font(.handFlow, size: 13))
                            .foregroundColor(theme.palette.ink3)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        if search.suggestions.isEmpty {
                            Text("Keep typing — suggestions appear as you go.")
                                .font(theme.typography.font(.handFlow, size: 13))
                                .foregroundColor(theme.palette.ink3)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(search.suggestions) { suggestion in
                                Button { Task { await pickSuggestion(suggestion) } } label: {
                                    SuggestionRow(suggestion: suggestion)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func pickCurrentLocation() {
        guard let loc = locationManager.current else { return }
        pickedCoordinate = loc.coordinate
        pickedAddress = ""
        name = ""
        iconOption = HubIconCatalog.fallback
        haloMeters = 80
        stage = .configure
    }

    private func pickSuggestion(_ suggestion: HubSearchCompleter.Suggestion) async {
        guard let resolved = await search.resolve(suggestion) else { return }
        pickedCoordinate = resolved.coordinate
        pickedAddress = resolved.address
        name = resolved.name
        iconOption = HubIconCatalog.option(forPOI: resolved.poiCategory)
        haloMeters = 80
        stage = .configure
    }

    // MARK: - Stage: configure

    @ViewBuilder
    private var configureStage: some View {
        Form {
            Section("Name") {
                HStack(spacing: 10) {
                    Button { showIconPicker = true } label: {
                        ZStack {
                            Circle().fill(iconOption.color)
                            Circle().stroke(theme.palette.line, lineWidth: 1.5)
                            HubIconView(icon: iconOption.systemName, size: 16, color: theme.palette.paper)
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    TextField("Name", text: $name)
                }
                Text("Tap the circle to change the icon. The color is paired with the icon.")
                    .font(theme.typography.font(.handFlow, size: 12))
                    .foregroundColor(theme.palette.ink3)
            }

            if let coord = pickedCoordinate {
                Section("Location") {
                    HubMapPreview(
                        coordinate: coord,
                        haloRadiusMeters: haloMeters,
                        color: iconOption.color
                    )
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    if !pickedAddress.isEmpty {
                        Text(pickedAddress)
                            .font(theme.typography.font(.handFlow, size: 13))
                    }
                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                        .font(theme.typography.font(.mono, size: 11))
                        .foregroundColor(theme.palette.ink3)
                }
            }

            Section("Halo radius — \(Units.radius(meters: haloMeters))") {
                Slider(value: $haloMeters, in: 20...500, step: 10)
            }

            Section("Who uses this place?") {
                if familyStore.watchedMembers.isEmpty {
                    Text("Add a wearer first.")
                        .font(theme.typography.font(.handFlow, size: 13))
                        .foregroundColor(theme.palette.ink3)
                } else {
                    ForEach(familyStore.watchedMembers) { wearer in
                        memberRow(wearer)
                    }
                    Text(assignedMembers.isEmpty
                         ? "No members selected — this hub will apply to everyone."
                         : "\(assignedMembers.count) member\(assignedMembers.count == 1 ? "" : "s") selected.")
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }
            }
        }
    }

    @ViewBuilder
    private func memberRow(_ wearer: Member) -> some View {
        HStack {
            Circle().fill(wearer.accentColor).frame(width: 12, height: 12)
            Text(wearer.displayName)
            Spacer()
            if assignedMembers.contains(wearer.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.palette.haloGreen)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(theme.palette.ink3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if assignedMembers.contains(wearer.id) {
                assignedMembers.remove(wearer.id)
            } else {
                assignedMembers.insert(wearer.id)
            }
        }
    }

    private var canSave: Bool {
        pickedCoordinate != nil &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard let coord = pickedCoordinate else { return }
        var hub = hubStore.dropHubAtCurrentLocation(
            named: name.trimmingCharacters(in: .whitespaces),
            icon: iconOption.systemName,
            coordinate: coord,
            haloMeters: haloMeters,
            colorHex: iconOption.colorHex,
            assignedTo: Array(assignedMembers),
            createdBy: familyStore.account.memberId
        )
        if !pickedAddress.isEmpty {
            hub.address = pickedAddress
            hubStore.update(hub)
        }
        dismiss()
    }
}

// MARK: - Subviews

private struct CurrentLocationCard: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var locationManager: LocationManager
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 22))
                    .foregroundColor(theme.palette.ink2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use where I'm standing")
                        .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                        .foregroundColor(theme.palette.ink)
                    Text(locationLabel)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.palette.ink3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sketchBorder(padding: 0)
        }
        .buttonStyle(.plain)
        .disabled(locationManager.current == nil)
    }
    private var locationLabel: String {
        guard let loc = locationManager.current else { return "Waiting for GPS…" }
        return String(format: "%.5f, %.5f · %@",
                      loc.coordinate.latitude, loc.coordinate.longitude,
                      Units.accuracy(meters: loc.horizontalAccuracy))
    }
}

private struct SuggestionRow: View {
    @Environment(\.theme) var theme
    let suggestion: HubSearchCompleter.Suggestion
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(theme.palette.ink2)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(theme.typography.font(.handTight, size: 14, weight: .bold))
                    .foregroundColor(theme.palette.ink)
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle)
                        .font(theme.typography.font(.handFlow, size: 12))
                        .foregroundColor(theme.palette.ink3)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.palette.ink3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchBorder(seed: suggestion.title.hashValue, padding: 0)
    }
}

/// Small read-only Map preview around a coordinate, with a halo overlay.
struct HubMapPreview: View {
    let coordinate: CLLocationCoordinate2D
    let haloRadiusMeters: Double
    let color: Color

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            MapCircle(center: coordinate, radius: haloRadiusMeters)
                .foregroundStyle(color.opacity(0.18))
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            Marker("", coordinate: coordinate)
                .tint(color)
        }
        .mapStyle(.standard(elevation: .flat))
        .allowsHitTesting(false)
    }
}

/// Sheet for picking an icon. Each icon has a fixed color shown on the
/// selection circle so the user can preview at a glance.
struct IconPickerSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: HubIconCatalog.Option

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                    ForEach(HubIconCatalog.defaults) { option in
                        Button {
                            selected = option
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().fill(option.color)
                                    Circle().stroke(theme.palette.line, lineWidth: option.id == selected.id ? 2.5 : 1.2)
                                    HubIconView(icon: option.systemName, size: 18, color: theme.palette.paper)
                                }
                                .frame(width: 44, height: 44)
                                Text(option.label)
                                    .font(theme.typography.font(.handTight, size: 11))
                                    .foregroundColor(theme.palette.ink2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Pick an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
