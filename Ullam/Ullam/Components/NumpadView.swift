import SwiftUI

struct NumpadView: View {
    @Binding var enteredValue: String
    let maxDigits: Int
    var onBiometric: (() -> Void)?
    var onComplete: (() -> Void)?

    private let buttons: [[NumpadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.biometric, .digit("0"), .delete]
    ]

    var body: some View {
        VStack(spacing: 18) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        NumpadButton(key: key) {
                            handleTap(key)
                        }
                    }
                }
            }
        }
    }

    private func handleTap(_ key: NumpadKey) {
        switch key {
        case .digit(let value):
            guard enteredValue.count < maxDigits else { return }
            enteredValue += value
            if enteredValue.count == maxDigits {
                onComplete?()
            }
        case .delete:
            if !enteredValue.isEmpty {
                enteredValue.removeLast()
            }
        case .biometric:
            onBiometric?()
        }
    }
}

enum NumpadKey: Hashable {
    case digit(String)
    case delete
    case biometric
}

struct NumpadButton: View {
    let key: NumpadKey
    let action: () -> Void

    @State private var isPressed = false

    private var buttonSize: CGFloat {
        #if os(macOS)
        72
        #else
        76
        #endif
    }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: buttonSize, height: buttonSize)

                content
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(NumpadPressStyle())
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var content: some View {
        switch key {
        case .digit(let value):
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        case .delete:
            Image(systemName: "delete.backward")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
        case .biometric:
            #if os(iOS)
            Image(systemName: "touchid")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
            #else
            Image(systemName: "touchid")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
            #endif
        }
    }

    private var accessibilityDescription: String {
        switch key {
        case .digit(let value): return value
        case .delete: return "Delete"
        case .biometric: return "Unlock with biometrics"
        }
    }

    private var backgroundColor: Color {
        switch key {
        case .digit:
            return .white.opacity(0.06)
        case .delete, .biometric:
            return .clear
        }
    }
}

struct NumpadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black
        NumpadView(enteredValue: .constant("12"), maxDigits: 4)
    }
}
