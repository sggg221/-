import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var metrics: TodayMetricsService
    @AppStorage("weightKg") private var weightKg = 90.0
    @AppStorage("dailyGoalKm") private var dailyGoalKm = 5.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $weightKg, in: 35...250, step: 0.5) {
                        HStack {
                            Label("体重", systemImage: "scalemass")
                            Spacer()
                            Text("\(weightKg.formatted()) kg")
                                .foregroundStyle(WalkTheme.accent)
                        }
                    }
                    Stepper(value: $dailyGoalKm, in: 1...30, step: 0.5) {
                        HStack {
                            Label("每日距离目标", systemImage: "target")
                            Spacer()
                            Text("\(dailyGoalKm.formatted()) km")
                                .foregroundStyle(WalkTheme.accent)
                        }
                    }
                } header: { Text("个人目标") } footer: {
                    Text("体重只用于估算本 App 记录运动的活动热量；修改体重不影响已经保存的历史记录。")
                }

                Section {
                    #if WALKTRACE_SIDELOAD
                    Label("免费侧载版使用热量估算，不读取 Apple 健康", systemImage: "heart.text.square")
                        .foregroundStyle(WalkTheme.secondary)
                    #else
                    Button {
                        metrics.requestHealthAccess()
                    } label: {
                        Label("连接 Apple 健康（只读活动热量）", systemImage: "heart.text.square")
                    }
                    #endif
                    Button {
                        metrics.refresh()
                    } label: {
                        Label("刷新今日步数", systemImage: "arrow.clockwise")
                    }
                    if let notice = metrics.healthNotice {
                        Text(notice).font(.caption).foregroundStyle(WalkTheme.secondary)
                    }
                } header: { Text("数据来源") } footer: {
                    #if WALKTRACE_SIDELOAD
                    Text("日常步数来自 iPhone 的 Core Motion；活动热量按运动距离和设置的体重估算。免费侧载版不读取 Apple 健康。")
                    #else
                    Text("日常步数来自 iPhone 的 Core Motion；授权后，可读取 Apple 健康中的当日活动热量。不会将运动写回健康 App。")
                    #endif
                }

                Section("隐私与说明") {
                    Label("运动轨迹及历史记录保存在 iPhone 本地", systemImage: "iphone")
                    Label("不需要账号，也不会上传到自建服务器", systemImage: "lock.shield")
                    Label("只在主动开始运动后持续使用 GPS", systemImage: "location")
                    Text("锁屏后系统仍可持续定位，但强制关闭应用、关闭定位或系统回收进程可能导致轨迹中断。")
                        .font(.caption)
                        .foregroundStyle(WalkTheme.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalkTheme.background.ignoresSafeArea())
            .navigationTitle("设置")
        }
    }
}
