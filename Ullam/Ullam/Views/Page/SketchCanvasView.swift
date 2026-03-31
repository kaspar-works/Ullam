#if os(iOS)
import SwiftUI
import PencilKit

// MARK: - Sketch Canvas View (UIViewRepresentable)

struct SketchCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPickerVisible: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = UIColor(AppTheme.bg)
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: UIColor(AppTheme.accent), width: 3)
        canvasView.delegate = context.coordinator

        // Show tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        toolPicker.colorUserInterfaceStyle = .dark
        canvasView.becomeFirstResponder()

        // Store reference to tool picker
        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let toolPicker = context.coordinator.toolPicker {
            toolPicker.setVisible(toolPickerVisible, forFirstResponder: uiView)
            if toolPickerVisible && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
    }
}

// MARK: - Sketch Sheet View

struct SketchSheetView: View {
    var onSave: (Data) -> Void
    var onCancel: (() -> Void)?

    @State private var canvasView = PKCanvasView()
    @State private var toolPickerVisible: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [AppTheme.bg, AppTheme.bg, AppTheme.sidebarBg],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Canvas
                    SketchCanvasView(canvasView: $canvasView, toolPickerVisible: $toolPickerVisible)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.subtle, lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel?()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        // Undo
                        Button {
                            canvasView.undoManager?.undo()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.mutedText)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.subtle)
                                .clipShape(Circle())
                        }

                        // Redo
                        Button {
                            canvasView.undoManager?.redo()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.mutedText)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.subtle)
                                .clipShape(Circle())
                        }

                        // Clear
                        Button {
                            canvasView.drawing = PKDrawing()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.mutedText)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.subtle)
                                .clipShape(Circle())
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveDrawing()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.accent.opacity(0.5), Color(hex: 0xC49340).opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(Capsule().stroke(AppTheme.mutedText.opacity(0.18), lineWidth: 1))
                            )
                            .shadow(color: AppTheme.accent.opacity(0.2), radius: 8, y: 3)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Save

    private func saveDrawing() {
        // Render the canvas to a PNG image
        let drawing = canvasView.drawing
        let bounds = canvasView.bounds

        // Use the drawing's image representation
        let image = drawing.image(
            from: bounds,
            scale: UIScreen.main.scale
        )

        if let pngData = image.pngData() {
            onSave(pngData)
        }

        dismiss()
    }
}

#endif
