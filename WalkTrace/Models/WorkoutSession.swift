import Foundation
import CoreLocation

struct RoutePoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        timestamp = location.timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WorkoutSession: Codable, Hashable, Identifiable {
    let id: UUID
    let startDate: Date
    var endDate: Date
    var distanceMeters: Double
    var stepCount: Int
    var activeKilocalories: Double
    var route: [RoutePoint]

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    var distanceKilometers: Double { distanceMeters / 1_000 }
    var avgPaceMinutesPerKilometer: Double? {
        guard distanceKilometers > 0.05 else { return nil }
        return duration / 60 / distanceKilometers
    }
}

extension TimeInterval {
    var workoutClock: String {
        let seconds = max(0, Int(self))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
