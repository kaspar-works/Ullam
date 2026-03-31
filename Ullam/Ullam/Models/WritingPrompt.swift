import Foundation
import SwiftData

@Model
final class WritingPrompt {
    var id: UUID = UUID()
    var text: String = ""
    var category: String = "reflection" // reflection, gratitude, creative, dream, anxiety
    var isUsed: Bool = false
    var usedDate: Date?

    init(text: String, category: String = "reflection") {
        self.id = UUID()
        self.text = text
        self.category = category
        self.isUsed = false
    }

    // Built-in prompt library
    static let defaultPrompts: [(text: String, category: String)] = [
        // Reflection
        ("What surprised you today?", "reflection"),
        ("What would you tell your younger self about today?", "reflection"),
        ("What moment today do you want to remember?", "reflection"),
        ("What did you learn today that you didn't know yesterday?", "reflection"),
        ("If today had a title, what would it be?", "reflection"),
        ("What conversation stayed with you today?", "reflection"),
        ("What are you avoiding thinking about?", "reflection"),
        ("What would you do differently if you could relive today?", "reflection"),
        ("What pattern are you noticing in your life lately?", "reflection"),
        ("What's something you're proud of but haven't told anyone?", "reflection"),

        // Gratitude
        ("Name three small things that made today better.", "gratitude"),
        ("Who made you smile today and why?", "gratitude"),
        ("What comfort do you take for granted?", "gratitude"),
        ("What part of your routine brings you the most joy?", "gratitude"),
        ("What's something beautiful you noticed today?", "gratitude"),
        ("Who would you thank if you could send one message right now?", "gratitude"),
        ("What skill do you have that you're grateful for?", "gratitude"),
        ("What about your home makes you feel safe?", "gratitude"),

        // Creative
        ("Write about a color that matches your mood right now.", "creative"),
        ("Describe your perfect day from morning to night.", "creative"),
        ("If your emotions were weather, what's the forecast?", "creative"),
        ("Write a letter to someone you'll never send.", "creative"),
        ("What would your life look like as a movie scene right now?", "creative"),
        ("Describe a memory using only sounds and smells.", "creative"),
        ("If you could live inside any painting, which one?", "creative"),
        ("Write about the view from your favorite window.", "creative"),

        // Dream
        ("What did you dream about last night?", "dream"),
        ("What's a recurring dream you've had?", "dream"),
        ("If you could dream about anything tonight, what would it be?", "dream"),
        ("Describe the strangest dream you remember.", "dream"),
        ("What do you think your dreams are trying to tell you?", "dream"),

        // Anxiety / Processing
        ("What's weighing on your mind right now? Write it all out.", "anxiety"),
        ("What are you worried about that might never happen?", "anxiety"),
        ("What would you say to a friend feeling what you feel right now?", "anxiety"),
        ("Name your emotions right now. All of them.", "anxiety"),
        ("What can you control about this situation? What can't you?", "anxiety"),
        ("Write down everything bothering you, then close this page.", "anxiety"),
        ("What's the worst case? What's the most likely case?", "anxiety"),
        ("What do you need right now that you're not giving yourself?", "anxiety"),
    ]
}
