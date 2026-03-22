import SwiftUI
import Combine

@MainActor
final class UnlockViewModel: ObservableObject {
    @Published var password: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let authService = AuthenticationService.shared
    private var authenticationTask: Task<Void, Never>?

    var isBiometryAvailable: Bool {
        authService.isBiometryAvailable
    }

    var biometryName: String {
        authService.biometryName
    }

    var biometryIconName: String {
        authService.biometryIconName
    }

    var biometryType: LABiometryType {
        authService.biometryType
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

        authenticationTask = Task {
            await authenticateWithPasswordAsync()
        }
    }

    private func authenticateWithPasswordAsync() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.authenticateWithPassword(password)
        } catch {
            errorMessage = "密码错误"
        }

        isLoading = false
    }
}