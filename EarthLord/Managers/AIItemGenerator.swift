//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器
//  负责调用 Edge Function 生成 AI 物品
//

import Foundation
import Supabase

@MainActor
final class AIItemGenerator {
    static let shared = AIItemGenerator()

    private let supabase = SupabaseConfig.shared

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成物品数量，默认 3
    /// - Returns: AI 生成的物品列表，失败返回 nil
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        print("\n🤖 ========== 调用 AI 生成物品 ==========")
        print("   📍 POI: \(poi.name)")
        print("   🎲 危险值: \(poi.dangerLevel)")
        print("   🔢 数量: \(count)")

        do {
            // ========== 步骤1: 获取有效的用户 Token ==========
            print("   🔐 正在获取用户认证信息...")

            // 获取当前会话
            let session = try await supabase.auth.session
            print("   📋 当前会话状态: \(session.isExpired ? "已过期" : "有效")")

            // 如果 token 已过期，尝试刷新
            var accessToken = session.accessToken
            if session.isExpired {
                print("   🔄 Token 已过期，正在刷新...")
                let refreshedSession = try await supabase.auth.refreshSession()
                accessToken = refreshedSession.accessToken
                print("   ✅ Token 刷新成功")
            }

            print("   🎫 Token 获取成功 (前20字符): \(String(accessToken.prefix(20)))...")

            // ========== 步骤2: 构建请求体 ==========
            print("   📡 正在调用 Edge Function...")

            struct FunctionPayload: Encodable {
                let poi: POIInfo
                let itemCount: Int
                let language: String  // 新增：用户语言偏好

                struct POIInfo: Encodable {
                    let name: String
                    let type: String
                    let dangerLevel: Int
                }
            }

            // 获取当前语言设置
            let currentLang = LanguageManager.shared.currentLanguage.languageCode ?? "zh-Hans"
            print("   🌍 当前语言: \(currentLang)")

            let payload = FunctionPayload(
                poi: FunctionPayload.POIInfo(
                    name: poi.name,
                    type: poi.type.rawValue,
                    dangerLevel: poi.dangerLevel
                ),
                itemCount: count,
                language: currentLang
            )

            // ========== 步骤3: 调用 Edge Function，手动传递 Authorization Header ==========
            let result: GenerateItemResponse = try await supabase.functions
                .invoke(
                    "generate-ai-item",
                    options: FunctionInvokeOptions(
                        headers: ["Authorization": "Bearer \(accessToken)"],  // 关键：手动传递 JWT Token
                        body: payload
                    )
                )

            if result.success, let items = result.items {
                print("   ✅ 成功生成 \(items.count) 个物品")
                for (index, item) in items.enumerated() {
                    print("      [\(index + 1)] \(item.name) (\(item.rarity))")
                }
                return items
            } else {
                print("   ❌ AI 生成失败: \(result.error ?? "未知错误")")
                return nil
            }

        } catch {
            print("   ❌ 调用失败: \(error.localizedDescription)")
            print("   📋 错误详情: \(error)")

            // 如果是 HTTP 错误，尝试解析响应
            if let httpError = error as? FunctionsError,
               case .httpError(let code, let data) = httpError {
                print("   🔍 HTTP \(code) 详细信息:")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   📄 响应内容: \(responseString)")
                }

                // 特别处理 401 错误（认证失败）
                if code == 401 {
                    print("   ⚠️ 401 错误：JWT Token 验证失败")
                    print("   💡 建议：请尝试重新登录")
                }
            }

            // 特别检查是否是认证错误
            if error.localizedDescription.contains("session") || error.localizedDescription.contains("auth") {
                print("   ⚠️ 这可能是认证相关的错误，请确认用户已登录")
            }

            return nil
        }
    }
}
