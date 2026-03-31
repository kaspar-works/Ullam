import SwiftUI

// Small mini month grid used in the sidebar "Yearly Emotional Journey" widget
struct MonthGridView: View {
    let year: Int
    let month: Int
    let moods: [Int: String]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        guard let date = calendar.date(from: DateComponents(year: year, month: month)) else { return "" }
        return formatter.string(from: date)
    }

    private var daysInMonth: Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month)),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 1 }
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.dimText)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(width: 12, height: 12)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCellView(day: day, emoji: moods[day], isToday: isToday(day: day))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.subtle)
        )
    }

    private func isToday(day: Int) -> Bool {
        let today = Date()
        return calendar.component(.year, from: today) == year &&
               calendar.component(.month, from: today) == month &&
               calendar.component(.day, from: today) == day
    }
}

struct DayCellView: View {
    let day: Int
    let emoji: String?
    let isToday: Bool

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .stroke(AppTheme.accent, lineWidth: 1)
                    .frame(width: 12, height: 12)
            }

            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 8))
            } else {
                Circle()
                    .fill(AppTheme.mutedText.opacity(0.15))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 12, height: 12)
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        MonthGridView(
            year: 2026,
            month: 1,
            moods: [1: "😊", 5: "😢", 10: "🥳", 15: "😴"]
        )
        .padding()
    }
}
