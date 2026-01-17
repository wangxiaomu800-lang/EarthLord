//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  包含 POI、背包物品、物品定义、探索结果等模拟数据
//

import Foundation
import CoreLocation

// MARK: - POI 相关模型

/// POI 状态枚举
enum POIStatus {
    case undiscovered   // 未发现（地图上不显示或显示为问号）
    case discovered     // 已发现，有物资可搜刮
    case looted         // 已发现，已被搜空
}

/// POI 类型枚举
enum POIType: String {
    case supermarket = "supermarket"    // 超市
    case hospital = "hospital"          // 医院
    case gasStation = "gas_station"     // 加油站
    case pharmacy = "pharmacy"          // 药店
    case factory = "factory"            // 工厂

    /// 显示名称（支持多语言）
    var displayName: String {
        switch self {
        case .supermarket: return NSLocalizedString("废弃超市", comment: "Abandoned Supermarket")
        case .hospital: return NSLocalizedString("医院废墟", comment: "Hospital Ruins")
        case .gasStation: return NSLocalizedString("加油站", comment: "Gas Station")
        case .pharmacy: return NSLocalizedString("药店废墟", comment: "Pharmacy Ruins")
        case .factory: return NSLocalizedString("工厂废墟", comment: "Factory Ruins")
        }
    }

    /// 图标名称（SF Symbols）
    var iconName: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.case.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        }
    }
}

/// 兴趣点（POI）模型
struct POI: Identifiable {
    let id: String
    let type: POIType
    let name: String
    let coordinate: CLLocationCoordinate2D
    let status: POIStatus
    let lootItems: [LootItem]?  // 可搜刮的物品（仅当 status == .discovered 时有效）
    let description: String?
    let dangerLevel: Int  // 危险等级 1-5（影响物品稀有度分布）

    /// 是否可以搜刮
    var canLoot: Bool {
        return status == .discovered && lootItems != nil && !lootItems!.isEmpty
    }
}

/// 可搜刮物品（POI 中的物品）
struct LootItem: Identifiable {
    let id: String
    let itemId: String      // 关联到 ItemDefinition
    let quantity: Int       // 数量
    let probability: Double // 搜刮成功概率（0-1）
}

// MARK: - 背包物品相关模型

/// 物品分类枚举
enum ItemCategory: String, CaseIterable {
    case water = "water"        // 水类
    case food = "food"          // 食物
    case medical = "medical"    // 医疗
    case material = "material"  // 材料
    case tool = "tool"          // 工具

    /// 中文名称
    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        }
    }
}

/// 物品稀有度枚举
enum ItemRarity: Int, CaseIterable {
    case common = 0     // 普通（白色）
    case uncommon = 1   // 非凡（绿色）
    case rare = 2       // 稀有（蓝色）
    case epic = 3       // 史诗（紫色）
    case legendary = 4  // 传说（橙色）

    /// 中文名称
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "非凡"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    /// 颜色名称（用于 UI 显示）
    var colorName: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

/// 物品品质枚举（部分物品有品质区分）
enum ItemQuality: Int, CaseIterable {
    case broken = 0     // 破损（50% 效果）
    case worn = 1       // 磨损（75% 效果）
    case normal = 2     // 正常（100% 效果）
    case good = 3       // 良好（110% 效果）
    case excellent = 4  // 优秀（125% 效果）

    /// 中文名称
    var displayName: String {
        switch self {
        case .broken: return "破损"
        case .worn: return "磨损"
        case .normal: return "正常"
        case .good: return "良好"
        case .excellent: return "优秀"
        }
    }

    /// 效果倍率
    var effectMultiplier: Double {
        switch self {
        case .broken: return 0.5
        case .worn: return 0.75
        case .normal: return 1.0
        case .good: return 1.1
        case .excellent: return 1.25
        }
    }
}

/// 物品定义（物品模板/配置表）
struct ItemDefinition: Identifiable {
    let id: String              // 物品唯一标识符
    let name: String            // 中文名称
    let category: ItemCategory  // 分类
    let weight: Double          // 单个重量（千克）
    let volume: Double          // 单个体积（升）
    let rarity: ItemRarity      // 稀有度
    let hasQuality: Bool        // 是否有品质区分
    let description: String     // 物品描述
    let maxStack: Int           // 最大堆叠数量
}

/// 背包物品（玩家持有的物品实例）
struct BackpackItem: Identifiable {
    let id: String
    let itemId: String          // 关联到 ItemDefinition
    let quantity: Int           // 数量
    let quality: ItemQuality?   // 品质（可选，部分物品没有品质）
    let obtainedAt: Date        // 获得时间

