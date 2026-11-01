import SwiftUI

@main
struct WalkTraceApp: App {
    @StateObject private var store: WorkoutStore
    @StateObject private var tracker: WorkoutTracker
    @StateObject private var todayMetrics: TodayMetricsService

    init() {
        let store = WorkoutStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: WorkoutTracker(store: store))
        _todayMetrics = StateObject(wrappedValue: TodayMetricsService())
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environmentObject(todayMetrics)
                .preferredColorScheme(.dark)
        }
    }
}
