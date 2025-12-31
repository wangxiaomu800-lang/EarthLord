//
//  LanguageManager.swift
//  EarthLord
//
//  管理应用内语言切换
//

import SwiftUI
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case chinese = "zh-Hans"    // 简体中文
    case english = "en"         // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 获取实际的语言代码
    var languageCode: String? {
        switch self {
        case .system:
            return Locale.current.language.languageCode?.identifier
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器
@MainActor
class LanguageManager: ObservableObject {
    /// 单例
    static let shared = LanguageManager()

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            print("🌍 语言已切换到: \(currentLanguage.displayName)")
        }
    }

    /// UserDefaults 键
    private let languageKey = "app_language"

    private init() {
        // 从 UserDefaults 加载语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("🌍 加载已保存的语言设置: \(language.displayName)")
        } else {
            self.currentLanguage = .system
            print("🌍 使用默认语言设置: 跟随系统")
        }
    }

    /// 保存语言设置
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 切换语言
    func changeLanguage(to language: AppLanguage) {
        currentLanguage = language
    }

    /// 获取本地化字符串
    func localizedString(_ key: String) -> String {
        guard let languageCode = currentLanguage.languageCode else {
            return NSLocalizedString(key, comment: "")
        }

        // 如果是跟随系统，使用系统默认的本地化
        if currentLanguage == .system {
            return NSLocalizedString(key, comment: "")
        }

        // 获取指定语言的 bundle
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            print("⚠️ 未找到语言包: \(languageCode)，使用默认语言")
            return NSLocalizedString(key, comment: "")
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

/// String 扩展 - 支持自定义语言切换
extension String {
    /// 获取本地化字符串
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    /// 获取本地化字符串（带参数）
    func localized(_ arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}
