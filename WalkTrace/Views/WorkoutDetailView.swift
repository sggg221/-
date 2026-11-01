import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.startDate.formatted(.dateTime.year().month().day().weekday(.wide)))
                        .foregroundStyle(WalkTheme.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.2f", session.distanceKilometers))
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                        Text("公里")
                            .foregroundStyle(WalkTheme.secondary)
                    }
                    Text("\(session.startDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(WalkTheme.secondary)
                }
                RouteMapView(points: session.route)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 23))
                    .overlay(alignment: .bottomLeading) {
                        if session.route.isEmpty {
                            Text("本次没有可用的 GPS 轨迹")
                                .font(.caption)
                                .padding(10)
                                .background(.regularMaterial, in: Capsule())
                                .padding(12)
                        }
                    }
                HStack(spacing: 10) {
                    InfoTile(icon: "clock", title: "用时", value: session.duration.workoutClock, unit: "")
                    InfoTile(icon: "shoeprints.fill", title: "运动步数", value: "\(session.stepCount)", unit: "步")
                }
                HStack(spacing: 10) {
                    InfoTile(icon: "flame.fill", title: "活动热量（估算）",
                             value: "\(Int(session.activeKilocalories.rounded()))", unit: "kcal")
                    InfoTile(icon: "speedometer", title: "平均配速",
                             value: session.avgPaceMinutesPerKilometer.map { String(format: "%.1f", $0) } ?? "—",
                             unit: "分钟/km")
                }
                Text("地图由 GPS 位置点绘制；热量依据记录距离及设置的体重估算，不代表医疗或运动设备的精确测量。")
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
            }
            .padding(20)
        }
        .background(WalkTheme.background.ignoresSafeArea())
        .navigationTitle("运动详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
