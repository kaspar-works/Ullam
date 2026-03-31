import Foundation
import SwiftData

@MainActor
final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    // Increment this when schema changes during development
    private static let schemaVersion = 8

    /// Whether iCloud sync is enabled (persisted in UserDefaults)
    var iCloudEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled")
            // Note: changing iCloud requires app restart to take effect with SwiftData
        }
    }

    private init() {
        let schema = Schema([
            Diary.self,
            Page.self,
            DayMood.self,
            MediaAttachment.self,
            AppSettings.self,
            Tag.self,
            WritingPrompt.self,
            TimeCapsule.self
        ])

        // Use local-only storage to avoid CloudKit schema compatibility issues
        // iCloud sync can be re-enabled once CloudKit entitlements are fully configured
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        // Check if we need to reset due to schema version change
        let currentVersion = UserDefaults.standard.integer(forKey: "schemaVersion")
        if currentVersion != Self.schemaVersion {
            print("Schema version changed from \(currentVersion) to \(Self.schemaVersion), resetting store")
            Self.deleteExistingStore()
            UserDefaults.standard.set(Self.schemaVersion, forKey: "schemaVersion")
        }

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("Migration failed, attempting to recreate store: \(error)")
            Self.deleteExistingStore()

            do {
                container = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to initialize ModelContainer after reset: \(error)")
            }
        }
    }

    private static func deleteExistingStore() {
        let fileManager = FileManager.default

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        // Delete all .store files (SwiftData may use different names)
        let extensions = ["store", "store-shm", "store-wal"]
        let defaultNames = ["default"]

        for name in defaultNames {
            for ext in extensions {
                let url = appSupport.appendingPathComponent("\(name).\(ext)")
                try? fileManager.removeItem(at: url)
            }
        }

        // Also try to delete any .sqlite files SwiftData might create
        if let contents = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in contents {
                let filename = url.lastPathComponent
                if filename.hasSuffix(".store") || filename.hasSuffix(".store-shm") || filename.hasSuffix(".store-wal") {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }

    func createDefaultDiaryIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Diary>()

        do {
            let diaries = try context.fetch(descriptor)
            if diaries.isEmpty {
                let defaultDiary = Diary(
                    name: "Me & Me",
                    isProtected: false,
                    storagePreference: iCloudEnabled ? .iCloud : .local
                )
                context.insert(defaultDiary)
                try context.save()
            }
        } catch {
            print("Error creating default diary: \(error)")
        }
    }

    func getOrCreateSettings() -> AppSettings {
        let context = container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()

        do {
            let settings = try context.fetch(descriptor)
            if let existing = settings.first {
                return existing
            }

            let newSettings = AppSettings()
            context.insert(newSettings)
            try context.save()
            return newSettings
        } catch {
            let newSettings = AppSettings()
            context.insert(newSettings)
            return newSettings
        }
    }

    func save() {
        try? container.mainContext.save()
    }

    /// Fetch all diaries (visible and hidden)
    func fetchAllDiaries() -> [Diary] {
        let descriptor = FetchDescriptor<Diary>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }
}
