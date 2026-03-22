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
