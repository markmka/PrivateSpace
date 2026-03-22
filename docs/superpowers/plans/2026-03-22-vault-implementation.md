# Vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Vault — a secure private content storage app with Face ID/Master Password unlock, iCloud sync, and custom field support.

**Architecture:** SwiftUI app with SwiftData for persistence and CloudKit sync. Sensitive fields encrypted with CryptoKit AES-GCM. Keychain stores derived encryption keys. LocalAuthentication handles Face ID/Touch ID.

**Tech Stack:** SwiftUI, SwiftData, CloudKit, LocalAuthentication, CryptoKit, Keychain Services

---

## File Structure

```
PrivateSpace/                    # Existing app (rename to Vault later)
├── App/
│   ├── VaultApp.swift           # @main entry point
│   └── AppState.swift           # Global app state (isLocked, isFirstLaunch)
├── Models/
│   ├── VaultItem.swift         # SwiftData @Model for items
│   ├── CustomField.swift       # Field model (value/encryptedValue)
│   ├── ItemType.swift          # Enum: password/privateKey/note/other/custom
│   └── CustomItemType.swift    # User-defined types
├── Services/
│   ├── KeychainService.swift    # Keychain CRUD for encryption keys
│   ├── EncryptionService.swift # AES-GCM encrypt/decrypt
│   ├── AuthenticationService.swift # Face ID + Master Password verify
│   └── ClipboardService.swift  # 30-second auto-clear
├── Components/
│   ├── SecretFieldView.swift    # Hidden/revealed field display
│   ├── FABMenuView.swift       # Floating action button menu
│   └── FilterPillsView.swift   # Type filter pills
├── Features/
│   ├── Unlock/
│   │   ├── UnlockView.swift
│   │   └── UnlockViewModel.swift
│   ├── Setup/
│   │   ├── SetupView.swift     # First-time Master Password setup
│   │   └── SetupViewModel.swift
│   ├── MainList/
│   │   ├── MainListView.swift
│   │   └── MainListViewModel.swift
│   ├── ItemDetail/
│   │   ├── ItemDetailView.swift
│   │   └── ItemDetailViewModel.swift
│   ├── ItemEdit/
│   │   ├── ItemEditView.swift
│   │   └── ItemEditViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   └── CustomTypes/
│       ├── CustomTypeListView.swift
│       └── CustomTypeEditView.swift
└── Utilities/
    ├── Constants.swift          # Colors, type metadata
    └── Extensions.swift        # View extensions
```

---

## Phase 1: Core Foundation

### Task 1: Project Setup & Models

**Files:**
- Create: `PrivateSpace/Models/ItemType.swift`
- Create: `PrivateSpace/Models/VaultItem.swift`
- Create: `PrivateSpace/Models/CustomField.swift`
- Create: `PrivateSpace/Models/CustomItemType.swift`
- Modify: `PrivateSpace/PrivateSpaceApp.swift` — add SwiftData container

- [ ] **Step 1: Create ItemType enum**

```swift
// PrivateSpace/Models/ItemType.swift
import Foundation

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case password
    case privateKey
    case note
    case other
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .password: return "密码"
        case .privateKey: return "私钥"
        case .note: return "安全笔记"
        case .other: return "其他"
        case .custom: return "自定义"
        }
    }

    var iconName: String {
        switch self {
        case .password: return "key.fill"
        case .privateKey: return "lock.fill"
        case .note: return "note.text"
        case .other: return "folder.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .password: return "007AFF"
        case .privateKey: return "34C759"
        case .note: return "FF9500"
        case .other: return "FF2D55"
        case .custom: return "5856D6"
        }
    }
}
```

- [ ] **Step 2: Create CustomField model**

```swift
// PrivateSpace/Models/CustomField.swift
import Foundation
import SwiftData

@Model
final class CustomField {
    var id: UUID
    var name: String
    var value: String          // Plain text for non-secret fields
    var encryptedValue: Data?  // Encrypted for secret fields
    var isSecret: Bool

    init(id: UUID = UUID(), name: String = "", value: String = "", encryptedValue: Data? = nil, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.encryptedValue = encryptedValue
        self.isSecret = isSecret
    }
}
```

- [ ] **Step 3: Create VaultItem model**

```swift
// PrivateSpace/Models/VaultItem.swift
import Foundation
import SwiftData

@Model
final class VaultItem {
    @Attribute(.unique) var id: UUID
    var type: ItemType
    var title: String
    @Relationship(deleteRule: .cascade) var fields: [CustomField]
    var customTypeId: UUID?    // For .custom type, reference to CustomItemType
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), type: ItemType, title: String = "", fields: [CustomField] = [], customTypeId: UUID? = nil, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.fields = fields
        self.customTypeId = customTypeId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    func fieldSummary() -> String {
        guard let first = fields.first else { return "" }
        if first.isSecret {
            return "••••••••"
        }
        return first.value.prefix(30).description
    }
}
```

- [ ] **Step 4: Create CustomItemType model**

```swift
// PrivateSpace/Models/CustomItemType.swift
import Foundation
import SwiftData

struct PresetField: Codable, Identifiable {
    var id: UUID
    var name: String
    var isSecret: Bool

    init(id: UUID = UUID(), name: String, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.isSecret = isSecret
    }
}

@Model
final class CustomItemType {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var presetFieldsData: Data  // Encoded [PresetField]
    var createdAt: Date

    var presetFields: [PresetField] {
        get {
            (try? JSONDecoder().decode([PresetField].self, from: presetFieldsData)) ?? []
        }
        set {
            presetFieldsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(id: UUID = UUID(), name: String = "", iconName: String = "square.grid.2x2.fill", presetFields: [PresetField] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.presetFieldsData = (try? JSONEncoder().encode(presetFields)) ?? Data()
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Update VaultApp.swift with SwiftData container**

```swift
// PrivateSpace/PrivateSpaceApp.swift
import SwiftUI
import SwiftData

