import SwiftUI
import MapKit

/// One pin on the sketch map.
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let label: String
    let icon: String
    let color: Color
    /// Halo radius in meters; 0 = no halo
    let haloRadius: Double
}

/// One person to render as a moving avatar on the map.
struct MapAvatar: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let label: String
    let color: Color
    let status: StatusDot.Status
}

/// Renders a map according to the active theme:
///   - `.sketch`  → hand-drawn paper map (no real geodata)
///   - `.kit`     → real MapKit map, themed controls only
///   - `.kitTextured` → MapKit with a sketchy overlay layer
struct ThemedMap: View {
    @Environment(\.theme) var theme

    let region: MKCoordinateRegion
    let pins: [MapPin]
    let avatars: [MapAvatar]
    /// A safe corridor described as a series of coordinates; rendered as a
    /// dashed green path on either map style.
    let corridor: [CLLocationCoordinate2D]

    init(
        region: MKCoordinateRegion,
        pins: [MapPin] = [],
        avatars: [MapAvatar] = [],
        corridor: [CLLocationCoordinate2D] = []
    ) {
        self.region = region
        self.pins = pins
        self.avatars = avatars
        self.corridor = corridor
    }

    var body: some View {
        #if os(watchOS)
        // watchOS 10's Map API doesn't expose the MapContent builder, so we
        // can't render themed annotations there. The sketch map still gives
        // the watch wearer a useful overview during the pilot regardless of
        // the chosen theme; iOS gets the real MapKit treatment.
        SketchMapView(pins: pins, avatars: avatars, corridor: corridor)
        #else
        switch theme.map {
        case .sketch:
            SketchMapView(pins: pins, avatars: avatars, corridor: corridor)
        case .kit, .kitTextured:
            RealMapView(
                region: region,
                pins: pins,
                avatars: avatars,
                corridor: corridor,
                textured: theme.map == .kitTextured
            )
        }
        #endif
    }
}

// MARK: - Sketch (paper) map

/// Hatched-paper background with squiggle "roads" and a soft park blob.
/// Pin coordinates are reinterpreted as percentages of the box for the
/// sketch theme — coordinates are normalized to (lon ↔ x, lat ↔ y) using
/// the supplied region's bounding box at draw time.
struct SketchMapView: View {
    @Environment(\.theme) var theme
    let pins: [MapPin]
    let avatars: [MapAvatar]
    let corridor: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Cross-hatched paper
                Rectangle()
                    .fill(Color(hex: 0xEFE9DB))
                Canvas { ctx, size in
                    let step: CGFloat = 16
                    let path = Path { p in
                        var x: CGFloat = -size.height
                        while x < size.width {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            x += step
                        }
                    }
                    ctx.stroke(path, with: .color(.black.opacity(0.04)), lineWidth: 1)
                }

                // Roads
                Canvas { ctx, size in
                    let road1 = Path { p in
                        p.move(to: CGPoint(x: -5, y: size.height * 0.3))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width + 5, y: size.height * 0.25),
                            control: CGPoint(x: size.width * 0.5, y: size.height * 0.32)
                        )
                    }
                    let road2 = Path { p in
                        p.move(to: CGPoint(x: -5, y: size.height * 0.65))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width + 5, y: size.height * 0.7),
                            control: CGPoint(x: size.width * 0.55, y: size.height * 0.61)
                        )
                    }
                    let road3 = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.2, y: -5))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.25, y: size.height + 5),
                            control: CGPoint(x: size.width * 0.3, y: size.height * 0.5)
                        )
                    }
                    let road4 = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.75, y: -5))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.78, y: size.height + 5),
                            control: CGPoint(x: size.width * 0.77, y: size.height * 0.5)
                        )
                    }
                    ctx.stroke(road1, with: .color(Color(hex: 0xBDB6A4)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    ctx.stroke(road2, with: .color(Color(hex: 0xBDB6A4)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    ctx.stroke(road3, with: .color(Color(hex: 0xBDB6A4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    ctx.stroke(road4, with: .color(Color(hex: 0xBDB6A4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    // Park blob
                    let park = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.55, y: size.height * 0.5))
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.7, y: size.height * 0.6),
                            control: CGPoint(x: size.width * 0.7, y: size.height * 0.45)
                        )
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.55, y: size.height * 0.7),
                            control: CGPoint(x: size.width * 0.6, y: size.height * 0.7)
                        )
                        p.addQuadCurve(
                            to: CGPoint(x: size.width * 0.5, y: size.height * 0.6),
                            control: CGPoint(x: size.width * 0.45, y: size.height * 0.65)
                        )
                        p.closeSubpath()
                    }
                    ctx.fill(park, with: .color(Color(hex: 0xCFD9BF)))
                    ctx.stroke(park, with: .color(Color(hex: 0x9AA783)), lineWidth: 1)

                    // Corridor (if provided)
                    if !corridor.isEmpty {
                        let cp = Path { p in
                            for (i, c) in corridor.enumerated() {
                                let pt = CGPoint(
                                    x: size.width * CGFloat(c.longitude),
                                    y: size.height * CGFloat(c.latitude)
                                )
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                        }
                        ctx.stroke(
                            cp,
                            with: .color(theme.palette.haloGreen.opacity(0.7)),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4])
                        )
                    }
                }

                // Halos around pins
                ForEach(pins) { pin in
                    if pin.haloRadius > 0 {
                        HaloRingDashed(color: pin.color, size: CGFloat(pin.haloRadius * 2))
                            .position(
                                x: geo.size.width * CGFloat(pin.coordinate.longitude),
                                y: geo.size.height * CGFloat(pin.coordinate.latitude)
                            )
                    }
                }

                // Pins
                ForEach(pins) { pin in
                    SketchPin(label: pin.label, icon: pin.icon, color: pin.color)
                        .position(
                            x: geo.size.width * CGFloat(pin.coordinate.longitude),
                            y: geo.size.height * CGFloat(pin.coordinate.latitude)
                        )
                }

                // Avatars
                ForEach(avatars) { a in
                    SketchAvatar(label: a.label, color: a.color, status: a.status)
                        .position(
                            x: geo.size.width * CGFloat(a.coordinate.longitude),
                            y: geo.size.height * CGFloat(a.coordinate.latitude)
                        )
                }
            }
            .clipShape(WobbleShape(corners: theme.geometry.wobbleCorners))
            .overlay(
                WobbleShape(corners: theme.geometry.wobbleCorners)
                    .stroke(theme.palette.line, lineWidth: theme.strokes.regular)
            )
        }
    }
}

