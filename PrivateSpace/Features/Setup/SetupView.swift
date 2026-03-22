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
                                Image(systemName: viewModel.biometryIconName)
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
                    .disabled(viewModel.isLoading || viewModel.password.isEmpty || viewModel.confirmPassword.isEmpty)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
        }
    }
}
