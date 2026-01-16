//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  根据行走距离生成奖励物品
//

import Foundation

/// 奖励等级
enum RewardTier: String {
    case none = "none"        // 无奖励（0-200米）
    case bronze = "bronze"    // 铜级（200-500米）
    case silver = "silver"    // 银级（500-1000米）
    case gold = "gold"        // 金级（1000-2000米）
    case diamond = "diamond"  // 钻石级（2000米以上）

    /// 中文名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "🥉 铜级"
        case .silver: return "🥈 银级"
        case .gold: return "🥇 金级"
        case .diamond: return "💎 钻石级"
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 普通物品概率
    var commonProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0.90
        case .silver: return 0.70
        case .gold: return 0.50
        case .diamond: return 0.30
        }
    }

    /// 稀有物品概率
    var rareProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0.10
        case .silver: return 0.25
        case .gold: return 0.35
        case .diamond: return 0.40
        }
    }

    /// 史诗物品概率
    var epicProbability: Double {
        switch self {
        case .none: return 0
        case .bronze: return 0.00
        case .silver: return 0.05
        case .gold: return 0.15
        case .diamond: return 0.30
        }
    }
}

/// 物品稀有度池
enum ItemRarityPool: Int {
    case common = 0  // 普通
    case rare = 1    // 稀有
    case epic = 2    // 史诗

    /// 普通物品池
    static let commonItems = [
        "item_water_bottle",
        "item_canned_food",
        "item_biscuit",
        "item_bandage",
        "item_wood",
        "item_scrap_metal",
        "item_cloth",
        "item_rope"
    ]

    /// 稀有物品池
    static let rareItems = [
        "item_medicine",
        "item_first_aid_kit",
        "item_flashlight",
        "item_toolbox",
        "item_radio"
    ]

    /// 史诗物品池（暂时使用稀有物品池，后续可扩展）
    static let epicItems = [
        "item_first_aid_kit",
        "item_toolbox",
        "item_radio"
    ]
}

/// 奖励物品
struct RewardItem {
    let itemId: String
    let quantity: Int
    let quality: Int?  // 品质（0-4）
    let metadata: [String: String]?  // 元数据（用于存储 AI 生成的名称、故事等）
}

/// 奖励生成器
struct RewardGenerator {

    // MARK: - 公开方法

    /// 根据行走距离生成奖励
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级和物品列表
    static func generateReward(distance: Double) -> (tier: RewardTier, items: [RewardItem]) {
        // 1. 确定奖励等级
        let tier = calculateTier(distance: distance)

        print("🎁 奖励等级: \(tier.displayName) (\(distance)米)")

        // 2. 如果无奖励，直接返回
        if tier == .none {
            return (tier, [])
        }

        // 3. 生成物品
        var items: [RewardItem] = []
        let targetCount = tier.itemCount
        print("🎯 目标物品数: \(targetCount)")

        for index in 0..<targetCount {
            if let item = generateRandomItem(tier: tier) {
                items.append(item)
                print("   [\(index + 1)/\(targetCount)] 生成: \(item.itemId) x\(item.quantity) (品质: \(item.quality ?? -1))")
            } else {
                print("   ❌ [\(index + 1)/\(targetCount)] 生成失败！")
            }
        }

        print("✅ 最终生成了 \(items.count)/\(targetCount) 件物品")

        return (tier, items)
    }

    // MARK: - 公开方法

    /// 根据距离计算奖励等级
    static func calculateTier(distance: Double) -> RewardTier {
        if distance < 200 {
            return .none
        } else if distance < 500 {
            return .bronze
        } else if distance < 1000 {
            return .silver
        } else if distance < 2000 {
            return .gold
        } else {
            return .diamond
        }
    }

    /// 生成随机物品
    /// 生成随机物品（POI 搜刮用）
    /// - Parameter tier: 奖励等级
    /// - Returns: 随机生成的物品，失败返回 nil
    static func generateRandomItem(tier: RewardTier) -> RewardItem? {
        // 1. 掷骰子决定稀有度
        let rarityRoll = Double.random(in: 0...1)
        let rarityPool: [String]

        if rarityRoll < tier.commonProbability {
            // 普通物品
            rarityPool = ItemRarityPool.commonItems
        } else if rarityRoll < tier.commonProbability + tier.rareProbability {
            // 稀有物品
            rarityPool = ItemRarityPool.rareItems
        } else {
            // 史诗物品
            rarityPool = ItemRarityPool.epicItems
        }

        // 2. 从物品池随机抽取
        guard let itemId = rarityPool.randomElement() else {
            return nil
        }

        // 3. 确定数量（1-3个）
        let quantity = Int.random(in: 1...3)

        // 4. 确定品质（对于有品质的物品）
        let quality = shouldHaveQuality(itemId: itemId) ? generateRandomQuality() : nil

        return RewardItem(itemId: itemId, quantity: quantity, quality: quality, metadata: nil)
    }

    /// 判断物品是否有品质
    private static func shouldHaveQuality(itemId: String) -> Bool {
        // 根据 item_definitions 表中的 has_quality 字段
        let itemsWithQuality = [
            "item_canned_food",
            "item_bandage",
            "item_medicine",
            "item_first_aid_kit",
            "item_flashlight",
            "item_rope",
            "item_toolbox",
            "item_radio"
        ]
        return itemsWithQuality.contains(itemId)
    }

    /// 生成随机品质（0=破损，1=磨损，2=正常，3=良好，4=优秀）
    private static func generateRandomQuality() -> Int {
        let roll = Double.random(in: 0...1)

        if roll < 0.10 {
            return 0  // 10% 破损
        } else if roll < 0.30 {
            return 1  // 20% 磨损
        } else if roll < 0.70 {
            return 2  // 40% 正常
        } else if roll < 0.90 {
            return 3  // 20% 良好
        } else {
            return 4  // 10% 优秀
        }
    }
}
