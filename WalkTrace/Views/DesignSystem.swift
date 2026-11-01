import SwiftUI

// Colors shared by the home, history and settings screens.
enum WalkTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.088)
    static let surface = Color(red: 0.100, green: 0.132, blue: 0.145)
    static let elevated = Color(red: 0.140, green: 0.175, blue: 0.181)
    static let accent = Color(red: 0.71, green: 0.97, blue: 0.55)
    static let secondary = Color(red: 0.60, green: 0.68, blue: 0.67)
}

struct InfoTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(WalkTheme.accent)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(WalkTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(WalkTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            Text(subtitle).font(.caption).foregroundStyle(WalkTheme.secondary)
        }
    }
}
