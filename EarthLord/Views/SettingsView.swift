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

                    // 版本信息
                    versionInfoCard
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("设置")
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
                Text("语言设置")
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
                    Text("当前语言")
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
            .navigationTitle("选择语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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
                        Text("跟随系统语言设置")
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
