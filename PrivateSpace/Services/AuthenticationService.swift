import Foundation
import Combine
import CryptoKit
import LocalAuthentication

enum AuthenticationError: Error {
    case biometryNotAvailable
    case biometryNotEnrolled
    case authenticationFailed
    case userCancelled
    case keyNotFound
}

final class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var biometryType: LABiometryType = .none

    private let context = LAContext()

    private init() {
        checkBiometryType()
    }

    func checkBiometryType() {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        } else {
            biometryType = .none
        }
    }

    var isBiometryAvailable: Bool {
        biometryType != .none
    }

    var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "生物识别"
        }
    }

    // Authenticate with Face ID/Touch ID
    func authenticateWithBiometrics() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "使用密码"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    throw AuthenticationError.biometryNotEnrolled
                default:
                    throw AuthenticationError.biometryNotAvailable
                }
            }
            throw AuthenticationError.biometryNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁 Vault"
            )
            if success {
                // Load encryption key from Keychain after biometric success
                if let key = try KeychainService.shared.retrieveEncryptionKey() {
                    EncryptionService.shared.loadKey(key)
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } else {
                    throw AuthenticationError.keyNotFound
                }
            } else {
                throw AuthenticationError.authenticationFailed
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .userFallback:
                throw AuthenticationError.userCancelled
            default:
                throw AuthenticationError.authenticationFailed
            }
        }
    }

    // Authenticate with Master Password
    func authenticateWithPassword(_ password: String) async throws {
        guard !password.isEmpty else {
            throw AuthenticationError.authenticationFailed
        }

        if KeychainService.shared.hasEncryptionKey() {
            // Retrieve stored salt and verification hash
            guard let salt = try KeychainService.shared.retrieveSalt(),
                  let storedHash = try KeychainService.shared.retrievePasswordHash() else {
                throw AuthenticationError.authenticationFailed
            }

            // Derive key from entered password and compare hash
            let derivedKey = try EncryptionService.shared.deriveKey(from: password, salt: salt)
            let derivedKeyData = derivedKey.withUnsafeBytes { Data($0) }
            let derivedHash = EncryptionService.shared.hashKey(derivedKeyData)

            guard derivedHash == storedHash else {
                throw AuthenticationError.authenticationFailed
            }

            // Load the stored encryption key
            if let key = try? KeychainService.shared.retrieveEncryptionKey() {
                EncryptionService.shared.loadKey(key)
                await MainActor.run {
                    self.isAuthenticated = true
                }
            } else {
                throw AuthenticationError.keyNotFound
            }
        } else {
            throw AuthenticationError.authenticationFailed // Should use setupMasterPassword for first time
        }
    }

    func setupMasterPassword(_ password: String) throws {
        let salt = EncryptionService.shared.generateSalt()
        let derivedKey = try EncryptionService.shared.deriveKey(from: password, salt: salt)
        let derivedKeyData = derivedKey.withUnsafeBytes { Data($0) }
        let verificationHash = EncryptionService.shared.hashKey(derivedKeyData)

        // Store salt and verification hash separately
        try KeychainService.shared.storeSalt(salt)
        try KeychainService.shared.storePasswordHash(verificationHash)
        try KeychainService.shared.storeEncryptionKey(derivedKeyData)

        EncryptionService.shared.loadKey(derivedKeyData)
        isAuthenticated = true
    }

    func lock() {
        EncryptionService.shared.clearKey()
        isAuthenticated = false
    }
}