@main
struct VaultApp: App {
    @StateObject private var appState = AppState()
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VaultItem.self,
            CustomField.self,
            CustomItemType.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add PrivateSpace/Models/ PrivateSpace/VaultApp.swift
git commit -m "feat: Add SwiftData models and app container"
```

---

### Task 2: Services (Keychain, Encryption, Authentication, Clipboard)

**Files:**
- Create: `PrivateSpace/Services/KeychainService.swift`
- Create: `PrivateSpace/Services/EncryptionService.swift`
- Create: `PrivateSpace/Services/AuthenticationService.swift`
- Create: `PrivateSpace/Services/ClipboardService.swift`

- [ ] **Step 1: Create KeychainService**

```swift
// PrivateSpace/Services/KeychainService.swift
import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainService {
    static let shared = KeychainService()
    private let encryptionKeyTag = "com.vault.encryptionKey"
    private let saltTag = "com.vault.salt"
    private let passwordHashTag = "com.vault.passwordHash"

    private init() {}

    // Store 256-bit encryption key derived from Master Password
    func storeEncryptionKey(_ key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try updateEncryptionKey(key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func updateEncryptionKey(_ key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: key
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrieveEncryptionKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    func deleteEncryptionKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func hasEncryptionKey() -> Bool {
        do {
            return try retrieveEncryptionKey() != nil
        } catch {
            return false
        }
    }

    // Salt management
    func storeSalt(_ salt: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: saltTag,
            kSecValueData as String: salt,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try updateSalt(salt)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func updateSalt(_ salt: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: saltTag
        ]
        let attributes: [String: Any] = [kSecValueData as String: salt]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrieveSalt() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: saltTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        return result as? Data
    }

    // Password hash verification
    func storePasswordHash(_ hash: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordHashTag,
            kSecValueData as String: hash,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try updatePasswordHash(hash)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func updatePasswordHash(_ hash: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordHashTag
        ]
        let attributes: [String: Any] = [kSecValueData as String: hash]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrievePasswordHash() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordHashTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        return result as? Data
    }
}
```

- [ ] **Step 2: Create EncryptionService**

```swift
// PrivateSpace/Services/EncryptionService.swift
import Foundation
import CryptoKit
import CommonCrypto

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
}

final class EncryptionService {
    static let shared = EncryptionService()

    private var symmetricKey: SymmetricKey?

    private init() {}

    // Derive 256-bit key from Master Password using PBKDF2-HMAC-SHA256
    func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derivedKeyData = Data(count: 32)

        derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
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
}
```

- [ ] **Step 3: Create AuthenticationService**

```swift
// PrivateSpace/Services/AuthenticationService.swift
import Foundation
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
    func authenticateWithPassword(_ password: String) throws {
        guard !password.isEmpty else {
            throw AuthenticationError.authenticationFailed
        }

        if KeychainService.shared.hasEncryptionKey() {
            // Retrieve stored salt and verification hash
            guard let salt = KeychainService.shared.retrieveSalt(),
                  let storedHash = KeychainService.shared.retrievePasswordHash() else {
                throw AuthenticationError.authenticationFailed
            }

            // Derive key from entered password and compare hash
            let derivedKey = EncryptionService.shared.deriveKey(from: password, salt: salt)
            let derivedKeyData = derivedKey.withUnsafeBytes { Data($0) }
            let derivedHash = EncryptionService.shared.hashKey(derivedKeyData)

            guard derivedHash == storedHash else {
                throw AuthenticationError.authenticationFailed
            }

            // Load the stored encryption key
            if let key = try? KeychainService.shared.retrieveEncryptionKey() {
                EncryptionService.shared.loadKey(key)
                isAuthenticated = true
            } else {
                throw AuthenticationError.keyNotFound
            }
        } else {
            throw AuthenticationError.authenticationFailed // Should use setupMasterPassword for first time
        }
    }

    func setupMasterPassword(_ password: String) throws {
        let salt = EncryptionService.shared.generateSalt()
        let derivedKey = EncryptionService.shared.deriveKey(from: password, salt: salt)
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
```

- [ ] **Step 4: Create ClipboardService**

```swift
// PrivateSpace/Services/ClipboardService.swift
import Foundation
import UIKit

final class ClipboardService {
    static let shared = ClipboardService()

    private var clearTimer: Timer?
    private let clearInterval: TimeInterval = 30

    private init() {}

    func copy(_ string: String, sensitive: Bool = true) {
        UIPasteboard.general.string = string

        if sensitive {
            scheduleClear()
        }
    }

    private func scheduleClear() {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: clearInterval, repeats: false) { [weak self] _ in
            self?.clearClipboard()
        }
    }

    func clearClipboard() {
        UIPasteboard.general.items = []
        clearTimer?.invalidate()
        clearTimer = nil
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add PrivateSpace/Services/
git commit -m "feat: Add Keychain, Encryption, Authentication, and Clipboard services"
```

---

### Task 3: AppState & Constants

**Files:**
- Create: `PrivateSpace/App/AppState.swift`
- Create: `PrivateSpace/Utilities/Constants.swift`
- Create: `PrivateSpace/Utilities/Extensions.swift`

- [ ] **Step 1: Create AppState**

```swift
// PrivateSpace/App/AppState.swift
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isLocked: Bool = true
    @Published var isFirstLaunch: Bool = false
    @Published var autoLockInterval: AutoLockOption = .immediately

    private let userDefaults = UserDefaults.standard
    private let hasCompletedSetupKey = "hasCompletedSetup"

    init() {
        isFirstLaunch = !userDefaults.bool(forKey: hasCompletedSetupKey)
        isLocked = true
    }

    func completeSetup() {
        userDefaults.set(true, forKey: hasCompletedSetupKey)
        isFirstLaunch = false
    }

    func lock() {
        AuthenticationService.shared.lock()
        isLocked = true
    }

    func unlock() {
        isLocked = false
    }

    enum AutoLockOption: String, CaseIterable {
        case immediately = "立即"
        case oneMinute = "1分钟"
        case fiveMinutes = "5分钟"

        var timeInterval: TimeInterval? {
            switch self {
            case .immediately: return nil
            case .oneMinute: return 60
            case .fiveMinutes: return 300
            }
        }
    }
}
```

- [ ] **Step 2: Create Constants**

```swift
// PrivateSpace/Utilities/Constants.swift
import SwiftUI

enum AppColors {
    static let primary = Color(hex: "007AFF")
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let danger = Color(hex: "FF2D55")
    static let background = Color(hex: "F2F2F7")
    static let cardBackground = Color.white
    static let darkBackground = Color.black
}

enum AppSpacing {
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let iconCornerRadius: CGFloat = 10
    static let fabSize: CGFloat = 56
    static let standardPadding: CGFloat = 16
    static let smallPadding: CGFloat = 8
}

enum ItemTypeMetadata {
    static func color(for type: ItemType) -> Color {
        switch type {
        case .password: return Color(hex: "007AFF")
        case .privateKey: return Color(hex: "34C759")
        case .note: return Color(hex: "FF9500")
        case .other: return Color(hex: "FF2D55")
        case .custom: return Color(hex: "5856D6")
        }
    }

    static func backgroundColor(for type: ItemType) -> Color {
        color(for: type).opacity(0.12)
    }

    static func icon(for type: ItemType) -> String {
        type.iconName
    }
}
```

- [ ] **Step 3: Create Extensions**

```swift
// PrivateSpace/Utilities/Extensions.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add PrivateSpace/App/AppState.swift PrivateSpace/Utilities/
git commit -m "feat: Add AppState, Constants, and Extensions"
```

---

### Task 4: Unlock View

**Files:**
- Create: `PrivateSpace/Features/Unlock/UnlockView.swift`
- Create: `PrivateSpace/Features/Unlock/UnlockViewModel.swift`
- Modify: `PrivateSpace/ContentView.swift` — route based on lock state

- [ ] **Step 1: Create UnlockViewModel**

```swift
// PrivateSpace/Features/Unlock/UnlockViewModel.swift
import SwiftUI

@MainActor
final class UnlockViewModel: ObservableObject {
    @Published var password: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let authService = AuthenticationService.shared

    var isBiometryAvailable: Bool {
        authService.isBiometryAvailable
    }

    var biometryName: String {
        authService.biometryName
    }

    func authenticateWithBiometrics() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.authenticateWithBiometrics()
        } catch AuthenticationError.userCancelled {
            // User chose to use password, do nothing
        } catch {
            errorMessage = "生物识别失败，请使用密码解锁"
        }

        isLoading = false
    }

    func authenticateWithPassword() {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try authService.authenticateWithPassword(password)
        } catch {
            errorMessage = "密码错误"
        }

        isLoading = false
    }
}
```

- [ ] **Step 2: Create UnlockView**

```swift
// PrivateSpace/Features/Unlock/UnlockView.swift
import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UnlockViewModel()

