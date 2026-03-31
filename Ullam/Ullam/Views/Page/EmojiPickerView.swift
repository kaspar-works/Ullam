import SwiftUI

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String?
    var onSelect: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var appeared = false
    @State private var tappedEmoji: String? = nil

    private let moodEmojis = [
        ["😊", "😄", "🥰", "😍", "🤗", "😌"],
        ["😐", "🤔", "😶", "🙂", "😏", "😑"],
        ["😢", "😭", "😔", "😞", "🥺", "😿"],
        ["😤", "😠", "😡", "🤬", "😾", "💢"],
        ["😰", "😨", "😱", "😳", "🫣", "😬"],
        ["🤩", "🥳", "🎉", "✨", "💫", "🌟"],
        ["😴", "🥱", "😪", "💤", "🛌", "😮‍💨"],
        ["🤒", "🤢", "🤮", "😷", "🤧", "🥴"]
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(moodEmojis.enumerated()), id: \.offset) { rowIdx, row in
                        HStack(spacing: 12) {
                            ForEach(Array(row.enumerated()), id: \.element) { colIdx, emoji in
                                let delay = Double(rowIdx) * 0.04 + Double(colIdx) * 0.02
                                Button {
                                    tappedEmoji = emoji
                                    selectedEmoji = emoji
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onSelect?(emoji)
                                        dismiss()
                                    }
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 36))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            selectedEmoji == emoji ?
                                            Color.accentColor.opacity(0.2) :
                                            Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .scaleEffect(tappedEmoji == emoji ? 1.3 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: tappedEmoji)
                                }
                                .buttonStyle(.plain)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.5))
                                .animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7).delay(delay), value: appeared)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("How are you feeling?")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation {
                    appeared = true
                }
            }
        }
    }
}

#Preview {
    EmojiPickerView(selectedEmoji: .constant("😊"))
}
