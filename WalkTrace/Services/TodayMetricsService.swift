import Foundation
import CoreMotion
#if !WALKTRACE_SIDELOAD
import HealthKit
#endif

@MainActor
final class TodayMetricsService: ObservableObject {
    @Published private(set) var todaySteps: Int?
    @Published private(set) var todayDistanceMeters: Double?
    @Published private(set) var todayHealthKilocalories: Double?
    @Published private(set) var motionNotice: String?
    @Published private(set) var healthNotice: String?

    private let pedometer = CMPedometer()
    #if !WALKTRACE_SIDELOAD
    private let healthStore = HKHealthStore()
    #endif
    private var lastObservedDay: Date?

    func start() {
        refresh()
    }

    func refresh() {
        pedometer.stopUpdates()
        let dayStart = Calendar.current.startOfDay(for: Date())
        if lastObservedDay != dayStart {
            todaySteps = nil
            todayDistanceMeters = nil
        }
        lastObservedDay = dayStart

        guard CMPedometer.isStepCountingAvailable() else {
            motionNotice = "此设备不支持计步，请在真机上测试。"
            refreshHealthCalories()
            return
        }

        pedometer.queryPedometerData(from: dayStart, to: Date()) { [weak self] data, error in
            Task { @MainActor in self?.applyPedometerData(data, error: error) }
        }
        pedometer.startUpdates(from: dayStart) { [weak self] data, error in
            Task { @MainActor in self?.applyPedometerData(data, error: error) }
        }
        refreshHealthCalories()
    }

    private func applyPedometerData(_ data: CMPedometerData?, error: Error?) {
        if let data {
            todaySteps = data.numberOfSteps.intValue
            todayDistanceMeters = data.distance?.doubleValue
            motionNotice = nil
        } else if let error {
            motionNotice = "读取步数失败，请检查「运动与健身」权限：\(error.localizedDescription)"
        }
    }

    #if WALKTRACE_SIDELOAD
    func requestHealthAccess() {
        healthNotice = "此版本为免费 Apple ID 侧载版：保留运动热量估算，Apple 健康读取需要支持 HealthKit 的正式签名版本。"
    }

    func refreshHealthCalories() {
        todayHealthKilocalories = nil
    }
    #else
    func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthNotice = "此设备无法使用 Apple 健康。"
            return
        }
        let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        healthStore.requestAuthorization(toShare: [], read: [energy]) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.healthNotice = "健康数据授权失败：\(error.localizedDescription)"
                } else {
                    // Success indicates the prompt completed, not necessarily that read access was granted.
                    UserDefaults.standard.set(true, forKey: "healthAccessRequested")
                    self.healthNotice = "已处理授权请求。如果没有热量数据，请检查健康 App 的访问权限。"
                    self.refreshHealthCalories()
                }
            }
        }
    }

    func refreshHealthCalories() {
        guard HKHealthStore.isHealthDataAvailable(),
              UserDefaults.standard.bool(forKey: "healthAccessRequested"),
              let quantityType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            todayHealthKilocalories = nil
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate
        )
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, result, error in
            let kcal = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
            Task { @MainActor in
                self?.todayHealthKilocalories = kcal
                if let error { self?.healthNotice = "无法读取健康数据：\(error.localizedDescription)" }
            }
        }
        healthStore.execute(query)
    }
    #endif
}