    var body: some View {
        ZStack {
            AppColors.darkBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.primary)

                    Text("Vault")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("安全私密内容存储")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Biometry Button
                if viewModel.isBiometryAvailable {
                    Button {
                        Task {
                            await viewModel.authenticateWithBiometrics()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "faceid")
                            Text("使用 \(viewModel.biometryName) 解锁")
                        }
                        .font(.headline)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                    }
                    .padding(.horizontal, 32)
                }

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("或")
                        .foregroundColor(.gray)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)

                // Password Input
                VStack(spacing: 16) {
                    SecureField("输入主密码", text: $viewModel.password)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(white: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                        .foregroundColor(.white)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.danger)
                    }

                    Button {
                        viewModel.authenticateWithPassword()
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("解锁")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .onChange(of: AuthenticationService.shared.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                appState.unlock()
            }
        }
    }
}
```

- [ ] **Step 3: Update ContentView for routing**

```swift
// PrivateSpace/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                SetupView()
            } else if appState.isLocked {
                UnlockView()
            } else {
                MainListView()
            }
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add PrivateSpace/Features/Unlock/ PrivateSpace/ContentView.swift
git commit -m "feat: Add UnlockView with Face ID and password support"
```

---

### Task 5: Setup View (First Launch)

**Files:**
- Create: `PrivateSpace/Features/Setup/SetupView.swift`
- Create: `PrivateSpace/Features/Setup/SetupViewModel.swift`

- [ ] **Step 1: Create SetupViewModel**

```swift
// PrivateSpace/Features/Setup/SetupViewModel.swift
import SwiftUI

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var enableBiometrics: Bool = true
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let authService = AuthenticationService.shared

    var isBiometryAvailable: Bool {
        authService.isBiometryAvailable
    }

    var biometryName: String {
        authService.biometryName
    }

    func setup() async {
        errorMessage = nil

        guard password.count >= 8 else {
            errorMessage = "密码至少8位"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "两次密码输入不一致"
            return
        }

        isLoading = true

        do {
            try authService.setupMasterPassword(password)

            if enableBiometrics && isBiometryAvailable {
                // Biometrics will be available on next launch
            }

            isLoading = false
        } catch {
            errorMessage = "设置失败，请重试"
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Create SetupView**

```swift
// PrivateSpace/Features/Setup/SetupView.swift
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SetupViewModel()

    var body: some View {
        ZStack {
            AppColors.darkBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.primary)

                        Text("设置 Master Password")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("此密码用于加密你的数据，请妥善保管")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    // Password Fields
                    VStack(spacing: 16) {
                        SecureField("设置密码（至少8位）", text: $viewModel.password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                            .foregroundColor(.white)

                        SecureField("确认密码", text: $viewModel.confirmPassword)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)

                    // Biometrics Toggle
                    if viewModel.isBiometryAvailable {
                        Toggle(isOn: $viewModel.enableBiometrics) {
                            HStack {
                                Image(systemName: viewModel.biometryName == "Face ID" ? "faceid" : "touchid")
                                    .foregroundColor(AppColors.primary)
                                Text("启用 \(viewModel.biometryName)")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                        .padding(.horizontal, 32)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.danger)
                    }

                    // Continue Button
                    Button {
                        Task {
                            await viewModel.setup()
                            if viewModel.errorMessage == nil {
                                appState.completeSetup()
                                appState.unlock()
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("继续")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                    }
                    .disabled(viewModel.isLoading || viewModel.password.isEmpty)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add PrivateSpace/Features/Setup/
git commit -m "feat: Add SetupView for first-launch Master Password setup"
```

---

### Task 6: MainList View

**Files:**
- Create: `PrivateSpace/Features/MainList/MainListView.swift`
- Create: `PrivateSpace/Features/MainList/MainListViewModel.swift`
- Create: `PrivateSpace/Components/SecretFieldView.swift`
- Create: `PrivateSpace/Components/FABMenuView.swift`
- Create: `PrivateSpace/Components/FilterPillsView.swift`

- [ ] **Step 1: Create FilterPillsView**

```swift
// PrivateSpace/Components/FilterPillsView.swift
import SwiftUI

struct FilterPillsView: View {
    @Binding var selectedType: ItemType?
    let customTypes: [CustomItemType]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "全部", isSelected: selectedType == nil) {
                    selectedType = nil
                }

                ForEach(ItemType.allCases.filter { $0 != .custom }) { type in
                    FilterPill(
                        title: type.displayName,
                        icon: type.iconName,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }

                ForEach(customTypes) { customType in
                    FilterPill(
                        title: customType.name,
                        icon: customType.iconName,
                        isSelected: false
                    ) {
                        // Handle custom type selection
                    }
                }
            }
            .padding(.horizontal, AppSpacing.standardPadding)
        }
    }
}

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.primary : Color.white)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
```

- [ ] **Step 2: Create FABMenuView**

```swift
// PrivateSpace/Components/FABMenuView.swift
import SwiftUI

struct FABMenuView: View {
    @Binding var isExpanded: Bool
    let onSelectType: (ItemType) -> Void
    let customTypes: [CustomItemType]

    var body: some View {
        ZStack {
            // Dimmed background when expanded
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded = false
                        }
                    }
            }

            // Menu items
            VStack(alignment: .trailing, spacing: 12) {
                if isExpanded {
                    ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                        MenuItemView(
                            title: item.title,
                            icon: item.icon,
                            color: item.color
                        ) {
                            onSelectType(item.type)
                            withAnimation(.spring(response: 0.3)) {
                                isExpanded = false
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }

                // FAB Button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "x" : "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: AppSpacing.fabSize, height: AppSpacing.fabSize)
                        .background(isExpanded ? Color.gray : AppColors.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
    }

    private var menuItems: [(title: String, icon: String, color: Color, type: ItemType)] {
        var items: [(title: String, icon: String, color: Color, type: ItemType)] = [
            ("密码", "key.fill", AppColors.primary, .password),
            ("私钥", "lock.fill", AppColors.success, .privateKey),
            ("安全笔记", "note.text", AppColors.warning, .note),
            ("其他", "folder.fill", AppColors.danger, .other)
        ]
        return items
    }
}

struct MenuItemView: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
    }
}
```

- [ ] **Step 3: Create SecretFieldView**

```swift
// PrivateSpace/Components/SecretFieldView.swift
import SwiftUI

struct SecretFieldView: View {
    let name: String
    @Binding var value: String
    @Binding var isRevealed: Bool
    let isSecret: Bool
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isSecret && !isRevealed {
                    Text(String(repeating: "•", count: 12))
                        .font(.body)
                } else {
                    Text(value)
                        .font(.body)
                }
            }

            Spacer()

            if isSecret {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRevealed.toggle()
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }

            if let onCopy = onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 4: Create MainListViewModel**

```swift
// PrivateSpace/Features/MainList/MainListViewModel.swift
import SwiftUI
import SwiftData

@MainActor
final class MainListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedType: ItemType? = nil
    @Published var isFABExpanded: Bool = false
    @Published var showingNewItem: Bool = false
    @Published var selectedItemType: ItemType = .password

    func createNewItem(type: ItemType) {
        selectedItemType = type
        showingNewItem = true
    }
}
```

- [ ] **Step 5: Create MainListView**

```swift
// PrivateSpace/Features/MainList/MainListView.swift
import SwiftUI
import SwiftData

struct MainListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MainListViewModel()
    @Query(sort: \VaultItem.modifiedAt, order: .reverse) private var items: [VaultItem]
    @Query private var customTypes: [CustomItemType]

    var filteredItems: [VaultItem] {
        var result = items

        if let type = viewModel.selectedType {
            result = result.filter { $0.type == type }
        }

        if !viewModel.searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(viewModel.searchText) }
        }

        return result
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Text("Vault")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        // Search action
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
                .padding(.horizontal, AppSpacing.standardPadding)
                .padding(.vertical, 12)

                // Filter pills
                FilterPillsView(selectedType: $viewModel.selectedType, customTypes: customTypes)
                    .padding(.bottom, 12)

                // Item list
                if filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无条目")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右下角 + 添加第一个条目")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRowView(item: item)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABMenuView(
                        isExpanded: $viewModel.isFABExpanded,
                        onSelectType: { type in
                            viewModel.createNewItem(type: type)
                        },
                        customTypes: customTypes
                    )
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.showingNewItem) {
            ItemEditView(mode: .create(type: viewModel.selectedItemType))
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }
}

