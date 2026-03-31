import Foundation
#if os(iOS)
import UIKit
#endif

/// Provides instant "panic lock" functionality: locks the current protected diary
/// and switches to the default unprotected diary, clearing sensitive state.
@MainActor
final class PanicLockService {

    static let shared = PanicLockService()
    private init() {}

    /// Instantly lock the current diary and switch to default unprotected diary.
    /// Clears any sensitive state from memory.
    func performPanicLock(diaryManager: DiaryManager) {
        // Only meaningful if we have a protected diary open
        guard diaryManager.currentDiary?.isProtected == true else { return }

        // Lock the current diary (clears key + diary reference)
        diaryManager.lockCurrentDiary()

        // Switch to default unprotected diary so the screen looks innocuous
        _ = diaryManager.openDefaultDiaryIfUnprotected()

        #if os(iOS)
        // Haptic feedback: warning pattern
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
