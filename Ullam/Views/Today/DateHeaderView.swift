import SwiftUI

struct DateHeaderView: View {
    @Binding var selectedDate: Date
    var onDateChange: () -> Void

    private let calendar = Calendar.current

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        HStack {
            Button {
                navigateDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 4) {
                if isToday {
                    Text("Today")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Text(formattedDate)
                    .font(.appHeadline)
            }

            Spacer()

            Button {
                navigateDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(canGoForward ? Color.secondary : Color.clear)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
    }

    private var canGoForward: Bool {
        !calendar.isDateInToday(selectedDate)
    }

    private func navigateDay(by offset: Int) {
        if let newDate = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
            selectedDate = newDate
            onDateChange()
        }
    }
}

#Preview {
    DateHeaderView(selectedDate: .constant(Date()), onDateChange: {})
}