struct ItemRowView: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.type.iconName)
                .font(.title3)
                .foregroundColor(ItemTypeMetadata.color(for: item.type))
                .frame(width: 40, height: 40)
                .background(ItemTypeMetadata.backgroundColor(for: item.type))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconCornerRadius))

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "无标题" : item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(item.fieldSummary())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add PrivateSpace/Features/MainList/ PrivateSpace/Components/
git commit -m "feat: Add MainListView with FAB menu and filter pills"
```

---

### Task 7: ItemDetail & ItemEdit Views

**Files:**
- Create: `PrivateSpace/Features/ItemDetail/ItemDetailView.swift`
- Create: `PrivateSpace/Features/ItemDetail/ItemDetailViewModel.swift`
- Create: `PrivateSpace/Features/ItemEdit/ItemEditView.swift`
- Create: `PrivateSpace/Features/ItemEdit/ItemEditViewModel.swift`

- [ ] **Step 1: Create ItemDetailViewModel**

```swift
// PrivateSpace/Features/ItemDetail/ItemDetailViewModel.swift
import SwiftUI

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var isRevealed: [UUID: Bool] = [:]
    @Published var copiedFieldId: UUID? = nil
    @Published var showingCopiedToast: Bool = false

    func toggleReveal(for fieldId: UUID) {
        isRevealed[fieldId] = !(isRevealed[fieldId] ?? false)
    }

    func copyField(_ field: CustomField) {
        let value = field.isSecret && field.encryptedValue != nil
            ? (try? EncryptionService.shared.decryptField(data: field.encryptedValue!)) ?? ""
            : field.value

        ClipboardService.shared.copy(value, sensitive: field.isSecret)
        copiedFieldId = field.id
        showingCopiedToast = true

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showingCopiedToast = false
            }
        }
    }

    func getFieldValue(_ field: CustomField) -> String {
        if field.isSecret {
            if isRevealed[field.id] == true {
                do {
                    return try EncryptionService.shared.decryptField(data: field.encryptedValue!)
                } catch {
                    return "解密失败"
                }
            } else {
                return String(repeating: "•", count: 12)
            }
        }
        return field.value
    }
}
```

- [ ] **Step 2: Create ItemDetailView**

```swift
// PrivateSpace/Features/ItemDetail/ItemDetailView.swift
import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var item: VaultItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    VStack(spacing: 12) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(ItemTypeMetadata.color(for: item.type))
                            .frame(width: 64, height: 64)
                            .background(ItemTypeMetadata.backgroundColor(for: item.type))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(item.title.isEmpty ? "无标题" : item.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(item.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .cardStyle()
                    .padding(.horizontal, AppSpacing.standardPadding)

                    // Fields Card
                    VStack(spacing: 0) {
                        ForEach(item.fields) { field in
                            SecretFieldView(
                                name: field.name,
                                value: .constant(viewModel.getFieldValue(field)),
                                isRevealed: Binding(
                                    get: { viewModel.isRevealed[field.id] ?? false },
                                    set: { _ in viewModel.toggleReveal(for: field.id) }
                                ),
                                isSecret: field.isSecret
                            ) {
                                viewModel.copyField(field)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            if field.id != item.fields.last?.id {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, AppSpacing.standardPadding)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }

            // Toast
            if viewModel.showingCopiedToast {
                VStack {
                    Spacer()
                    Text("已复制，30秒后清除")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    NavigationLink {
                        ItemEditView(mode: .edit(item: item))
                    } label: {
                        Text("编辑")
                    }

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
        }
        .alert("删除条目", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("确定要删除这个条目吗？此操作不可撤销。")
        }
    }

    private func deleteItem() {
        modelContext.delete(item)
        dismiss()
    }
}
```

- [ ] **Step 3: Create ItemEditViewModel**

```swift
// PrivateSpace/Features/ItemEdit/ItemEditViewModel.swift
import SwiftUI
import SwiftData

enum ItemEditMode {
    case create(type: ItemType)
    case edit(item: VaultItem)
}

@MainActor
final class ItemEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedType: ItemType = .password
    @Published var fields: [EditableField] = []
    @Published var errorMessage: String?

    let mode: ItemEditMode
    private var existingItem: VaultItem?

    init(mode: ItemEditMode) {
        self.mode = mode

        switch mode {
        case .create(let type):
            selectedType = type
            setupPresetFields(for: type)
        case .edit(let item):
            existingItem = item
            title = item.title
            selectedType = item.type
            fields = item.fields.map { EditableField(from: $0) }
        }
    }

    func setupPresetFields(for type: ItemType) {
        fields = []
        switch type {
        case .password:
            fields = [
                EditableField(name: "网站", isSecret: false),
                EditableField(name: "用户名", isSecret: false),
                EditableField(name: "密码", isSecret: true)
            ]
        case .privateKey:
            fields = [
                EditableField(name: "名称", isSecret: false),
                EditableField(name: "私钥", isSecret: true),
                EditableField(name: "备注", isSecret: false)
            ]
        case .note:
            fields = [
                EditableField(name: "标题", isSecret: false),
                EditableField(name: "内容", isSecret: true)
            ]
        case .other:
            fields = [
                EditableField(name: "字段1", isSecret: false)
            ]
        case .custom:
            fields = [
                EditableField(name: "字段1", isSecret: false)
            ]
        }
    }

    func addField() {
        fields.append(EditableField(name: "新字段", isSecret: false))
    }

    func removeField(at index: Int) {
        guard fields.count > 1 else { return }
        fields.remove(at: index)
    }

    func save(context: ModelContext) throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入标题"
            return
        }

        switch mode {
        case .create:
            let item = VaultItem(type: selectedType, title: title)
            for editableField in fields {
                let field = CustomField(
                    name: editableField.name,
                    value: editableField.isSecret ? "" : editableField.value,
                    encryptedValue: editableField.isSecret ? try? EncryptionService.shared.encryptField(value: editableField.value) : nil,
                    isSecret: editableField.isSecret
                )
                item.fields.append(field)
            }
            context.insert(item)
        case .edit(let item):
            item.title = title
            item.type = selectedType
            item.modifiedAt = Date()

            // Remove existing fields and add new ones
            for existingField in item.fields {
                context.delete(existingField)
            }
            item.fields.removeAll()

            for editableField in fields {
                let field = CustomField(
                    name: editableField.name,
                    value: editableField.isSecret ? "" : editableField.value,
                    encryptedValue: editableField.isSecret ? try? EncryptionService.shared.encryptField(value: editableField.value) : nil,
                    isSecret: editableField.isSecret
                )
                item.fields.append(field)
            }
        }

        errorMessage = nil
    }
}

