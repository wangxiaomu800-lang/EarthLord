import SwiftUI

struct SettingsView: View {
    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 环境变量 - 用于返回上一页
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 版本信息
                    versionInfoCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 版本信息卡片
    private var versionInfoCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.primary)

            Text("地球新主")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("生存游戏 · 探索未知")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthManager())
    }
}
