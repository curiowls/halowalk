import SwiftUI
import MapKit

/// Edit an existing hub. Mirrors AddHubSheet's configure stage with the
/// preview map, icon-with-name layout, and drop-color-picker simplification.
struct EditHubSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var familyStore: FamilyStore
    @EnvironmentObject var hubStore: HubStore

    @State var hub: Hub
    @State private var assignedMembers: Set<UUID>
    @State private var iconOption: HubIconCatalog.Option
    @State private var showDeleteConfirm = false
    @State private var showIconPicker = false

    init(hub: Hub) {
        _hub = State(initialValue: hub)
        _assignedMembers = State(initialValue: Set(hub.assignedMemberIds))
        _iconOption = State(initialValue: HubIconCatalog.option(for: hub.icon))
    }

    var body: some View {
        NavigationStack {
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
                        TextField("Name", text: $hub.name)
                    }
                }

                Section("Location") {
                    HubMapPreview(
                        coordinate: hub.coordinate,
                        haloRadiusMeters: hub.haloRadiusMeters,
                        color: iconOption.color
                    )
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    if !hub.address.isEmpty {
                        Text(hub.address)
                            .font(theme.typography.font(.handFlow, size: 13))
                    }
                    Text(String(format: "%.5f, %.5f", hub.latitude, hub.longitude))
                        .font(theme.typography.font(.mono, size: 11))
                        .foregroundColor(theme.palette.ink3)
                }

                Section("Halo radius — \(Units.radius(meters: hub.haloRadiusMeters))") {
                    Slider(value: $hub.haloRadiusMeters, in: 20...500, step: 10)
                }

                Section("Used by") {
                    ForEach(familyStore.watchedMembers) { wearer in
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
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Remove this hub", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(hub.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog(
                "Remove \(hub.name)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    hubStore.remove(hub.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This hub will stop tracking the people assigned to it.")
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selected: $iconOption)
                    .presentationDetents([.medium])
            }
        }
    }

    private func save() {
        var updated = hub
        updated.assignedMemberIds = Array(assignedMembers)
        updated.icon = iconOption.systemName
        updated.colorHex = iconOption.colorHex
        hubStore.update(updated)
        dismiss()
    }
}