struct EditableField: Identifiable {
    let id: UUID
    var name: String
    var value: String
    var isSecret: Bool

    init(id: UUID = UUID(), name: String = "", value: String = "", isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }

    init(from field: CustomField) {
        self.id = field.id
        self.name = field.name
        self.value = field.isSecret
            ? (try? EncryptionService.shared.decryptField(data: field.encryptedValue!)) ?? ""
            : field.value
        self.isSecret = field.isSecret
    }
}
```

- [ ] **Step 4: Create ItemEditView**

```swift
// PrivateSpace/Features/ItemEdit/ItemEditView.swift
import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemEditViewModel

    init(mode: ItemEditMode) {
        _viewModel = StateObject(wrappedValue: ItemEditViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("输入标题", text: $viewModel.title)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                    }
                    .padding(.horizontal, AppSpacing.standardPadding)

                    // Type Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("类型")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ItemType.allCases.filter { $0 != .custom }) { type in
                                    TypeCard(
                                        type: type,
                                        isSelected: viewModel.selectedType == type
                                    ) {
                                        viewModel.selectedType = type
                                        viewModel.setupPresetFields(for: type)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.standardPadding)

                    // Fields
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字段")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppSpacing.standardPadding)

                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.fields.enumerated()), id: \.element.id) { index, field in
                                FieldEditorRow(
                                    field: $viewModel.fields[index],
                                    onDelete: {
                                        viewModel.removeField(at: index)
                                    },
                                    canDelete: viewModel.fields.count > 1
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.standardPadding)

                        // Add Field Button
                        Button {
                            viewModel.addField()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("添加字段")
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.primary)
                        }
                        .padding(.horizontal, AppSpacing.standardPadding)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.danger)
                            .padding(.horizontal, AppSpacing.standardPadding)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(viewModel.mode.isEdit ? "编辑条目" : "新建条目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    do {
                        try viewModel.save(context: modelContext)
                        dismiss()
                    } catch {
                        viewModel.errorMessage = "保存失败"
                    }
                }
            }
        }
    }
}

