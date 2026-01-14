//
//  PlayerLocation.swift
//  EarthLord
//
//  玩家位置数据模型
//  用于附近玩家检测和位置上报
//

import Foundation
import CoreLocation

// MARK: - 玩家位置记录（数据库模型）

/// 玩家位置记录
/// 对应数据库表 player_locations
struct PlayerLocation: Codable, Identifiable {
    let playerId: UUID
    let latitude: Double
    let longitude: Double
    let lastUpdateTime: Date
    let isOnline: Bool

    var id: UUID { playerId }

    /// 转换为 CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case latitude
        case longitude
        case lastUpdateTime = "last_update_time"
        case isOnline = "is_online"
    }
}

// MARK: - 位置上报请求（UPSERT 模型）

/// 位置上报请求
/// 用于插入或更新玩家位置
struct LocationUpdateRequest: Codable {
    let playerId: UUID
    let latitude: Double
    let longitude: Double
    let lastUpdateTime: Date
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case latitude
        case longitude
        case lastUpdateTime = "last_update_time"
        case isOnline = "is_online"
    }

    /// 从 CLLocationCoordinate2D 创建
    init(playerId: UUID, coordinate: CLLocationCoordinate2D, isOnline: Bool = true) {
        self.playerId = playerId
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.lastUpdateTime = Date()
        self.isOnline = isOnline
    }
}

// MARK: - 附近玩家密度等级

/// 附近玩家密度等级
enum PlayerDensity: String {
    case solo       // 独行者（0人）
    case low        // 低密度（1-5人）
    case medium     // 中密度（6-20人）
    case high       // 高密度（20+人）

    /// 显示名称
    var displayName: String {
        switch self {
        case .solo: return "独行者"
        case .low: return "低密度区域"
        case .medium: return "中密度区域"
        case .high: return "高密度区域"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .solo: return "person.fill"
        case .low: return "person.2.fill"
        case .medium: return "person.3.fill"
        case .high: return "person.3.sequence.fill"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .solo: return "附近没有其他幸存者"
        case .low: return "附近有少量幸存者"
        case .medium: return "附近有不少幸存者"
        case .high: return "这里聚集了大量幸存者"
        }
    }

    /// 从玩家数量创建
    static func from(count: Int) -> PlayerDensity {
        switch count {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}
