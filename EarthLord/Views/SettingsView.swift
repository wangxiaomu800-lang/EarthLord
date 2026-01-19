import SwiftUI

struct SettingsView: View {
    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 语言管理器
    @ObservedObject var languageManager = LanguageManager.shared

    /// 环境变量 - 用于返回上一页
    @Environment(\.dismiss) var dismiss

    /// 是否显示语言选择器
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 语言设置卡片
                    languageCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // 支持与隐私卡片
                    supportLinksCard
                        .padding(.horizontal, 20)

                    // 版本信息
                    versionInfoCard
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
    }

    // MARK: - 语言设置卡片
    private var languageCard: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("settings.language")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 语言选择按钮
            Button(action: {
                showLanguagePicker = true
            }) {
                HStack {
                    Text("settings.current_language")
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    Text(languageManager.currentLanguage.displayName)
                        .foregroundColor(ApocalypseTheme.primary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 支持与隐私卡片
    private var supportLinksCard: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("settings.support_privacy")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 技术支持链接
            Link(destination: URL(string: "https://wangxiaomu800-lang.github.io/earthlord-support/")!) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 24)

                    Text("settings.technical_support")
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))
                .padding(.leading, 56)

            // 隐私政策链接
            Link(destination: URL(string: "https://wangxiaomu800-lang.github.io/earthlord-support/privacy.html")!) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 24)

                    Text("settings.privacy_policy")
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 语言选择器弹窗
    private var languagePickerSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(AppLanguage.allCases) { language in
                            languageOptionRow(language)

                            if language != AppLanguage.allCases.last {
                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.3))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .padding(20)
                }
            }
            .navigationTitle("settings.select_language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done") {
                        showLanguagePicker = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 语言选项行
    private func languageOptionRow(_ language: AppLanguage) -> some View {
        Button(action: {
            languageManager.changeLanguage(to: language)
        }) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: language == .system ? "globe" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(languageManager.currentLanguage == language ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 30)

                // 语言名称
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if language == .system {
                        Text("settings.follow_system")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 选中标记
                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }

    // MARK: - 版本信息卡片
    private var versionInfoCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.primary)

            Text("app.name")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("app.version")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("app.tagline")
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