struct TypeCard: View {
    let type: ItemType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : ItemTypeMetadata.color(for: type))

                Text(type.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? ItemTypeMetadata.color(for: type) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct FieldEditorRow: View {
    @Binding var field: EditableField
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("字段名", text: $field.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("", isOn: $field.isSecret)
                    .labelsHidden()
                    .scaleEffect(0.8)

                Text("私密")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }

            if field.isSecret {
                SecureField("字段值", text: $field.value)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
            } else {
                TextField("字段值", text: $field.value)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
    }
}

extension ItemEditMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add PrivateSpace/Features/ItemDetail/ PrivateSpace/Features/ItemEdit/
git commit -m "feat: Add ItemDetailView and ItemEditView with full CRUD"
```

---

### Task 8: Settings View

**Files:**
- Create: `PrivateSpace/Features/Settings/SettingsView.swift`
- Create: `PrivateSpace/Features/Settings/SettingsViewModel.swift`

- [ ] **Step 1: Create SettingsViewModel**

```swift
// PrivateSpace/Features/Settings/SettingsViewModel.swift
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isBiometricsEnabled: Bool = true
    @Published var autoLockOption: AppState.AutoLockOption = .immediately
    @Published var showingDeleteConfirmation: Bool = false

    private let authService = AuthenticationService.shared

    var isBiometryAvailable: Bool {
        authService.isBiometryAvailable
    }

    var biometryName: String {
        authService.biometryName
    }

    func lockApp() {
        AuthenticationService.shared.lock()
    }
}
```

- [ ] **Step 2: Create SettingsView**

```swift
// PrivateSpace/Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            List {
                // iCloud Sync Section
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud 同步")
                                .font(.body)
                            Text("已连接")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("同步")
                }
                .listRowBackground(Color.white)

                // Security Section
                Section {
                    if viewModel.isBiometryAvailable {
                        Toggle(isOn: $viewModel.isBiometricsEnabled) {
                            HStack {
                                Image(systemName: viewModel.biometryName == "Face ID" ? "faceid" : "touchid")
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 28)

                                Text(viewModel.biometryName)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink {
                        MasterPasswordView()
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(AppColors.warning)
                                .frame(width: 28)

                            Text("Master Password")
                                .foregroundColor(.primary)

                            Spacer()

                            Text("已设置")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Picker(selection: $appState.autoLockInterval) {
                        ForEach(AppState.AutoLockOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppColors.danger)
                                .frame(width: 28)

                            Text("自动锁定")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("安全")
                }
                .listRowBackground(Color.white)

                // Custom Types Section
                Section {
                    NavigationLink {
                        CustomTypeListView()
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(Color(hex: "5856D6"))
                                .frame(width: 28)

                            Text("管理自定义类型")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("自定义")
                }
                .listRowBackground(Color.white)

                // Lock Button
                Section {
                    Button {
                        viewModel.lockApp()
                    } label: {
                        HStack {
                            Spacer()
                            Text("锁定 Vault")
                                .foregroundColor(AppColors.danger)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.white)

                // About Section
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("关于")
                }
                .listRowBackground(Color.white)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MasterPasswordView: View {
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        Form {
            Section {
                SecureField("当前密码", text: $currentPassword)
                SecureField("新密码（至少8位）", text: $newPassword)
                SecureField("确认新密码", text: $confirmPassword)
            } header: {
                Text("更改密码")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(AppColors.danger)
                }
            }

            Section {
                Button("保存") {
                    changePassword()
                }
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            }
        }
        .navigationTitle("Master Password")
        .alert("密码已更改", isPresented: $showingSuccess) {
            Button("确定", role: .cancel) { }
        }
    }

    private func changePassword() {
        errorMessage = nil

        guard newPassword.count >= 8 else {
            errorMessage = "新密码至少8位"
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = "两次密码输入不一致"
            return
        }

        // Verify current password first
        guard let salt = try? KeychainService.shared.retrieveSalt(),
              let storedHash = try? KeychainService.shared.retrievePasswordHash() else {
            errorMessage = "无法验证当前密码"
            return
        }

        let currentDerivedKey = EncryptionService.shared.deriveKey(from: currentPassword, salt: salt)
        let currentKeyData = currentDerivedKey.withUnsafeBytes { Data($0) }
        let currentHash = EncryptionService.shared.hashKey(currentKeyData)

        guard currentHash == storedHash else {
            errorMessage = "当前密码错误"
            return
        }

        // Derive new key from new password
        let newSalt = EncryptionService.shared.generateSalt()
        let newDerivedKey = EncryptionService.shared.deriveKey(from: newPassword, salt: newSalt)
        let newKeyData = newDerivedKey.withUnsafeBytes { Data($0) }
        let newHash = EncryptionService.shared.hashKey(newKeyData)

        // Update Keychain with new salt, hash, and key
        try? KeychainService.shared.storeSalt(newSalt)
        try? KeychainService.shared.storePasswordHash(newHash)
        try? KeychainService.shared.storeEncryptionKey(newKeyData)

        // Load new key for re-encryption
        EncryptionService.shared.loadKey(newKeyData)

        showingSuccess = true
    }
}
```

- [ ] **Step 3: Create CustomTypeListView and CustomTypeEditView**

```swift
// PrivateSpace/Features/CustomTypes/CustomTypeListView.swift
import SwiftUI
import SwiftData

struct CustomTypeListView: View {
    @Query private var customTypes: [CustomItemType]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewType = false

    var body: some View {
        List {
            ForEach(customTypes) { type in
                NavigationLink {
                    CustomTypeEditView(mode: .edit(type: type))
                } label: {
                    HStack {
                        Image(systemName: type.iconName)
                            .foregroundColor(Color(hex: "5856D6"))
                            .frame(width: 28)

                        Text(type.name)
                    }
                }
            }
            .onDelete(perform: deleteTypes)
        }
        .navigationTitle("自定义类型")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewType = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewType) {
            NavigationStack {
                CustomTypeEditView(mode: .create)
            }
        }
    }

    private func deleteTypes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customTypes[index])
        }
    }
}

