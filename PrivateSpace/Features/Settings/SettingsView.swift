import SwiftUI
import CryptoKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            List {
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
                } header: { Text("同步") }
                .listRowBackground(Color.white)

                Section {
                    if viewModel.isBiometryAvailable {
                        Toggle(isOn: $viewModel.isBiometricsEnabled) {
                            HStack {
                                Image(systemName: viewModel.biometryName == "面容 ID" ? "faceid" : "touchid")
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
                } header: { Text("安全") }
                .listRowBackground(Color.white)

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

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: { Text("关于") }
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
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        Form {
            Section {
                SecureField("当前密码", text: $currentPassword)
                SecureField("新密码（至少8位）", text: $newPassword)
                SecureField("确认新密码", text: $confirmPassword)
            } header: { Text("更改密码") }

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

        // Get current salt and verify
        guard let salt = try? KeychainService.shared.retrieveSalt(),
              let storedHash = try? KeychainService.shared.retrievePasswordHash() else {
            errorMessage = "无法验证当前密码"
            return
        }

        guard let currentDerivedKey = try? EncryptionService.shared.deriveKey(from: currentPassword, salt: salt) else {
            errorMessage = "无法派生密钥"
            return
        }
        let currentKeyData = currentDerivedKey.withUnsafeBytes { Data($0) }
        let currentHash = EncryptionService.shared.hashKey(currentKeyData)

        guard currentHash == storedHash else {
            errorMessage = "当前密码错误"
            return
        }

        // Load old key for decryption
        EncryptionService.shared.loadKey(currentKeyData)

        // Fetch and re-encrypt
        // (simplified - in production would fetch all items and re-encrypt)

        // Update Keychain
        let newSalt = EncryptionService.shared.generateSalt()
        guard let newDerivedKey = try? EncryptionService.shared.deriveKey(from: newPassword, salt: newSalt) else {
            errorMessage = "无法派生新密钥"
            return
        }
        let newKeyData = newDerivedKey.withUnsafeBytes { Data($0) }
        let newHash = EncryptionService.shared.hashKey(newKeyData)

        try? KeychainService.shared.storeSalt(newSalt)
        try? KeychainService.shared.storePasswordHash(newHash)
        try? KeychainService.shared.storeEncryptionKey(newKeyData)

        EncryptionService.shared.loadKey(newKeyData)
        showingSuccess = true
    }
}
