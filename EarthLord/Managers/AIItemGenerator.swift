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
            // 获取访问令牌
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            // 构建请求
            let functionURL = URL(string: "https://vuqfufnrxzsmkzmhtuhw.supabase.co/functions/v1/generate-ai-item")!
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody = GenerateItemRequest(
                poi: GenerateItemRequest.POIInfo(
                    name: poi.name,
                    type: poi.type.rawValue,
                    dangerLevel: poi.dangerLevel
                ),
                itemCount: count
            )
            request.httpBody = try JSONEncoder().encode(requestBody)

            // 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("   ❌ 无效的响应")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                print("   ❌ HTTP \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   📄 响应: \(responseString)")
                }
                return nil
            }

            // 解析响应
            let result = try JSONDecoder().decode(GenerateItemResponse.self, from: data)

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
            return nil
        }
    }
}