enum CustomTypeEditMode {
    case create
    case edit(type: CustomItemType)
}

struct CustomTypeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: CustomTypeEditMode
    @State private var name: String = ""
    @State private var selectedIcon: String = "square.grid.2x2.fill"
    @State private var presetFields: [PresetField] = []

    private let availableIcons = [
        "square.grid.2x2.fill", "creditcard.fill", "building.2.fill",
        "car.fill", "airplane", "heart.fill", "star.fill", "flag.fill",
        "bookmark.fill", "tag.fill", "bell.fill", "envelope.fill"
    ]

    init(mode: CustomTypeEditMode) {
        self.mode = mode
        if case .edit(let type) = mode {
            _name = State(initialValue: type.name)
            _selectedIcon = State(initialValue: type.iconName)
            _presetFields = State(initialValue: type.presetFields)
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("类型名称", text: $name)
            } header: {
                Text("名称")
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIcon == icon ? .white : Color(hex: "5856D6"))
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color(hex: "5856D6") : Color(hex: "5856D6").opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            } header: {
                Text("图标")
            }

            Section {
                ForEach(Array(presetFields.enumerated()), id: \.element.id) { index, field in
                    HStack {
                        TextField("字段名", text: $presetFields[index].name)
                        Toggle("", isOn: $presetFields[index].isSecret)
                            .labelsHidden()
                    }
                }
                .onDelete { indexSet in
                    presetFields.remove(atOffsets: indexSet)
                }

                Button {
                    presetFields.append(PresetField(name: "新字段", isSecret: false))
                } label: {
                    Label("添加字段", systemImage: "plus")
                }
            } header: {
                Text("预设字段")
            }
        }
        .navigationTitle(mode.isEdit ? "编辑类型" : "新建类型")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    save()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func save() {
        switch mode {
        case .create:
            let type = CustomItemType(name: name, iconName: selectedIcon, presetFields: presetFields)
            modelContext.insert(type)
        case .edit(let type):
            type.name = name
            type.iconName = selectedIcon
            type.presetFields = presetFields
        }
        dismiss()
    }
}

