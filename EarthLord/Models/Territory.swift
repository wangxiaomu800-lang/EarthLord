//
//  Territory.swift
//  EarthLord
//
//  领地数据模型
//  用于解析数据库返回的领地数据
//

import Foundation
import CoreLocation

/// 领地数据模型
struct Territory: Codable, Identifiable {
    /// 领地 ID
    let id: String

    /// 用户 ID
    let userId: String

    /// 领地名称（可选，数据库允许为空）
    let name: String?

    /// 路径坐标数组，格式：[{"lat": x, "lon": y}]
    let path: [[String: Double]]

    /// 领地面积（平方米）
    let area: Double

    /// 路径点数（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    /// 完成圈地时间（可选）
    let completedAt: String?

    /// 开始圈地时间（可选）
    let startedAt: String?

    /// 创建时间（可选）
    let createdAt: String?

    /// JSON 编码键映射
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }

    /// 将 path JSON 转换为坐标数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（如果没有名称则显示"未命名领地"）
    var displayName: String {
        return name ?? "未命名领地"
    }
}
