import SwiftUI
import MapKit

struct RouteMapView: View {
    let points: [RoutePoint]
    var showsUserLocation = false

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }

    var body: some View {
        Map(position: $cameraPosition) {
            if points.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(WalkTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let first = points.first {
                Annotation("起点", coordinate: first.coordinate) {
                    Circle()
                        .fill(WalkTheme.accent)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.black, lineWidth: 3))
                }
            }
            if points.count >= 2, let last = points.last {
                Annotation("终点", coordinate: last.coordinate) {
                    Image(systemName: "flag.checkered")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(7)
                        .background(WalkTheme.accent, in: Circle())
                }
            }
            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .onAppear(perform: fitRoute)
        .onChange(of: points.count) { _, _ in fitRoute() }
    }

    private func fitRoute() {
        guard !points.isEmpty else {
            if showsUserLocation {
                cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
            }
            return
        }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.007, (maxLat - minLat) * 1.5),
                                   longitudeDelta: max(0.007, (maxLon - minLon) * 1.5))
        )
        cameraPosition = .region(region)
    }
}
