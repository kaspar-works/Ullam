#if os(iOS)
import SwiftUI
import SwiftData

struct TagChipsView: View {
    let tagIds: [UUID]
    let diary: Diary?
    var onTap: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    private var tags: [Tag] {
        guard let diary else { return [] }
        let allTags = TagService.shared.getAllTags(for: diary, context: modelContext)
        return allTags.filter { tagIds.contains($0.id) }
    }

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.id) { tag in
                        Button {
                            onTap?()
                        } label: {
                            Text(tag.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(tagColor(tag.color).opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke(tagColor(tag.color).opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(TagChipButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func tagColor(_ key: String) -> Color {
        switch key {
        case "blue": return AppTheme.gradientBlue
        case "orange": return AppTheme.moodHappy
        case "purple": return AppTheme.gradientPurple
        case "pink": return AppTheme.gradientPink
        case "green": return Color(hex: 0x34D399)
        case "yellow": return Color(hex: 0xFDE68A)
        case "red": return Color(hex: 0xF87171)
        case "indigo": return AppTheme.indigo
        default: return AppTheme.accent
        }
    }
}

private struct TagChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
#endif
