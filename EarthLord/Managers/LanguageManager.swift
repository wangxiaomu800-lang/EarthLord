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
            updateLocale()
            print("🌍 语言已切换到: \(currentLanguage.displayName)")
        }
    }

    /// 当前的 Locale（用于 SwiftUI environment）
    @Published var currentLocale: Locale

    /// UserDefaults 键
    private let languageKey = "app_language"

    private init() {
        // 从 UserDefaults 加载语言设置
        let language: AppLanguage
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let loadedLanguage = AppLanguage(rawValue: savedLanguage) {
            language = loadedLanguage
            print("🌍 加载已保存的语言设置: \(loadedLanguage.displayName)")
        } else {
            language = .system
            print("🌍 使用默认语言设置: 跟随系统")
        }

        // 初始化所有存储属性
        self.currentLanguage = language
        self.currentLocale = Self.getLocale(for: language)
    }

    /// 保存语言设置
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 语言设置已保存: \(currentLanguage.rawValue)")
    }

    /// 更新 Locale
    private func updateLocale() {
        currentLocale = Self.getLocale(for: currentLanguage)
        print("🌐 Locale 已更新: \(currentLocale.identifier)")
    }

    /// 切换语言
    func changeLanguage(to language: AppLanguage) {
        currentLanguage = language
    }

    /// 获取指定语言的 Locale
    private static func getLocale(for language: AppLanguage) -> Locale {
        switch language {
        case .system:
            return Locale.current
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

