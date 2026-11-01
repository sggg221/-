import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var tracker: WorkoutTracker
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var metrics: TodayMetricsService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dailyGoalKm") private var dailyGoalKm = 5.0
    @State private var showRecovery = false
    @State private var showError = false

    private var loggedDistance: Double { store.todaySessions.reduce(0) { $0 + $1.distanceKilometers } }
    private var currentDistance: Double { tracker.isRecording ? tracker.distanceMeters / 1_000 : 0 }
    private var goalProgress: Double { min(1, (loggedDistance + currentDistance) / max(1, dailyGoalKm)) }
    private var recordedKcal: Double { store.todaySessions.reduce(0) { $0 + $1.activeKilocalories } + (tracker.isRecording ? tracker.activeKilocalories : 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                goalCard
                trackingCard
                dailyMetrics
                if let notice = metrics.motionNotice {
                    Label(notice, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(WalkTheme.secondary)
                }
                Text("轨迹仅在你点击「开始运动」后记录；数据默认保存在本机。")
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .background(WalkTheme.background.ignoresSafeArea())
        .onAppear {
            metrics.start()
            showRecovery = store.recoverableDraft != nil && !tracker.isRecording
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { metrics.refresh() }
        }
        .onChange(of: tracker.errorMessage) { _, value in showError = value != nil }
        .onChange(of: store.storageError) { _, value in showError = value != nil }
        .alert("运动记录提示", isPresented: $showError) {
            Button("知道了") { tracker.errorMessage = nil; store.storageError = nil }
        } message: {
            Text(tracker.errorMessage ?? store.storageError ?? "")
        }
        .alert("发现未结束的运动", isPresented: $showRecovery) {
            Button("保存已记录部分") { store.restoreDraft() }
            Button("丢弃记录", role: .destructive) { store.discardDraft() }
        } message: {
            Text("上次运动可能被系统中断。可以保存最后一次自动备份的数据，不能补回中断后的轨迹。")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("WALKTRACE  /  走迹")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(WalkTheme.accent)
                Text("今天，走了多远？")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text(Date.now.formatted(.dateTime.year().month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(WalkTheme.secondary)
            }
            Spacer()
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(WalkTheme.accent)
                .frame(width: 58, height: 58)
                .background(WalkTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("今日运动目标", systemImage: "target")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(WalkTheme.secondary)
                Spacer()
                Text("\(Int(goalProgress * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(WalkTheme.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.2f", loggedDistance + currentDistance))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(dailyGoalKm.formatted()) km")
                    .font(.subheadline)
                    .foregroundStyle(WalkTheme.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(WalkTheme.elevated)
                    Capsule().fill(WalkTheme.accent).frame(width: geometry.size.width * goalProgress)
                }
            }
            .frame(height: 9)
            Text("这里统计本 App 记录的运动距离，不等于全天走路总里程。")
                .font(.caption2)
                .foregroundStyle(WalkTheme.secondary)
        }
        .padding(20)
        .background(WalkTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var trackingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "运动轨迹", subtitle: tracker.isRecording ? "● 记录中" : "等待开始")
            ZStack(alignment: .bottomLeading) {
                RouteMapView(points: tracker.route, showsUserLocation: true)
                    .frame(height: 266)
                    .clipShape(RoundedRectangle(cornerRadius: 21))
                if !tracker.isRecording {
                    Text("开始运动后绘制 GPS 路线")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .padding(13)
                }
            }
            if tracker.isRecording {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    HStack(spacing: 10) {
                        liveLabel("时间", tracker.elapsed(at: timeline.date).workoutClock)
                        liveLabel("距离", String(format: "%.2f km", tracker.distanceMeters / 1_000))
                        liveLabel("步数", "\(tracker.stepCount)")
                    }
                }
            }
            Button {
                if tracker.isRecording {
                    tracker.finish()
                    metrics.refresh()
                } else {
                    tracker.start()
                }
            } label: {
                Label(tracker.isRecording ? "结束并保存运动" : "开始运动",
                      systemImage: tracker.isRecording ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(WalkTheme.background)
                    .background(WalkTheme.accent, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)
            Text(tracker.isRecording ? "可锁屏继续走路；不要从多任务界面强制关闭 App。" : "运动中使用 GPS，耗电量会增加。")
                .font(.caption)
                .foregroundStyle(WalkTheme.secondary)
        }
    }

    private func liveLabel(_ heading: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(heading).font(.caption2).foregroundStyle(WalkTheme.secondary)
            Text(value).font(.subheadline.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dailyMetrics: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "今日概览", subtitle: "iPhone 计步 / 活动热量")
            HStack(spacing: 10) {
                InfoTile(icon: "shoeprints.fill", title: "今日步数",
                         value: metrics.todaySteps.map(String.init) ?? "—", unit: "步")
                InfoTile(icon: "flame.fill", title: "活动热量",
                         value: String(Int((metrics.todayHealthKilocalories ?? recordedKcal).rounded())), unit: "kcal")
            }
            HStack(spacing: 10) {
                InfoTile(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "全天步行距离",
                         value: metrics.todayDistanceMeters.map { String(format: "%.2f", $0 / 1_000) } ?? "—", unit: "km")
                InfoTile(icon: "figure.walk", title: "运动次数", value: "\(store.todaySessions.count + (tracker.isRecording ? 1 : 0))", unit: "次")
            }
            Text(metrics.todayHealthKilocalories != nil
                 ? "活动热量来自 Apple 健康；运动详情中的热量为基于距离与体重的估算。"
                 : "活动热量仅统计本 App 已记录的运动（估算）；可在设置中授权 Apple 健康查看全天数据。")
                .font(.caption2)
                .foregroundStyle(WalkTheme.secondary)
        }
    }
}
