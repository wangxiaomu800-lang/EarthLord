//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理背包数据、与数据库同步
//

import Foundation
import Supabase
import Combine

/// 背包管理器
@MainActor
class InventoryManager: ObservableObject {
    // MARK: - 单例
    static let shared = InventoryManager()

    // MARK: - 发布属性

    /// 背包物品列表
    @Published var inventoryItems: [BackpackItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 加载背包物品
    func loadInventory() async throws {
        print("📦 加载背包物品")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前用户ID
            guard let userId = try? await supabase.auth.session.user.id else {
                throw InventoryError.notAuthenticated
            }

            // 查询背包物品
            let response: [InventoryItemDTO] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            // 转换为 BackpackItem
            inventoryItems = response.map { dto in
                BackpackItem(
                    id: dto.id.uuidString,
                    itemId: dto.item_id,
                    quantity: dto.quantity,
                    quality: dto.quality.map { ItemQuality(rawValue: $0) } ?? nil,
                    obtainedAt: dto.obtained_at
                )
            }

            print("✅ 加载了 \(inventoryItems.count) 件物品")
            isLoading = false
        } catch {
            print("❌ 加载背包失败: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - items: 要添加的物品列表
    func addItems(_ items: [RewardItem]) async throws {
        print("📦 添加物品到背包: \(items.count) 件")

        // 获取当前用户ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        for item in items {
            try await addSingleItem(userId: userId, item: item)
        }

        // 重新加载背包
        try await loadInventory()
    }

    /// 移除物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    func removeItem(itemId: String, quantity: Int) async throws {
        print("📦 移除物品: \(itemId) x\(quantity)")

        // 获取当前用户ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        // 查找物品
        guard let item = inventoryItems.first(where: { $0.itemId == itemId }) else {
            throw InventoryError.itemNotFound
        }

        if item.quantity <= quantity {
            // 删除物品
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("user_id", value: userId)
                .eq("item_id", value: itemId)
                .execute()
        } else {
            // 减少数量
            let newQuantity = item.quantity - quantity
            try await supabase
                .from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("user_id", value: userId)
                .eq("item_id", value: itemId)
                .execute()
        }

        // 重新加载背包
        try await loadInventory()
    }

    // MARK: - 私有方法

    /// 添加单个物品
    private func addSingleItem(userId: UUID, item: RewardItem) async throws {
        // 检查物品是否已存在（不考虑品质，后续可优化）
        let existing: [InventoryItemDTO] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_id", value: item.itemId)
            .execute()
            .value

        // 找到匹配品质的物品
        let matchingItem = existing.first { dto in
            dto.quality == item.quality
        }

        if let existingItem = matchingItem {
            // 物品已存在，增加数量
            let newQuantity = existingItem.quantity + item.quantity
            try await supabase
                .from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("id", value: existingItem.id)
                .execute()

            print("✅ 更新物品数量: \(item.itemId) -> \(newQuantity)")
        } else {
            // 物品不存在，新增
            let newItem = InventoryItemInsertDTO(
                user_id: userId,
                item_id: item.itemId,
                quantity: item.quantity,
                quality: item.quality
            )

            try await supabase
                .from("inventory_items")
                .insert(newItem)
                .execute()

            print("✅ 新增物品: \(item.itemId) x\(item.quantity)")
        }
    }
}

// MARK: - 错误类型

enum InventoryError: Error, LocalizedError {
    case notAuthenticated
    case itemNotFound
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .invalidQuantity:
            return "数量无效"
        }
    }
}

// MARK: - DTO 模型

/// 背包物品 DTO（数据库查询结果）
struct InventoryItemDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let item_id: String
    let quantity: Int
    let quality: Int?
    let obtained_at: Date
}

/// 背包物品插入 DTO
struct InventoryItemInsertDTO: Encodable {
    let user_id: UUID
    let item_id: String
    let quantity: Int
    let quality: Int?
}
