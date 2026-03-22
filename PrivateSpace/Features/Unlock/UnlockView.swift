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