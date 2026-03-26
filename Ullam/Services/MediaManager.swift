import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import CryptoKit

enum MediaError: Error {
    case invalidData
    case saveFailed
    case loadFailed
    case fileNotFound
}

actor MediaManager {
    static let shared = MediaManager()

    private let fileManager = FileManager.default
    private let encryptionManager = EncryptionManager.shared

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var mediaDirectory: URL {
        documentsDirectory.appendingPathComponent("Media", isDirectory: true)
    }

    init() {
        Task { await createMediaDirectoryIfNeeded() }
    }

    private func createMediaDirectoryIfNeeded() async {
        if !fileManager.fileExists(atPath: mediaDirectory.path) {
            try? fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Save Media

    #if canImport(UIKit)
    func saveImage(_ image: UIImage, encrypted: Bool, key: SymmetricKey?) async throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw MediaError.invalidData
        }

        if encrypted, let key = key {
            let encryptedData = try await encryptionManager.encrypt(data, using: key)
            try encryptedData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }

        return fileName
    }

    func loadImage(fileName: String, encrypted: Bool, key: SymmetricKey?) async throws -> UIImage {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw MediaError.fileNotFound
        }

        var data = try Data(contentsOf: fileURL)

        if encrypted, let key = key {
            data = try await encryptionManager.decrypt(data, using: key)
        }

        guard let image = UIImage(data: data) else {
            throw MediaError.invalidData
        }

        return image
    }
    #endif

    func saveVideo(from sourceURL: URL, encrypted: Bool, key: SymmetricKey?) async throws -> (fileName: String, thumbnailFileName: String?) {
        let fileName = UUID().uuidString + ".mp4"
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        let data = try Data(contentsOf: sourceURL)

        if encrypted, let key = key {
            let encryptedData = try await encryptionManager.encrypt(data, using: key)
            try encryptedData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }

        // Generate thumbnail
        let thumbnailFileName = try await generateVideoThumbnail(from: sourceURL, encrypted: encrypted, key: key)

        return (fileName, thumbnailFileName)
    }

    func saveAudio(from sourceURL: URL, encrypted: Bool, key: SymmetricKey?) async throws -> String {
        let fileName = UUID().uuidString + ".m4a"
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        let data = try Data(contentsOf: sourceURL)

        if encrypted, let key = key {
            let encryptedData = try await encryptionManager.encrypt(data, using: key)
            try encryptedData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }

        return fileName
    }

    // MARK: - Load Media

    func loadVideoURL(fileName: String, encrypted: Bool, key: SymmetricKey?) async throws -> URL {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw MediaError.fileNotFound
        }

        if encrypted, let key = key {
            let data = try Data(contentsOf: fileURL)
            let decryptedData = try await encryptionManager.decrypt(data, using: key)

            let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try decryptedData.write(to: tempURL)
            return tempURL
        }

        return fileURL
    }

    func loadAudioURL(fileName: String, encrypted: Bool, key: SymmetricKey?) async throws -> URL {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw MediaError.fileNotFound
        }

        if encrypted, let key = key {
            let data = try Data(contentsOf: fileURL)
            let decryptedData = try await encryptionManager.decrypt(data, using: key)

            let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            try decryptedData.write(to: tempURL)
            return tempURL
        }

        return fileURL
    }

    // MARK: - Helpers

    #if canImport(UIKit)
    private func generateVideoThumbnail(from videoURL: URL, encrypted: Bool, key: SymmetricKey?) async throws -> String? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0, preferredTimescale: 600)

        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            return try await saveImage(thumbnail, encrypted: encrypted, key: key)
        } catch {
            return nil
        }
    }
    #else
    private func generateVideoThumbnail(from videoURL: URL, encrypted: Bool, key: SymmetricKey?) async throws -> String? {
        return nil
    }
    #endif

    func deleteMedia(fileName: String) throws {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func getMediaURL(fileName: String) -> URL {
        return mediaDirectory.appendingPathComponent(fileName)
    }
}