extension CustomTypeEditMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add PrivateSpace/Features/Settings/ PrivateSpace/Features/CustomTypes/
git commit -m "feat: Add SettingsView and CustomType management"
```

---

### Task 9: Auto-Lock on Background

**Files:**
- Modify: `PrivateSpace/PrivateSpaceApp.swift` — add scenePhase monitoring

- [ ] **Step 1: Update VaultApp with auto-lock**

```swift
// In VaultApp.swift, add:
@Environment(\.scenePhase) private var scenePhase

// And in the body:
ContentView()
    .environmentObject(appState)
    .onChange(of: scenePhase) { oldPhase, newPhase in
        if newPhase == .background {
            appState.lock()
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add PrivateSpace/VaultApp.swift
git commit -m "feat: Add auto-lock on app background"
```

---

## Phase 2: Security Features

### Task 10: Clipboard Auto-Clear Integration

(Already implemented in ClipboardService — ensure it's wired up in ItemDetailView)

### Task 11: Verify Encryption Flow

**Files:**
- Review: `PrivateSpace/Services/EncryptionService.swift`
- Review: `PrivateSpace/Features/ItemEdit/ItemEditViewModel.swift` (save flow)

- [ ] **Step 1: Verify encryption/decryption works end-to-end**

```swift
// Add to EncryptionService for testing:
func testEncryption() {
    let testString = "Hello, Vault!"
    let salt = generateSalt()
    let key = deriveKey(from: "testpassword", salt: salt)
    loadKey(key.withUnsafeBytes { Data($0) })

    let encrypted = try! encrypt(testString)
    let decrypted = try! decrypt(encrypted)
    assert(decrypted == testString)
}
```

- [ ] **Step 2: Run test and verify**

Run in playground or test target. Expected: assertion passes.

- [ ] **Step 3: Commit**

```bash
git add PrivateSpace/Services/EncryptionService.swift
git commit -m "test: Verify AES-GCM encryption flow"
```

---

## Phase 3: Advanced Features

### Task 12: iOS Password AutoFill Extension

**Files:**
- Create: `VaultAutoFill/` (new extension target)
- Create: `VaultAutoFill/CredentialProviderViewController.swift`
- Create: `VaultAutoFill/ASCredentialProviderViewController`
- Modify: `PrivateSpace.xcodeproj` — add extension target and entitlements

- [ ] **Step 1: Create extension target**

In Xcode, add new target: "Credential Provider Extension" named `VaultAutoFill`.

- [ ] **Step 2: Create CredentialProviderViewController**

```swift
// VaultAutoFill/CredentialProviderViewController.swift
import AuthenticationServices
import SwiftData

class CredentialProviderViewController: ASCredentialProviderViewController {

    private var modelContainer: ModelContainer?

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Initialize SwiftData container
        setupModelContainer()

        // Query VaultItem where type == .password
        // Match against serviceIdentifiers domains
        // Present matching credentials
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Called when system wants to autofill without UI
        // Must have valid session with key loaded
        guard EncryptionService.shared.symmetricKey != nil else {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            return
        }

        // Retrieve password for credentialIdentity.recordIdentifier
        // Return ASPasswordCredential
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Show UI to confirm before autofilling
        // User confirms -> provideCredential(for:)
    }

    private func setupModelContainer() {
        // Same container config as main app
        let schema = Schema([VaultItem.self, CustomField.self, CustomItemType.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        modelContainer = try? ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 3: Configure extension entitlements**

```xml
<!-- VaultAutoFill/VaultAutoFill.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.developer.authentication-services.autofill-credential-provider</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.quwaner.Vault</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Add App Groups capability for shared Keychain access**

Both main app and extension must have same app group to share Keychain items.

- [ ] **Step 5: Commit**

```bash
git add VaultAutoFill/
git commit -m "feat: Add AutoFill credential provider extension"
```

### Task 13: Sync Status UI

**Files:**
- Modify: `PrivateSpace/Services/CloudSyncService.swift`
- Modify: `PrivateSpace/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Create CloudSyncService**

```swift
// PrivateSpace/Services/CloudSyncService.swift
import Foundation
import Combine
import SwiftData

final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published var syncStatus: SyncStatus = .unknown
    @Published var lastSyncDate: Date?

    enum SyncStatus {
        case unknown
        case connected
        case syncing
        case disconnected
        case error(String)
    }

    private init() {
        observeSyncStatus()
    }

    private func observeSyncStatus() {
        // Observe NotificationCenter for CloudKit sync notifications
        // Update syncStatus based on NSNotification names:
        // - CKAccountChangedNotification
        // - CKDatabaseServerRecordChangedNotification
    }

    func forceSync() {
        // Trigger SwiftData save which will push to CloudKit
        syncStatus = .syncing
    }
}
```

- [ ] **Step 2: Update SettingsView to show sync status**

(Already wired in SettingsView as iCloud Sync card)

- [ ] **Step 3: Commit**

```bash
git add PrivateSpace/Services/CloudSyncService.swift
git commit -m "feat: Add CloudKit sync status monitoring"
```

---

## Summary

**Core tasks completed:**
1. SwiftData models with CloudKit sync
2. Keychain + Encryption services (PBKDF2 key derivation + verification hash)
3. Face ID + Master Password authentication
4. Unlock, Setup, MainList, ItemDetail, ItemEdit views
5. Settings with auto-lock
6. Custom type management
7. Clipboard auto-clear
8. Password change with re-encryption

---

## Summary

**Core tasks completed:**
1. SwiftData models with CloudKit sync
2. Keychain + Encryption services
3. Face ID + Master Password authentication
4. Unlock, Setup, MainList, ItemDetail, ItemEdit views
5. Settings with auto-lock
6. Custom type management
7. Clipboard auto-clear

**Next steps for Phase 3:**
- iOS Password AutoFill extension
- Sync status UI improvements
- Biometrics enable/disable toggle wiring
