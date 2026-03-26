import SwiftUI

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String?
    var onSelect: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

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
                    ForEach(moodEmojis, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                    onSelect?(emoji)
                                    dismiss()
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
                                }
                                .buttonStyle(.plain)
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
        }
    }
}

#Preview {
    EmojiPickerView(selectedEmoji: .constant("😊"))
}
