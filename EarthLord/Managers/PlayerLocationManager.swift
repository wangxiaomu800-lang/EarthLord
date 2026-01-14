//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置管理器
//  职责：上报位置、查询附近玩家数量、动态调整 POI 数量
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 玩家位置管理器
/// 负责定期上报位置、查询附近玩家数量、动态调整 POI 显示
@MainActor
class PlayerLocationManager: ObservableObject {
    // MARK: - Singleton

    static let shared = PlayerLocationManager()

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 玩家密度等级
    @Published var playerDensity: PlayerDensity = .solo

    /// 是否正在上报位置
    @Published var isReporting: Bool = false

    // MARK: - Private Properties

    private let supabase = SupabaseConfig.shared
    private var reportTimer: Timer?
    private var lastReportedLocation: CLLocation?
    private let minReportDistance: CLLocationDistance = 50.0  // 50 米

    // MARK: - Initialization

    private init() {
        print("🌍 PlayerLocationManager 初始化")
    }

    // MARK: - Public Methods

    /// 开始定期上报位置（30 秒间隔）
    func startReporting() {
        guard reportTimer == nil else {
            print("📍 位置上报已在运行")
            return
        }

        print("📍 开始位置上报（每 30 秒）")
        isReporting = true

        // 立即上报一次
        Task {
            await reportCurrentLocation()
        }

        // 启动定时器（30 秒间隔）
        reportTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.reportCurrentLocation()
            }
        }
    }

    /// 停止位置上报
    func stopReporting() {
        print("📍 停止位置上报")
        reportTimer?.invalidate()
        reportTimer = nil
        isReporting = false

        // 标记为离线
        Task {
            await markOffline()
        }
    }

    /// 手动触发位置上报（移动超过 50 米时调用）
    func reportLocationIfNeeded(currentLocation: CLLocation) async {
        // 检查是否移动超过 50 米
        if let lastLocation = lastReportedLocation {
            let distance = currentLocation.distance(from: lastLocation)
            if distance < minReportDistance {
                return  // 移动距离不足，跳过上报
            }
            print("📍 移动距离：\(Int(distance))m，触发位置上报")
        }

        await reportCurrentLocation()
    }

    /// 查询附近玩家数量
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radiusMeters: 查询半径（米），默认 1000
    /// - Returns: 附近在线玩家数量
    func queryNearbyPlayers(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 1000
    ) async throws -> Int {
        print("🔍 查询附近玩家数量...")

        // 调用 RPC 函数
        let response = try await supabase.rpc(
            "count_nearby_players",
            params: [
                "user_lat": latitude,
                "user_lng": longitude,
                "radius_meters": radiusMeters
            ]
        ).execute()

        let count = try JSONDecoder().decode(Int.self, from: response.data)

        await MainActor.run {
            nearbyPlayerCount = count
            playerDensity = PlayerDensity.from(count: count)
        }

        print("✅ 附近有 \(count) 个在线玩家 - \(playerDensity.displayName)")
        return count
    }

    /// 获取建议的 POI 显示数量
    /// - Parameter nearbyPlayerCount: 附近玩家数量
    /// - Returns: 建议的 POI 显示数量（1-20）
    func getSuggestedPOICount(nearbyPlayerCount: Int) async throws -> Int {
        print("💡 查询建议的 POI 数量...")

        let response = try await supabase.rpc(
            "suggest_poi_count",
            params: ["nearby_player_count": nearbyPlayerCount]
        ).execute()

        let count = try JSONDecoder().decode(Int.self, from: response.data)
        print("💡 建议显示 \(count) 个 POI（附近 \(nearbyPlayerCount) 个玩家）")
        return count
    }

    // MARK: - Private Methods

    /// 上报当前位置
    private func reportCurrentLocation() async {
        guard let location = LocationManager.shared.userLocation else {
            print("⚠️ 无法获取用户位置，跳过上报")
            return
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            print("⚠️ 用户未登录，跳过位置上报")
            return
        }

        let request = LocationUpdateRequest(
            playerId: userId,
            coordinate: location,
            isOnline: true
        )

        do {
            // UPSERT 操作（插入或更新）
            _ = try await supabase
                .from("player_locations")
                .upsert(request)
                .execute()

            lastReportedLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )

            print("✅ 位置上报成功: (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))")
        } catch {
            print("❌ 位置上报失败: \(error.localizedDescription)")
        }
    }

    /// 标记为离线
    private func markOffline() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            struct OfflineUpdate: Codable {
                let isOnline: Bool

                enum CodingKeys: String, CodingKey {
                    case isOnline = "is_online"
                }
            }

            _ = try await supabase
                .from("player_locations")
                .update(OfflineUpdate(isOnline: false))
                .eq("player_id", value: userId.uuidString)
                .execute()

            print("✅ 已标记为离线")
        } catch {
            print("❌ 离线标记失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 辅助结构

/// 离线标记请求
private struct OfflineUpdateRequest: Codable {
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
    }
}
