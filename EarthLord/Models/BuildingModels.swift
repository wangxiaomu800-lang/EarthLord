//
//  BuildingModels.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import Foundation

// MARK: - Enums

/// 建筑分类
enum BuildingCategory: String, Codable {
    case survival = "survival"      // 生存类
    case storage = "storage"        // 储存类
    case production = "production"  // 生产类
    case energy = "energy"          // 能源类
}

/// 建筑状态
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 已完工
}

/// 建筑错误类型
enum BuildingError: Error, LocalizedError {
    case notAuthenticated
    case templateNotFound
    case insufficientResources(missing: [String: Int])
    case buildingLimitReached
    case territoryNotFound
    case buildingNotFound
    case invalidLocation
    case alreadyMaxLevel
    case buildingNotActive

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .templateNotFound:
            return "建筑模板不存在"
        case .insufficientResources(let missing):
            let missingList = missing.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            return "资源不足：\(missingList)"
        case .buildingLimitReached:
            return "该建筑在此领地已达建造上限"
        case .territoryNotFound:
            return "领地不存在"
        case .buildingNotFound:
            return "建筑不存在"
        case .invalidLocation:
            return "位置无效"
        case .alreadyMaxLevel:
            return "建筑已达最高等级"
        case .buildingNotActive:
            return "建筑未完工"
        }
    }
}

// MARK: - Building Template

/// 建筑模板（从 JSON 加载）
struct BuildingTemplate: Codable, Identifiable {
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int?
    let maxLevel: Int

    var id: String { templateId }

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case name, category, tier
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }

    /// 获取升级到指定等级所需的资源
    /// 基础资源 * 等级系数（简化版本，可根据需求调整）
    func resourcesForLevel(_ level: Int) -> [String: Int] {
        return requiredResources.mapValues { $0 * level }
    }
}

// MARK: - Player Building (Application Model)

/// 玩家建筑实例（应用层模型）
struct PlayerBuilding: Identifiable {
    let id: String
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: BuildingStatus
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    let buildCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    /// 是否建造中
    var isConstructing: Bool {
        status == .constructing
    }

    /// 是否已完工
    var isActive: Bool {
        status == .active
    }

    /// 建造进度（0.0 - 1.0）
    var constructionProgress: Double {
        guard isConstructing, let completedAt = buildCompletedAt else {
            return 1.0
        }

        let totalDuration = completedAt.timeIntervalSince(buildStartedAt)
        let elapsed = Date().timeIntervalSince(buildStartedAt)

        return min(max(elapsed / totalDuration, 0.0), 1.0)
    }

    /// 剩余建造时间（秒）
    var remainingBuildTime: TimeInterval {
        guard isConstructing, let completedAt = buildCompletedAt else {
            return 0
        }

        return max(completedAt.timeIntervalSince(Date()), 0)
    }
}

// MARK: - Database DTOs

/// 数据库 DTO（查询）
struct PlayerBuildingDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let territory_id: String
    let template_id: String
    let building_name: String
    let status: String
    let level: Int
    let location_lat: Double?
    let location_lon: Double?
    let build_started_at: Date
    let build_completed_at: Date?
    let created_at: Date
    let updated_at: Date

    func toPlayerBuilding() -> PlayerBuilding {
        PlayerBuilding(
            id: id.uuidString,
            userId: user_id.uuidString,
            territoryId: territory_id,
            templateId: template_id,
            buildingName: building_name,
            status: BuildingStatus(rawValue: status) ?? .constructing,
            level: level,
            locationLat: location_lat,
            locationLon: location_lon,
            buildStartedAt: build_started_at,
            buildCompletedAt: build_completed_at,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

/// 数据库 DTO（插入）
struct PlayerBuildingInsertDTO: Encodable {
    let user_id: UUID
    let territory_id: String
    let template_id: String
    let building_name: String
    let status: String
    let level: Int
    let location_lat: Double?
    let location_lon: Double?
    let build_started_at: Date
    let build_completed_at: Date?
}

/// 数据库 DTO（更新）
struct PlayerBuildingUpdateDTO: Encodable {
    let status: String?
    let level: Int?
    let build_completed_at: Date?
    let updated_at: Date
}
