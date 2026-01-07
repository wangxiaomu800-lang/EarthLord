//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器
//  负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Supabase
import Combine

/// 领地上传数据结构
private struct TerritoryUploadData: Codable {
    let userId: String
    let path: [[String: Double]]
    let polygon: String
    let bboxMinLat: Double
    let bboxMaxLat: Double
    let bboxMinLon: Double
    let bboxMaxLon: Double
    let area: Double
    let pointCount: Int
    let startedAt: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case path
        case polygon
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case area
        case pointCount = "point_count"
        case startedAt = "started_at"
        case isActive = "is_active"
    }
}

/// 领地管理器
@MainActor
class TerritoryManager: ObservableObject {
    // MARK: - ObservableObject

    /// Swift 6 并发：需要 nonisolated 来符合 ObservableObject
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    // MARK: - 单例

    /// 共享实例
    static let shared = TerritoryManager()

    // MARK: - 属性

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    // MARK: - 初始化

    private init() {
        print("🏰 TerritoryManager 已初始化")
    }

    // MARK: - 数据转换

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            return [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT 多边形格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: SRID=4326;POLYGON((lon lat, lon lat, ...))
    /// - Note: WKT 格式是「经度在前，纬度在后」，多边形必须闭合（首尾相同）
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return "SRID=4326;POLYGON EMPTY"
        }

        // 构建坐标对字符串（经度在前，纬度在后）
        var coordinatePairs = coordinates.map { coordinate in
            return "\(coordinate.longitude) \(coordinate.latitude)"
        }

        // 确保多边形闭合（首尾相同）
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                // 首尾不同，添加首个坐标到末尾
                coordinatePairs.append("\(first.longitude) \(first.latitude)")
            }
        }

        let wkt = "SRID=4326;POLYGON((\(coordinatePairs.joined(separator: ", "))))"
        return wkt
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传领地

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        print("🏰 开始上传领地...")

        // 获取当前用户 ID
        guard let userId = supabase.auth.currentUser?.id else {
            print("❌ 上传失败：未登录")
            throw NSError(domain: "TerritoryManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 构建上传数据
        let territoryData = TerritoryUploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        print("📦 上传数据：")
        print("  - 用户ID: \(userId.uuidString)")
        print("  - 点数: \(coordinates.count)")
        print("  - 面积: \(String(format: "%.2f", area))m²")
        print("  - 边界框: [\(bbox.minLat), \(bbox.maxLat)] x [\(bbox.minLon), \(bbox.maxLon)]")
        print("  - WKT: \(wktPolygon.prefix(100))...")

        // 上传到数据库
        do {
            try await supabase.from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功！")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        } catch {
            print("❌ 领地上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 拉取领地

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    /// - Throws: 查询失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        print("🏰 开始加载领地...")

        do {
            let response: [Territory] = try await supabase.from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ 加载了 \(response.count) 个领地")
            return response
        } catch {
            print("❌ 加载领地失败: \(error.localizedDescription)")
            throw error
        }
    }

    /// 加载我的领地
    /// - Returns: 我的领地数组
    /// - Throws: 查询失败时抛出错误
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
        }

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()
            return true
        } catch {
            return false
        }
    }
}
