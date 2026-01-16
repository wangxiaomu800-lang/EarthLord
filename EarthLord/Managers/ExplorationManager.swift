//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索状态、GPS追踪、距离计算、时长计时
//

import Foundation
import CoreLocation
import Combine

/// 探索管理器
@MainActor
class ExplorationManager: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = ExplorationManager()

    // MARK: - 发布属性

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 探索轨迹点
    @Published var explorationPath: [CLLocationCoordinate2D] = []

    /// 当前速度（米/秒）
    @Published var currentSpeed: Double = 0

    /// 速度警告消息
    @Published var speedWarning: String?

    /// 是否探索失败
    @Published var explorationFailed: Bool = false

    /// 探索失败原因
    @Published var failureReason: String?

    /// 物品发现通知
    @Published var itemDiscoveryNotification: String?

    /// POI 列表
    @Published var nearbyPOIs: [POI] = []

    /// 是否显示 POI 搜刮弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的 POI
    @Published var currentPOI: POI?

    /// 是否正在加载 POI
    @Published var isLoadingPOIs: Bool = false

    // MARK: - 私有属性

    /// 位置管理器
    private let locationManager = CLLocationManager()

    /// 上一个有效位置点
    private var lastValidLocation: CLLocation?

    /// 探索开始时间
    private var startTime: Date?

    /// 探索开始位置
    private var startLocation: CLLocationCoordinate2D?

    /// 计时器
    private var durationTimer: Timer?

    /// 上次位置更新时间
    private var lastLocationUpdateTime: Date?

    /// 速度警告定时器
    private var speedWarningTimer: Timer?

    /// 速度警告开始时间
    private var speedWarningStartTime: Date?

    /// 上次达到的奖励等级（用于检测等级提升）
    private var lastRewardTier: RewardTier = .none

    /// 已搜刮的 POI ID 集合（internal 供 MapViewRepresentable 访问）
    var scavengedPOIIds: Set<String> = []

    /// 地理围栏通知订阅
    private var geofenceCancellable: AnyCancellable?

    // MARK: - 常量

    /// GPS 精度阈值（米）- 精度差于此值的点将被忽略
    private let accuracyThreshold: Double = 50.0

    /// 单次距离跳变阈值（米）- 与上一点距离超过此值的点将被忽略
    private let distanceJumpThreshold: Double = 100.0

    /// 最小时间间隔（秒）- 距离上次更新小于此时间的点将被忽略
    private let minimumTimeInterval: TimeInterval = 1.0

    /// 速度限制（米/秒）- 30km/h = 8.33m/s
    private let speedLimit: Double = 8.33

    /// 速度警告时长（秒）- 超速10秒后停止探索
    private let speedWarningDuration: TimeInterval = 10.0

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // 移动5米更新一次（更频繁的更新以获得更准确的轨迹）
        locationManager.allowsBackgroundLocationUpdates = false

        // 订阅地理围栏通知
        geofenceCancellable = NotificationCenter.default
            .publisher(for: .didEnterPOIRegion)
            .sink { [weak self] notification in
                if let identifier = notification.object as? String {
                    Task { @MainActor in
                        self?.handlePOIEntry(identifier: identifier)
                    }
                }
            }
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        print("🔍 ========== 开始探索 ==========")

        // 重置状态
        isExploring = true
        currentDistance = 0
        currentDuration = 0
        currentSpeed = 0
        explorationPath = []
        lastValidLocation = nil
        startTime = Date()
        lastLocationUpdateTime = nil
        speedWarning = nil
        speedWarningTimer = nil
        speedWarningStartTime = nil
        explorationFailed = false
        failureReason = nil
        lastRewardTier = .none
        itemDiscoveryNotification = nil

        // 记录开始位置
        if let location = LocationManager.shared.userLocation {
            startLocation = location
            explorationPath.append(location)
            print("📍 探索起点: 纬度=\(location.latitude), 经度=\(location.longitude)")
        } else {
            print("⚠️ 警告: 未获取到起始位置")
        }

        // 开始GPS追踪
        locationManager.startUpdatingLocation()
        print("🛰️ GPS定位已启动")

        // 启动计时器（每秒更新一次时长）
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let startTime = self.startTime {
                    self.currentDuration = Date().timeIntervalSince(startTime)
                }
            }
        }

        print("✅ 探索已开始，等待GPS位置更新...")

        // 开始位置上报
        PlayerLocationManager.shared.startReporting()

        // 搜索附近 POI（基于玩家密度）
        Task {
            await searchAndAddPOIsWithDensity()
        }
    }

    /// 停止探索
    /// - Returns: 探索结果数据（距离、时长、起始位置等）
    func stopExploration() -> (distance: Double, duration: TimeInterval, startLocation: CLLocationCoordinate2D?, endLocation: CLLocationCoordinate2D?) {
        print("🛑 ========== 停止探索 ==========")

        // 停止GPS追踪
        locationManager.stopUpdatingLocation()
        print("🛰️ GPS定位已停止")

        // 停止计时器
        durationTimer?.invalidate()
        durationTimer = nil

        // 停止速度警告定时器
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil
        speedWarningStartTime = nil

        // 计算最终时长
        if let startTime = startTime {
            currentDuration = Date().timeIntervalSince(startTime)
        }

        // 获取结束位置
        let endLocation = explorationPath.last

        // 保存结果
        let finalDistance = currentDistance
        let finalDuration = currentDuration
        let finalStartLocation = startLocation
        let finalEndLocation = endLocation

        // 重置状态
        isExploring = false

        // 停止位置上报
        PlayerLocationManager.shared.stopReporting()

        // 清除 POI 和地理围栏
        clearPOIs()

        print("📊 ========== 探索统计 ==========")
        print("   📏 总距离: \(String(format: "%.2f", finalDistance)) 米")
        print("   ⏱️ 总时长: \(Int(finalDuration)) 秒 (\(Int(finalDuration/60))分\(Int(finalDuration)%60)秒)")
        print("   📍 轨迹点数: \(explorationPath.count) 个")
        print("   📈 平均速度: \(String(format: "%.2f", finalDistance/finalDuration)) 米/秒")
        print("================================")

        return (finalDistance, finalDuration, finalStartLocation, finalEndLocation)
    }

    // MARK: - POI 管理方法

    /// 搜索并添加附近的 POI（基于玩家密度）
    func searchAndAddPOIsWithDensity() async {
        print("\n🔍 ========== 开始搜索附近 POI（基于玩家密度）==========")
        isLoadingPOIs = true

        guard let userLocation = LocationManager.shared.userLocation else {
            print("❌ 无法获取用户位置")
            isLoadingPOIs = false
            return
        }

        do {
            // 1. 查询附近玩家数量
            print("   📡 查询附近玩家数量...")
            let nearbyCount = try await PlayerLocationManager.shared.queryNearbyPlayers(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude,
                radiusMeters: 1000
            )

            // 2. 获取建议的 POI 数量
            print("   💡 获取建议的 POI 数量...")
            let suggestedCount = try await PlayerLocationManager.shared.getSuggestedPOICount(
                nearbyPlayerCount: nearbyCount
            )

            // 3. 搜索 POI（传入限制数量）
            print("   🔎 搜索附近真实地点...")
            let pois = try await POISearchManager.searchNearbyPOIs(
                center: userLocation,
                radiusInMeters: 1000,
                maxResults: suggestedCount
            )

            await MainActor.run {
                nearbyPOIs = pois
                setupGeofences(for: pois)
                isLoadingPOIs = false
                print("✅ 找到 \(pois.count) 个 POI（附近 \(nearbyCount) 个玩家，密度：\(PlayerLocationManager.shared.playerDensity.displayName)）")
            }
        } catch {
            print("❌ POI 搜索失败: \(error.localizedDescription)")
            // 即使失败也尝试使用默认配置搜索
            print("   🔄 尝试使用默认配置搜索...")
            await searchAndAddPOIs()
        }

        print("🔍 ========== POI 搜索完成 ==========\n")
    }

    /// 搜索并添加附近的 POI（不考虑密度，默认配置）
    private func searchAndAddPOIs() async {
        print("🔍 开始搜索附近 POI（默认配置）...")
        isLoadingPOIs = true

        guard let userLocation = LocationManager.shared.userLocation else {
            print("❌ 无法获取用户位置")
            isLoadingPOIs = false
            return
        }

        do {
            let pois = try await POISearchManager.searchNearbyPOIs(center: userLocation)
            await MainActor.run {
                nearbyPOIs = pois
                setupGeofences(for: pois)
                isLoadingPOIs = false
                print("✅ 找到 \(pois.count) 个 POI")
            }
        } catch {
            print("❌ POI 搜索失败: \(error)")
            isLoadingPOIs = false
        }
    }

    /// 设置地理围栏
    private func setupGeofences(for pois: [POI]) {
        print("\n📍 ========== 设置地理围栏 ==========")

        // 清除旧围栏（只清除 POI 相关的）
        for region in locationManager.monitoredRegions {
            if region.identifier.hasPrefix("poi_") {
                locationManager.stopMonitoring(for: region)
                print("   🗑️ 清除旧围栏: \(region.identifier)")
            }
        }

        // 创建新围栏（最多 20 个）
        let limit = min(pois.count, 20)
        print("   📊 将创建 \(limit) 个地理围栏")

        for i in 0..<limit {
            let poi = pois[i]
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: 1000.0,  // 1000 米半径（1公里）
                identifier: "poi_\(poi.id)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoring(for: region)
            print("   [\(i + 1)/\(limit)] 📍 \(poi.name) - 半径 1000m")
        }

        print("📍 ========== 地理围栏设置完成 ==========\n")

        // ⚠️ iOS 地理围栏限制：如果用户已经在围栏内，不会触发进入事件
        // 解决方案：主动检查用户是否已经在某个 POI 范围内
        checkUserLocationInPOIs(pois: pois)
    }

    /// 检查用户是否已经在某个 POI 范围内
    private func checkUserLocationInPOIs(pois: [POI]) {
        guard let userLocation = LocationManager.shared.userLocation else {
            return
        }

        print("\n🔍 检查用户是否已在 POI 范围内...")

        for poi in pois {
            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userCLLocation.distance(from: poiLocation)

            // 如果在 1000 米范围内，且未搜刮
            if distance <= 1000.0 && !scavengedPOIIds.contains(poi.id) {
                print("   ✅ 用户已在 \(poi.name) 范围内（\(Int(distance))米）")
                // 主动触发 POI 进入事件
                handlePOIEntry(identifier: "poi_\(poi.id)")
                // 只触发最近的一个
                break
            }
        }
    }

    /// 处理进入 POI 范围
    func handlePOIEntry(identifier: String) {
        print("\n🎯 ========== 进入 POI 范围 ==========")
        print("   🆔 Identifier: \(identifier)")

        // 提取 POI ID
        guard identifier.hasPrefix("poi_") else {
            print("   ❌ 不是 POI 围栏")
            return
        }

        let poiId = String(identifier.dropFirst(4))  // 移除 "poi_" 前缀
        print("   🔑 POI ID: \(poiId)")

        // 查找 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == poiId }) else {
            print("   ❌ 未找到对应的 POI")
            return
        }

        print("   📍 POI: \(poi.name)")

        // 检查是否已搜刮
        if scavengedPOIIds.contains(poi.id) {
            print("   ℹ️ POI 已搜刮，跳过")
            return
        }

        // 显示弹窗
        currentPOI = poi
        showPOIPopup = true
        print("   ✅ 显示搜刮弹窗")
        print("🎯 ====================================\n")
    }

    /// 搜刮 POI（异步版本，集成 AI 生成）
    func scavengePOI(_ poi: POI) async -> [RewardItem] {
        print("\n🎁 ========== 搜刮 POI ==========")
        print("   📍 地点: \(poi.name)")
        print("   🎲 危险值: \(poi.dangerLevel)")

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)
        print("   ✅ 标记为已搜刮")

        // 1. 尝试 AI 生成
        if let aiItems = await AIItemGenerator.shared.generateItems(for: poi, count: 3) {
            // AI 生成成功，转换为 RewardItem
            let items = convertAIItemsToRewardItems(aiItems)
            print("   ✅ AI 生成成功: \(items.count) 件物品")
            print("🎁 ========== 搜刮完成 ==========\n")
            return items
        }

        // 2. AI 失败，使用降级方案（预设物品）
        print("   ⚠️ AI 生成失败，使用预设物品")

        // 生成 1-3 件物品（使用铜级奖励池）
        let itemCount = Int.random(in: 1...3)
        var items: [RewardItem] = []

        print("   🎯 目标物品数: \(itemCount)")

        for i in 0..<itemCount {
            if let item = RewardGenerator.generateRandomItem(tier: .bronze) {
                items.append(item)
                print("      [\(i + 1)/\(itemCount)] \(item.itemId) x\(item.quantity)")
            } else {
                print("      [\(i + 1)/\(itemCount)] 生成失败")
            }
        }

        print("   ✅ 降级方案: 生成了 \(items.count) 件物品")
        print("🎁 ========== 搜刮完成 ==========\n")

        return items
    }

    /// 将 AI 生成的物品转换为 RewardItem
    private func convertAIItemsToRewardItems(_ aiItems: [AIGeneratedItem]) -> [RewardItem] {
        return aiItems.map { aiItem in
            // 根据 AI 稀有度和分类选择对应的物品 ID
            let itemId = selectItemIdByRarity(aiItem.rarity, category: aiItem.category)

            return RewardItem(
                itemId: itemId,
                quantity: 1,
                quality: nil,  // AI 物品不使用品质系统
                metadata: [
                    "ai_generated": "true",
                    "ai_name": aiItem.name,
                    "ai_story": aiItem.story,
                    "ai_rarity": aiItem.rarity
                ]
            )
        }
    }

    /// 根据稀有度和分类选择对应的游戏内物品 ID
    private func selectItemIdByRarity(_ rarity: String, category: String) -> String {
        // 根据分类和稀有度映射到现有物品系统
        switch (category, rarity.lowercased()) {
        case ("医疗", "legendary"), ("医疗", "epic"):
            return "medical_kit_advanced"
        case ("医疗", _):
            return "medical_bandage"
        case ("食物", "legendary"), ("食物", "epic"):
            return "food_canned_premium"
        case ("食物", _):
            return "food_water"
        case ("工具", _):
            return "tool_flashlight"
        case ("武器", _):
            return "weapon_baton"
        default:
            return "material_scrap"
        }
    }

    /// 清除所有 POI 和地理围栏
    func clearPOIs() {
        print("\n🧹 ========== 清除 POI 和地理围栏 ==========")

        // 停止所有 POI 围栏监控
        var removedCount = 0
        for region in locationManager.monitoredRegions {
            if region.identifier.hasPrefix("poi_") {
                locationManager.stopMonitoring(for: region)
                removedCount += 1
            }
        }

        print("   🗑️ 清除了 \(removedCount) 个地理围栏")

        // 清空数据
        nearbyPOIs.removeAll()
        scavengedPOIIds.removeAll()
        currentPOI = nil
        showPOIPopup = false

        print("   ✅ 清空了 POI 列表和状态")
        print("🧹 ========== 清除完成 ==========\n")
    }

    // MARK: - 私有方法

    /// 处理新的位置更新
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else { return }

        print("\n🛰️ ========== GPS位置更新 ==========")
        print("   📍 坐标: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
        print("   🎯 精度: \(String(format: "%.2f", location.horizontalAccuracy))m")
        print("   🚀 速度: \(String(format: "%.2f", location.speed))m/s (\(String(format: "%.2f", location.speed * 3.6))km/h)")
        print("   ⏰ 时间: \(location.timestamp)")

        // 1. 检查精度
        if location.horizontalAccuracy > accuracyThreshold {
            print("❌ 精度检查失败: \(String(format: "%.2f", location.horizontalAccuracy))m > \(accuracyThreshold)m，忽略此点")
            return
        }
        print("✅ 精度检查通过")

        // 2. 检查时间间隔
        if let lastTime = lastLocationUpdateTime {
            let timeInterval = location.timestamp.timeIntervalSince(lastTime)
            if timeInterval < minimumTimeInterval {
                print("❌ 时间间隔检查失败: \(String(format: "%.2f", timeInterval))s < \(minimumTimeInterval)s，忽略此点")
                return
            }
            print("✅ 时间间隔检查通过: \(String(format: "%.2f", timeInterval))s")
        }

        // 3. 计算速度并检查是否超速
        var calculatedSpeed: Double = 0
        if let lastLocation = lastValidLocation, let lastTime = lastLocationUpdateTime {
            let distance = location.distance(from: lastLocation)
            let timeInterval = location.timestamp.timeIntervalSince(lastTime)

            print("⏱️ ========== 速度计算详情 ==========")
            print("   📏 距离: \(String(format: "%.2f", distance))m")
            print("   ⏰ 时间间隔: \(String(format: "%.2f", timeInterval))s")

            if timeInterval > 0 {
                calculatedSpeed = distance / timeInterval
                currentSpeed = calculatedSpeed

                let speedKmh = calculatedSpeed * 3.6
                print("   🚀 计算速度: \(String(format: "%.2f", calculatedSpeed))m/s = \(String(format: "%.1f", speedKmh))km/h")
                print("   📱 GPS速度: \(String(format: "%.2f", location.speed))m/s = \(String(format: "%.1f", location.speed * 3.6))km/h")

                // 检查是否超速（30km/h = 8.33m/s）
                if calculatedSpeed > speedLimit {
                    print("⚠️ ========== 速度超限 ==========")
                    print("   当前速度: \(String(format: "%.1f", speedKmh))km/h")
                    print("   限制速度: 30km/h")
                    handleSpeedWarning(speed: calculatedSpeed)
                } else {
                    // 速度正常，清除警告
                    if speedWarning != nil {
                        print("✅ 速度恢复正常，清除警告")
                        clearSpeedWarning()
                    }
                }
            }
        }

        // 4. 检查距离跳变
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)

            if distance > distanceJumpThreshold {
                print("❌ 距离跳变检查失败: \(String(format: "%.2f", distance))m > \(distanceJumpThreshold)m，忽略此点")
                return
            }
            print("✅ 距离跳变检查通过: \(String(format: "%.2f", distance))m")

            // 累加距离
            currentDistance += distance
            print("📏 ========== 距离统计 ==========")
            print("   ➕ 新增: \(String(format: "%.2f", distance))m")
            print("   📍 累计: \(String(format: "%.2f", currentDistance))m")

            // 检查是否达到新的奖励等级
            checkRewardTierUpgrade()
        }

        // 5. 保存为有效点
        lastValidLocation = location
        lastLocationUpdateTime = location.timestamp
        explorationPath.append(location.coordinate)

        print("✅ GPS点已记录，当前轨迹点数: \(explorationPath.count)")
        print("====================================\n")
    }

    /// 处理速度警告
    private func handleSpeedWarning(speed: Double) {
        let speedKmh = speed * 3.6

        if speedWarningStartTime == nil {
            // 第一次超速，开始警告
            speedWarningStartTime = Date()
            speedWarning = String(format: "速度过快 %.0fkm/h！请降低速度", speedKmh)
            print("⚠️ 开始速度警告，10秒后若未降速将停止探索")

            // 启动10秒倒计时
            speedWarningTimer?.invalidate()
            speedWarningTimer = Timer.scheduledTimer(withTimeInterval: speedWarningDuration, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    // 10秒后仍在超速，停止探索
                    self.failExploration(reason: "速度持续超过限制，探索自动停止")
                }
            }
        } else {
            // 持续超速，更新警告消息
            if let startTime = speedWarningStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let remaining = max(0, speedWarningDuration - elapsed)
                speedWarning = String(format: "速度过快 %.0fkm/h！%.0f秒后自动停止", speedKmh, remaining)
                print("⚠️ 持续超速，剩余时间: \(String(format: "%.0f", remaining))秒")
            }
        }
    }

    /// 清除速度警告
    private func clearSpeedWarning() {
        speedWarning = nil
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil
        speedWarningStartTime = nil
        print("✅ 速度警告已清除")
    }

    /// 探索失败
    private func failExploration(reason: String) {
        print("❌ ========== 探索失败 ==========")
        print("   原因: \(reason)")
        print("================================")

        explorationFailed = true
        failureReason = reason

        // 停止探索
        _ = stopExploration()
    }

    /// 检查奖励等级提升
    private func checkRewardTierUpgrade() {
        let currentTier = RewardGenerator.calculateTier(distance: currentDistance)

        // 如果等级提升
        if currentTier.rawValue > lastRewardTier.rawValue {
            lastRewardTier = currentTier

            // 生成通知消息
            let tierName: String

            switch currentTier {
            case .none:
                return // 无奖励不通知
            case .bronze:
                tierName = "🥉 铜级"
            case .silver:
                tierName = "🥈 银级"
            case .gold:
                tierName = "🥇 金级"
            case .diamond:
                tierName = "💎 钻石"
            }

            itemDiscoveryNotification = "🎉 达到\(tierName)！"
            print("   🎁 等级提升: \(tierName) (距离: \(Int(currentDistance))m)")

            // 3秒后自动清除通知
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                itemDiscoveryNotification = nil
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {
    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            handleLocationUpdate(location)
        }
    }

    /// 位置更新失败回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ GPS定位失败: \(error.localizedDescription)")
    }
}
