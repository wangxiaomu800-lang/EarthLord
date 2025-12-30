import SwiftUI
import Auth

struct ProfileTabView: View {
    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 是否显示退出确认对话框
    @State private var showSignOutAlert = false

    /// 是否正在退出登录
    @State private var isSigningOut = false

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    Text("幸存者档案")
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
                        .padding(.bottom, 40)
                }
            }

            // 加载遮罩
            if isSigningOut {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("正在退出登录...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                    .padding(30)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(16)
                }
            }
        }
        .alert("确认退出", isPresented: $showSignOutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出登录", role: .destructive) {
                handleSignOut()
            }
        } message: {
            Text("确定要退出登录吗？")
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
                Text("ID: \(String(user.id.uuidString.prefix(8)).uppercased())...")
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
                value: "0",
                label: "领地"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 40)

            // 资源点
            StatItem(
                icon: "info.circle.fill",
                value: "0",
                label: "资源点"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 40)

            // 探索距离
            StatItem(
                icon: "figure.walk",
                value: "0",
                label: "探索距离"
            )
        }
        .padding(.vertical, 20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 菜单选项
    private var menuOptions: some View {
        VStack(spacing: 0) {
            MenuOptionRow(
                icon: "gearshape.fill",
                iconColor: .gray,
                title: "设置",
                action: {}
            )

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "bell.fill",
                iconColor: ApocalypseTheme.primary,
                title: "通知",
                action: {}
            )

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "questionmark.circle.fill",
                iconColor: .blue,
                title: "帮助",
                action: {}
            )

            Divider()
                .padding(.leading, 56)
                .background(ApocalypseTheme.textMuted.opacity(0.2))

            MenuOptionRow(
                icon: "info.circle.fill",
                iconColor: .green,
                title: "关于",
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

                Text("退出登录")
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

    // MARK: - 辅助方法

    /// 从邮箱中提取用户名（邮箱 @ 前面的部分）
    private func extractUsername(from email: String?) -> String {
        guard let email = email else { return "未知用户" }
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
    let label: String

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
    let title: String
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

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
