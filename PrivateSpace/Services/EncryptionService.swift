import Foundation
import CryptoKit
import CommonCrypto

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case keyDerivationFailed
}

final class EncryptionService {
    static let shared = EncryptionService()

    private var symmetricKey: SymmetricKey?

    var hasKey: Bool {
        symmetricKey != nil
    }

    private init() {}

    // Derive 256-bit key from Master Password using PBKDF2-HMAC-SHA256
    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derivedKeyData = Data(count: 32)

        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        600_000,  // NIST recommended iterations as of 2026
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }

    // Generate random salt for key derivation
    func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return salt
    }

    // Load derived key into memory (called after successful unlock)
    func loadKey(_ key: Data) {
        symmetricKey = SymmetricKey(data: key)
    }

    // Clear key from memory (on lock)
    func clearKey() {
        symmetricKey = nil
    }

    // Encrypt string -> Data (for storing encryptedValue)
    func encrypt(_ string: String) throws -> Data {
        guard let key = symmetricKey else {
            throw EncryptionError.invalidKey
        }
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.encryptionFailed
        }
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

    // Decrypt Data -> string
    func decrypt(_ data: Data) throws -> String {
        guard let key = symmetricKey else {
            throw EncryptionError.invalidKey
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            guard let string = String(data: decryptedData, encoding: .utf8) else {
                throw EncryptionError.decryptionFailed
            }
            return string
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // Encrypt sensitive field when saving
    func encryptField(value: String) throws -> Data {
        try encrypt(value)
    }

    // Decrypt sensitive field when reading
    func decryptField(data: Data) throws -> String {
        try decrypt(data)
    }

    // Hash the encryption key for verification (not the same as deriving)
    func hashKey(_ key: Data) -> Data {
        let hash = SHA256.hash(data: key)
        return Data(hash)
    }

    // Verify encryption is working (used for testing)
    func verifyEncryption() -> Bool {
        guard let testKey = symmetricKey else { return false }
        let testData = "test".data(using: .utf8)!
        do {
            let sealedBox = try AES.GCM.seal(testData, using: testKey)
            guard let combined = sealedBox.combined else { return false }
            let unsealedBox = try AES.GCM.SealedBox(combined: combined)
            let decryptedData = try AES.GCM.open(unsealedBox, using: testKey)
            return decryptedData == testData
        } catch {
            return false
        }
    }
}