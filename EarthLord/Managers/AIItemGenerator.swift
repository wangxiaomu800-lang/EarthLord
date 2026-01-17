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
            print("   📡 使用 Supabase SDK 调用 Edge Function...")

            // 构建请求体
            struct FunctionPayload: Encodable {
                let poi: POIInfo
                let itemCount: Int

                struct POIInfo: Encodable {
                    let name: String
                    let type: String
                    let dangerLevel: Int
                }
            }

            let payload = FunctionPayload(
                poi: FunctionPayload.POIInfo(
                    name: poi.name,
                    type: poi.type.rawValue,
                    dangerLevel: poi.dangerLevel
                ),
                itemCount: count
            )

            // 使用 Supabase SDK 的 functions API
            let result: GenerateItemResponse = try await supabase.functions
                .invoke("generate-ai-item", options: FunctionInvokeOptions(body: payload))

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
            }

            // 特别检查是否是认证错误
            if error.localizedDescription.contains("session") || error.localizedDescription.contains("auth") {
                print("   ⚠️  这可能是认证相关的错误，请确认用户已登录")
            }

            return nil
        }
    }
}
