import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isBiometricsEnabled: Bool = true
    @Published var autoLockOption: AppState.AutoLockOption = .immediately

    var isBiometryAvailable: Bool {
        AuthenticationService.shared.isBiometryAvailable
    }

    var biometryName: String {
        AuthenticationService.shared.biometryName
    }

    func lockApp() {
        AuthenticationService.shared.lock()
    }
}
