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

    var biometryIconName: String {
        authService.biometryIconName
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
            isLoading = false
        } catch {
            errorMessage = "设置失败，请重试"
            isLoading = false
        }
    }
}