private struct SketchPin: View {
    @Environment(\.theme) var theme
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Path { p in
                    p.addArc(center: CGPoint(x: 11, y: 11), radius: 11,
                             startAngle: .degrees(-225), endAngle: .degrees(45), clockwise: false)
                    p.closeSubpath()
                }
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Path { p in
                        p.addArc(center: CGPoint(x: 11, y: 11), radius: 11,
                                 startAngle: .degrees(-225), endAngle: .degrees(45), clockwise: false)
                        p.closeSubpath()
                    }.stroke(theme.palette.line, lineWidth: 1.5)
                )
                .rotationEffect(.degrees(-45))
                Text(icon)
                    .font(theme.typography.font(.handTight, size: 11, weight: .bold))
                    .foregroundColor(theme.palette.paper)
            }
            Text(label)
                .font(theme.typography.font(.hand, size: 10))
                .foregroundColor(theme.palette.ink)
                .padding(.horizontal, 4)
                .background(theme.palette.paper)
                .overlay(Rectangle().stroke(theme.palette.line, lineWidth: 1))
        }
    }
}

private struct SketchAvatar: View {
    @Environment(\.theme) var theme
    let label: String
    let color: Color
    let status: StatusDot.Status
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(color).frame(width: 16, height: 16)
                Circle().stroke(theme.palette.line, lineWidth: 1.5).frame(width: 16, height: 16)
                StatusDot(status: status, size: 6)
                    .offset(x: 8, y: -8)
            }
            Text(label)
                .font(theme.typography.font(.hand, size: 10))
                .foregroundColor(theme.palette.ink)
                .padding(.horizontal, 4)
                .background(theme.palette.paper)
                .overlay(Rectangle().stroke(theme.palette.line, lineWidth: 1))
        }
    }
}

// MARK: - Real MapKit (default for non-sketch themes — iOS only)

#if !os(watchOS)
struct RealMapView: View {
    let region: MKCoordinateRegion
    let pins: [MapPin]
    let avatars: [MapAvatar]
    let corridor: [CLLocationCoordinate2D]
    let textured: Bool

    @State private var cameraPosition: MapCameraPosition

    init(
        region: MKCoordinateRegion,
        pins: [MapPin],
        avatars: [MapAvatar],
        corridor: [CLLocationCoordinate2D],
        textured: Bool
    ) {
        self.region = region
        self.pins = pins
        self.avatars = avatars
        self.corridor = corridor
        self.textured = textured
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(pins) { pin in
                Annotation(pin.label, coordinate: pin.coordinate) {
                    PinBadge(icon: pin.icon, color: pin.color)
                }
                if pin.haloRadius > 0 {
                    MapCircle(center: pin.coordinate, radius: pin.haloRadius)
                        .foregroundStyle(pin.color.opacity(0.18))
                        .stroke(pin.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            }
            ForEach(avatars) { a in
                Annotation(a.label, coordinate: a.coordinate) {
                    AvatarBadge(color: a.color, status: a.status)
                }
            }
            if corridor.count > 1 {
                MapPolyline(coordinates: corridor)
                    .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 4]))
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay {
            if textured {
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PinBadge: View {
    @Environment(\.theme) var theme
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 24, height: 24)
            Circle().stroke(theme.palette.line, lineWidth: 1.5).frame(width: 24, height: 24)
            Text(icon)
                .font(theme.typography.font(.handTight, size: 12, weight: .bold))
                .foregroundColor(theme.palette.paper)
        }
    }
}

private struct AvatarBadge: View {
    @Environment(\.theme) var theme
    let color: Color
    let status: StatusDot.Status
    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 18, height: 18)
            Circle().stroke(theme.palette.line, lineWidth: 1.5).frame(width: 18, height: 18)
            StatusDot(status: status, size: 7)
                .offset(x: 9, y: -9)
        }
    }
}
#endif
