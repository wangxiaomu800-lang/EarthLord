import SwiftUI
import Auth

struct ProfileTabView: View {
    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 定位管理器（用于显示领地数）
    @ObservedObject var locationManager = LocationManager.shared

    /// 是否显示退出确认对话框
    @State private var showSignOutAlert = false

    /// 是否正在退出登录
    @State private var isSigningOut = false

    /// 是否显示删除账号确认对话框
    @State private var showDeleteAccountAlert = false

    /// 是否正在删除账号
    @State private var isDeletingAccount = false

    /// 删除账号确认输入文本
    @State private var deleteAccountConfirmationText = ""

    /// 删除账号错误信息
    @State private var deleteAccountError: String?

    /// 是否显示删除错误提示
    @State private var showDeleteAccountError = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 标题
                        Text("profile.title")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)

                        // 用户信息卡片
                        userInfoCard
                            .padding(.horizontal, 20)

                        // 统计数据
                        statsCard
                            .padding(.horizontal, 20)

                        // 菜单选项
                        menuOptions
                            .padding(.horizontal, 20)

                        // 退出登录按钮
                        signOutButton
                            .padding(.horizontal, 20)

                        // 删除账户按钮
                        deleteAccountButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }

                // 加载遮罩
                if isSigningOut || isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text(isSigningOut ? "profile.signing_out" : "profile.deleting_account")
                                .foregroundColor(.white)
                                .font(.headline)

                            if isDeletingAccount {
                                Text("profile.please_wait")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)
                            }
                        }
                        .padding(40)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(20)
                    }
                }
            }
            .alert("profile.confirm_sign_out", isPresented: $showSignOutAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("profile.sign_out", role: .destructive) {
                    handleSignOut()
                }
            } message: {
                Text("profile.sign_out_message")
            }
            .sheet(isPresented: $showDeleteAccountAlert) {
                DeleteAccountConfirmationView(
                    confirmationText: $deleteAccountConfirmationText,
                    isPresented: $showDeleteAccountAlert,
                    onConfirm: handleDeleteAccount
                )
            }
            .alert("profile.delete_failed", isPresented: $showDeleteAccountError) {
                Button("common.ok", role: .cancel) {
                    deleteAccountError = nil
                }
            } message: {
                Text(deleteAccountError ?? "")
            }
        }
    }

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 12) {
            // 头像
            Circle()
                .fill(ApocalypseTheme.primary)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )

            // 用户信息
            if let user = authManager.currentUser {
                // 用户名/邮箱前缀
                Text(extractUsername(from: user.email))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 邮箱
                Text(user.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // ID
                Text(String(format: NSLocalizedString("ID: %@...", comment: "User ID"), String(user.id.uuidString.prefix(8)).uppercased()))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - 统计数据卡片
    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地
            StatItem(
                icon: "flag.fill",
                value: "\(locationManager.territoryCount)",
                label: "profile.stats.territories"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 40)

            // 资源点
            StatItem(
                icon: "info.circle.fill",
                value: "0",
                label: "profile.stats.resources"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 40)

            // 探索距离
            StatItem(
                icon: "figure.walk",
                value: "0",
                label: "profile.stats.distance"
            )
        }
        .padding(.vertical, 20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 菜单选项
    private var menuOptions: some View {
        VStack(spacing: 0) {
            // 设置 - 带导航链接
            NavigationLink(destination: SettingsView().environmentObject(authManager)) {
                HStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .frame(width: 24)

                    Text("profile.menu.settings")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "bell.fill",
                iconColor: ApocalypseTheme.primary,
                title: "profile.menu.notifications",
                action: {}
            )

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "questionmark.circle.fill",
                iconColor: .blue,
                title: "profile.menu.help",
                action: {}
            )

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "info.circle.fill",
                iconColor: .green,
                title: "profile.menu.about",
                action: {}
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 退出登录按钮
    private var signOutButton: some View {
        Button(action: {
            showSignOutAlert = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)

                Text("profile.sign_out")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.4, blue: 0.4),
                        Color(red: 1.0, green: 0.5, blue: 0.5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSigningOut)
    }

    // MARK: - 处理退出登录
    private func handleSignOut() {
        isSigningOut = true

        Task {
            await authManager.signOut()

            // 延迟一下，让用户看到加载动画
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            await MainActor.run {
                isSigningOut = false
            }
        }
    }

    // MARK: - 删除账户按钮
    private var deleteAccountButton: some View {
        Button(action: {
            print("🔴 用户点击删除账户按钮")
            showDeleteAccountAlert = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.headline)

                Text("profile.delete_account")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.cardBackground)
            .foregroundColor(.red)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
            )
        }
        .disabled(isDeletingAccount)
    }

    // MARK: - 处理删除账户
    private func handleDeleteAccount() {
        print("⚠️ 用户确认删除账户，输入文本: \(deleteAccountConfirmationText)")

        guard deleteAccountConfirmationText == String(localized: "profile.delete_keyword") else {
            print("❌ 确认文本不匹配")
            return
        }

        isDeletingAccount = true
        deleteAccountConfirmationText = ""

        Task {
            do {
                print("🗑️ 开始调用删除账户方法")
                try await authManager.deleteAccount()

                print("✅ 账户删除成功，即将返回登录页")

                // 成功删除后，AuthManager 已经将 isAuthenticated 设为 false
                // RootView 会自动跳转到登录页
                await MainActor.run {
                    isDeletingAccount = false
                }

            } catch {
                print("❌ 删除账户失败: \(error.localizedDescription)")

                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountError = error.localizedDescription
                    showDeleteAccountError = true
                }
            }
        }
    }

    // MARK: - 辅助方法

    /// 从邮箱中提取用户名（邮箱 @ 前面的部分）
    private func extractUsername(from email: String?) -> String {
        guard let email = email else { return String(localized: "profile.unknown_user") }
        if let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        }
        return email
    }
}

// MARK: - 统计项组件
struct StatItem: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单选项行组件
struct MenuOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - 删除账户确认对话框
struct DeleteAccountConfirmationView: View {
    @Binding var confirmationText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 40)

                // 标题
                Text("profile.delete_account")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 警告信息
                VStack(spacing: 12) {
                    Text("profile.delete_warning")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("profile.delete_data_warning")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        DeleteInfoItem(text: "profile.delete_item.account")
                        DeleteInfoItem(text: "profile.delete_item.progress")
                        DeleteInfoItem(text: "profile.delete_item.territories")
                        DeleteInfoItem(text: "profile.delete_item.resources")
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)

                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("profile.delete_confirmation_prompt")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField(String(localized: "profile.delete_keyword"), text: $confirmationText)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    confirmationText == String(localized: "profile.delete_keyword") ? Color.red : ApocalypseTheme.textMuted.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 20)

                Spacer()

                // 按钮组
                VStack(spacing: 12) {
                    // 确认删除按钮
                    Button(action: {
                        onConfirm()
                        isPresented = false
                    }) {
                        Text("profile.confirm_delete")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                confirmationText == String(localized: "profile.delete_keyword")
                                    ? Color.red
                                    : Color.gray.opacity(0.3)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(confirmationText != String(localized: "profile.delete_keyword"))

                    // 取消按钮
                    Button(action: {
                        confirmationText = ""
                        isPresented = false
                    }) {
                        Text("common.cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ApocalypseTheme.cardBackground)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 删除信息项组件
struct DeleteInfoItem: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)

            Text(text)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
