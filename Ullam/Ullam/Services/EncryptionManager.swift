import Foundation
import CryptoKit

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidData
}

actor EncryptionManager {
    static let shared = EncryptionManager()

    private let keyLength = 32 // 256 bits for AES-256

    // MARK: - Key Derivation

    func deriveKey(from pincode: String, salt: Data) -> SymmetricKey {
        let pincodeData = Data(pincode.utf8)

        let inputKeyMaterial = SymmetricKey(data: pincodeData)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            info: Data("Ullam.Diary.Key".utf8),
            outputByteCount: keyLength
        )

        return derivedKey
    }

    func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return salt
    }

    func hashPincode(_ pincode: String, salt: Data) -> Data {
        let pincodeData = Data(pincode.utf8)
        let combined = pincodeData + salt
        let hash = SHA256.hash(data: combined)
        return Data(hash)
    }

    // MARK: - Encryption/Decryption

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    func encryptString(_ string: String, using key: SymmetricKey) throws -> Data {
        let data = Data(string.utf8)
        return try encrypt(data, using: key)
    }

    func decryptString(_ data: Data, using key: SymmetricKey) throws -> String {
        let decrypted = try decrypt(data, using: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        return string
    }

    // MARK: - Verify Pincode

    func verifyPincode(_ pincode: String, againstHash storedHash: Data, salt: Data) -> Bool {
        let computedHash = hashPincode(pincode, salt: salt)
        return computedHash == storedHash
    }
}