    /// 计算总重量（需要传入物品定义）
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }

    /// 计算总体积（需要传入物品定义）
    func totalVolume(definition: ItemDefinition) -> Double {
        return definition.volume * Double(quantity)
    }
}

// MARK: - 探索结果相关模型

/// 探索统计数据
struct ExplorationStats {
    let walkingDistance: Double     // 本次行走距离（米）
    let totalDistance: Double       // 累计行走距离（米）
    let distanceRank: Int           // 距离排名

    let duration: TimeInterval      // 探索时长（秒）
    let obtainedItems: [ObtainedItem] // 获得的物品列表
}

/// 获得的物品
struct ObtainedItem: Identifiable {
    let id: String
    let itemId: String      // 关联到 ItemDefinition
    let quantity: Int       // 数量
    let quality: ItemQuality? // 品质
}

// MARK: - Mock 数据

/// 探索模块假数据
struct MockExplorationData {

    // MARK: - 物品定义表

    /// 所有物品的定义（配置表）
    /// 用途：作为物品的模板，定义每种物品的基础属性
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "一瓶未开封的矿泉水，可以补充水分。",
            maxStack: 20
        ),

        // 食物类
        ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            hasQuality: true,  // 罐头有品质（过期程度）
            description: "密封保存的罐头食品，保质期较长。",
            maxStack: 15
        ),

        // 医疗类
        ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .common,
            hasQuality: true,  // 绷带有品质（干净程度）
            description: "用于包扎伤口的医用绷带。",
            maxStack: 30
        ),
        ItemDefinition(
            id: "item_medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: true,  // 药品有品质（有效期）
            description: "常见的止痛药和消炎药。",
            maxStack: 20
        ),

        // 材料类
        ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            hasQuality: false,  // 木材没有品质
            description: "可用于建造和生火的木材。",
            maxStack: 50
        ),
        ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 1.0,
            rarity: .common,
            hasQuality: false,  // 废金属没有品质
            description: "可回收利用的金属废料。",
            maxStack: 50
        ),

        // 工具类
        ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            hasQuality: true,  // 手电筒有品质（电池/灯泡状态）
            description: "便携式手电筒，夜间探索必备。",
            maxStack: 1
        ),
        ItemDefinition(
            id: "item_rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            hasQuality: true,  // 绳子有品质（磨损程度）
            description: "结实的尼龙绳，用途广泛。",
            maxStack: 5
        ),
    ]

    /// 根据 ID 查找物品定义
    static func findItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    // MARK: - POI 列表

    /// 模拟的 POI 列表（5个不同状态的兴趣点）
    /// 用途：在地图上显示可探索的地点
    static let poiList: [POI] = [
        // 1. 废弃超市：已发现，有物资
        POI(
            id: "poi_supermarket_001",
            type: .supermarket,
            name: "废弃超市",
            coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            status: .discovered,
            lootItems: [
                LootItem(id: "loot_001", itemId: "item_water_bottle", quantity: 5, probability: 0.8),
                LootItem(id: "loot_002", itemId: "item_canned_food", quantity: 3, probability: 0.6),
            ],
            description: "一家废弃的小型超市，货架上还残留着一些物资。",
            dangerLevel: 3
        ),

        // 2. 医院废墟：已发现，已被搜空
        POI(
            id: "poi_hospital_001",
            type: .hospital,
            name: "医院废墟",
            coordinate: CLLocationCoordinate2D(latitude: 39.9142, longitude: 116.4174),
            status: .looted,
            lootItems: nil,  // 已被搜空，没有物品
            description: "一座废弃的医院，已经被其他幸存者搜刮过了。",
            dangerLevel: 4
        ),

        // 3. 加油站：未发现
        POI(
            id: "poi_gas_station_001",
            type: .gasStation,
            name: "加油站",
            coordinate: CLLocationCoordinate2D(latitude: 39.8942, longitude: 116.3974),
            status: .undiscovered,
            lootItems: [
                LootItem(id: "loot_003", itemId: "item_rope", quantity: 1, probability: 0.5),
                LootItem(id: "loot_004", itemId: "item_flashlight", quantity: 1, probability: 0.3),
            ],
            description: nil,  // 未发现时不显示描述
            dangerLevel: 2
        ),

        // 4. 药店废墟：已发现，有物资
        POI(
            id: "poi_pharmacy_001",
            type: .pharmacy,
            name: "药店废墟",
            coordinate: CLLocationCoordinate2D(latitude: 39.9092, longitude: 116.4024),
            status: .discovered,
            lootItems: [
                LootItem(id: "loot_005", itemId: "item_bandage", quantity: 8, probability: 0.9),
                LootItem(id: "loot_006", itemId: "item_medicine", quantity: 4, probability: 0.5),
            ],
            description: "一家小型药店的废墟，柜台后面可能还有药品。",
            dangerLevel: 3
        ),

        // 5. 工厂废墟：未发现
        POI(
            id: "poi_factory_001",
            type: .factory,
            name: "工厂废墟",
            coordinate: CLLocationCoordinate2D(latitude: 39.8992, longitude: 116.4124),
            status: .undiscovered,
            lootItems: [
                LootItem(id: "loot_007", itemId: "item_scrap_metal", quantity: 10, probability: 0.8),
                LootItem(id: "loot_008", itemId: "item_wood", quantity: 8, probability: 0.7),
            ],
            description: nil,  // 未发现时不显示描述
            dangerLevel: 2
        ),
    ]

    // MARK: - 背包物品

    /// 模拟的背包物品列表（玩家当前持有的物品）
    /// 用途：显示在背包界面，管理玩家物品
    static let backpackItems: [BackpackItem] = [
        // 矿泉水 x8（没有品质）
        BackpackItem(
            id: "bp_001",
            itemId: "item_water_bottle",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600)  // 1小时前获得
        ),

        // 罐头食品 x5（正常品质）
        BackpackItem(
            id: "bp_002",
            itemId: "item_canned_food",
            quantity: 5,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-7200)  // 2小时前获得
        ),

        // 绷带 x12（良好品质）
        BackpackItem(
            id: "bp_003",
            itemId: "item_bandage",
            quantity: 12,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-1800)  // 30分钟前获得
        ),

        // 药品 x3（磨损品质）
        BackpackItem(
            id: "bp_004",
            itemId: "item_medicine",
            quantity: 3,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-10800)  // 3小时前获得
        ),

        // 木材 x15（没有品质）
        BackpackItem(
            id: "bp_005",
            itemId: "item_wood",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-5400)  // 1.5小时前获得
        ),

        // 废金属 x8（没有品质）
        BackpackItem(
            id: "bp_006",
            itemId: "item_scrap_metal",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-900)  // 15分钟前获得
        ),

        // 手电筒 x1（优秀品质）
        BackpackItem(
            id: "bp_007",
            itemId: "item_flashlight",
            quantity: 1,
            quality: .excellent,
            obtainedAt: Date().addingTimeInterval(-14400)  // 4小时前获得
        ),

        // 绳子 x2（破损品质）
        BackpackItem(
            id: "bp_008",
            itemId: "item_rope",
            quantity: 2,
            quality: .broken,
            obtainedAt: Date().addingTimeInterval(-21600)  // 6小时前获得
        ),
    ]

    // MARK: - 探索结果

    /// 模拟的探索结果数据
    /// 用途：探索结束后显示本次探索的统计信息
    static let explorationResult: ExplorationStats = ExplorationStats(
        // 行走距离统计
        walkingDistance: 2500,      // 本次行走 2500 米
        totalDistance: 15000,       // 累计行走 15000 米
        distanceRank: 42,           // 距离排名第 42 名

        // 探索时长
        duration: 1800,             // 30 分钟（1800 秒）

        // 获得的物品
        obtainedItems: [
            ObtainedItem(id: "obtain_001", itemId: "item_wood", quantity: 5, quality: nil),
            ObtainedItem(id: "obtain_002", itemId: "item_water_bottle", quantity: 3, quality: nil),
            ObtainedItem(id: "obtain_003", itemId: "item_canned_food", quantity: 2, quality: .normal),
        ]
    )

    // MARK: - 辅助方法

    /// 计算背包总重量（千克）
    static func calculateTotalWeight() -> Double {
        var totalWeight: Double = 0
        for item in backpackItems {
            if let definition = findItemDefinition(by: item.itemId) {
                totalWeight += item.totalWeight(definition: definition)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积（升）
    static func calculateTotalVolume() -> Double {
        var totalVolume: Double = 0
        for item in backpackItems {
            if let definition = findItemDefinition(by: item.itemId) {
                totalVolume += item.totalVolume(definition: definition)
            }
        }
        return totalVolume
    }

    /// 格式化距离显示
    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 公里", meters / 1000)
        } else {
            return String(format: "%.0f 米", meters)
        }
    }

    /// 格式化时长显示
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours) 小时 \(remainingMinutes) 分钟"
        } else {
            return "\(minutes) 分钟"
        }
    }
}
