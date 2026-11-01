import Foundation
import CoreLocation
import CoreMotion

@MainActor
final class WorkoutTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var route: [RoutePoint] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var stepCount: Int = 0
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let store: WorkoutStore
    private var previousLocation: CLLocation?
    private var pendingStart = false
    private var lastCheckpoint = Date.distantPast

    init(store: WorkoutStore) {
        self.store = store
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    var activeKilocalories: Double {
        // Approximate *active* walking energy (not resting calories).
        // About 0.5 kcal/kg/km; no heart-rate sensor is required.
        let kg = max(35, min(250, UserDefaults.standard.double(forKey: "weightKg") == 0
                             ? 90 : UserDefaults.standard.double(forKey: "weightKg")))
        return (distanceMeters / 1_000) * kg * 0.5
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, date.timeIntervalSince(startedAt))
    }

    func start() {
        guard !isRecording else { return }
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "请先在 iPhone 设置中打开定位服务。"
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            actuallyStart()
        case .notDetermined:
            pendingStart = true
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "无法使用定位。请在「设置 → 隐私与安全性 → 定位服务」中为走迹开启定位权限。"
        @unknown default:
            errorMessage = "暂时无法获取定位权限。"
        }
    }

    private func actuallyStart() {
        pendingStart = false
        store.discardDraft()
        route = []
        distanceMeters = 0
        stepCount = 0
        previousLocation = nil
        currentSessionID = UUID()
        startedAt = Date()
        lastCheckpoint = .distantPast
        isRecording = true

        // Background location mode is enabled in Info.plist; enable it only for a workout.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()

        checkpointIfNeeded(force: true)
        guard CMPedometer.isStepCountingAvailable(), let startedAt else { return }
        pedometer.startUpdates(from: startedAt) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                if let data { self.stepCount = data.numberOfSteps.intValue }
                if let error { self.errorMessage = "计步暂不可用，GPS 仍会记录：\(error.localizedDescription)" }
                self.checkpointIfNeeded()
            }
        }
    }

    func finish() {
        guard isRecording, let startDate = startedAt else { return }
        let finishDate = Date()
        isRecording = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()

        let session = makeSession(startDate: startDate, endDate: finishDate)
        store.add(session)
        store.discardDraft()

        // Ask Core Motion for the final count, since live callbacks may lag slightly.
        if CMPedometer.isStepCountingAvailable() {
            pedometer.queryPedometerData(from: startDate, to: finishDate) { [weak self] data, _ in
                guard let data else { return }
                Task { @MainActor in
                    self?.store.updateSteps(id: session.id, steps: data.numberOfSteps.intValue)
                }
            }
        }

        startedAt = nil
        previousLocation = nil
        route = []
        distanceMeters = 0
        stepCount = 0
    }

    private func makeSession(startDate: Date, endDate: Date) -> WorkoutSession {
        WorkoutSession(
            id: currentSessionID,
            startDate: startDate,
            endDate: endDate,
            distanceMeters: distanceMeters,
            stepCount: stepCount,
            activeKilocalories: activeKilocalories,
            route: route
        )
    }

    private var currentSessionID = UUID()

    private func checkpointIfNeeded(force: Bool = false) {
        guard isRecording, let startedAt else { return }
        if force || Date().timeIntervalSince(lastCheckpoint) >= 12 {
            store.saveDraft(makeSession(startDate: startedAt, endDate: Date()))
            lastCheckpoint = Date()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if pendingStart {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: actuallyStart()
            case .denied, .restricted:
                pendingStart = false
                errorMessage = "未获得定位权限，无法开始轨迹记录。"
            default: break
            }
        } else if isRecording && (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted) {
            finish()
            errorMessage = "定位权限被关闭，已保存当前运动记录。"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording, let startedAt else { return }
        for location in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= 35,
                  location.timestamp >= startedAt.addingTimeInterval(-2),
                  abs(location.timestamp.timeIntervalSinceNow) < 300 else { continue }

            if let previousLocation {
                let delta = location.timestamp.timeIntervalSince(previousLocation.timestamp)
                let segment = location.distance(from: previousLocation)
                guard delta > 0, segment >= 3, segment / delta <= 4.5 else { continue }
                distanceMeters += segment
            }
            self.previousLocation = location
            route.append(RoutePoint(location: location))
            checkpointIfNeeded()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A temporary GPS outage does not discard the workout.
        if isRecording { errorMessage = "GPS 定位暂时中断，恢复后会继续记录：\(error.localizedDescription)" }
    }
}
