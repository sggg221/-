import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkoutStore

    private var totalDistance: Double { store.sessions.reduce(0) { $0 + $1.distanceKilometers } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        InfoTile(icon: "figure.walk", title: "累计运动",
                                 value: "\(store.sessions.count)", unit: "次")
                        InfoTile(icon: "map.fill", title: "累计公里",
                                 value: String(format: "%.1f", totalDistance), unit: "km")
                    }
                    if store.sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.walk.circle")
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundStyle(WalkTheme.accent)
                            Text("还没有运动记录").font(.title3.bold())
                            Text("回到「今天」开始第一次走路，轨迹会保存在这里。")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(WalkTheme.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else {
                        ForEach(store.sessions) { session in
                            NavigationLink {
                                WorkoutDetailView(session: session)
                            } label: {
                                workoutRow(session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("删除这条记录", systemImage: "trash", role: .destructive) {
                                    store.delete(session.id)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(WalkTheme.background.ignoresSafeArea())
            .navigationTitle("运动历史")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func workoutRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(WalkTheme.accent)
                .frame(width: 54, height: 54)
                .background(WalkTheme.elevated, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(session.startDate.formatted(.dateTime.year().month().day().hour().minute()))
                    .font(.subheadline.weight(.medium))
                Text("\(session.stepCount) 步  ·  \(Int(session.activeKilocalories)) kcal（估算）")
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", session.distanceKilometers) + " km")
                    .font(.headline.monospacedDigit())
                Text(session.duration.workoutClock)
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(WalkTheme.secondary)
        }
        .padding(14)
        .background(WalkTheme.surface, in: RoundedRectangle(cornerRadius: 21))
    }
}
