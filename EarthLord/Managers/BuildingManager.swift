//
//  BuildingManager.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import Foundation
import Supabase
import Combine

@MainActor
class BuildingManager: ObservableObject {
    static let shared = BuildingManager()

    // MARK: - Published Properties

    @Published var buildingTemplates: [BuildingTemplate] = []
    @Published var playerBuildings: [PlayerBuilding] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabase = SupabaseConfig.shared
    private let inventoryManager = InventoryManager.shared
    private var buildCheckTimer: Timer?

    // MARK: - Initialization

    private init() {
        print("🏗️ BuildingManager initialized")
    }

    deinit {
        buildCheckTimer?.invalidate()
    }

    // MARK: - Template Loading

    /// 从 Bundle 加载建筑模板
    func loadTemplates() async throws {
        print("📚 开始加载建筑模板...")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ 未找到 building_templates.json")
            throw BuildingError.templateNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        buildingTemplates = try decoder.decode([BuildingTemplate].self, from: data)

        print("✅ 加载了 \(buildingTemplates.count) 个建筑模板")
        buildingTemplates.forEach { template in
            print("   - \(template.name) (\(template.templateId))")
        }
    }

    /// 根据 ID 查找模板
    func findTemplate(byId templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    // MARK: - Resource Management

    /// 将资源键映射到物品 ID
    /// JSON 中的 "wood" -> InventoryManager 中的 "item_wood"
    private func mapResourceKeyToItemId(_ resourceKey: String) -> String {
        if resourceKey.hasPrefix("item_") {
            return resourceKey
        }
        return "item_\(resourceKey)"
    }

    /// 检查资源可用性
    /// - Returns: 缺少的资源列表（空表示资源充足）
    private func checkResourceAvailability(required: [String: Int]) -> [String: Int] {
        var missing: [String: Int] = [:]

        for (resourceKey, requiredQuantity) in required {
            let itemId = mapResourceKeyToItemId(resourceKey)

            let currentQuantity = inventoryManager.inventoryItems
                .first { $0.itemId == itemId }?
                .quantity ?? 0

            if currentQuantity < requiredQuantity {
                missing[resourceKey] = requiredQuantity - currentQuantity
            }
        }

        return missing
    }

    /// 消耗资源（扣除背包物品）
    private func consumeResources(_ resources: [String: Int]) async throws {
        print("💰 开始扣除资源...")

        for (resourceKey, quantity) in resources {
            let itemId = mapResourceKeyToItemId(resourceKey)
            try await inventoryManager.removeItem(itemId: itemId, quantity: quantity)
            print("   ✅ 扣除 \(itemId) x\(quantity)")
        }

        print("✅ 资源扣除完成")
    }

    // MARK: - Building Construction

    /// 检查是否可以建造
    func canBuild(templateId: String, territoryId: String) async throws -> (canBuild: Bool, reason: String?) {
        // 1. 检查模板是否存在
        guard let template = findTemplate(byId: templateId) else {
            return (false, "建筑模板不存在")
        }

        // 2. 检查领地建造数量限制
        if let maxPerTerritory = template.maxPerTerritory {
            let existingCount = playerBuildings.filter {
                $0.territoryId == territoryId && $0.templateId == templateId
            }.count

            if existingCount >= maxPerTerritory {
                return (false, "该建筑在此领地已达建造上限（\(maxPerTerritory)）")
            }
        }

        // 3. 检查资源是否充足
        let missingResources = checkResourceAvailability(required: template.requiredResources)

        if !missingResources.isEmpty {
            let missingList = missingResources.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            return (false, "资源不足：\(missingList)")
        }

        return (true, nil)
    }

    /// 开始建造
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)? = nil
    ) async throws -> PlayerBuilding {
        print("🏗️ 开始建造: \(templateId)")

        // 1. 检查能否建造
        let (canBuild, reason) = try await canBuild(templateId: templateId, territoryId: territoryId)
        guard canBuild else {
            if let reason = reason {
                print("❌ 无法建造: \(reason)")
                throw BuildingError.insufficientResources(missing: [:])
            } else {
                throw BuildingError.templateNotFound
            }
        }

        // 2. 获取模板和用户 ID
        guard let template = findTemplate(byId: templateId) else {
            throw BuildingError.templateNotFound
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        // 3. 扣除资源
        try await consumeResources(template.requiredResources)

        // 4. 计算建造完成时间
        let startTime = Date()
        let completionTime = startTime.addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        // 5. 插入数据库
        let insertDTO = PlayerBuildingInsertDTO(
            user_id: userId,
            territory_id: territoryId,
            template_id: templateId,
            building_name: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            location_lat: location?.lat,
            location_lon: location?.lon,
            build_started_at: startTime,
            build_completed_at: completionTime
        )

        let response: [PlayerBuildingDTO] = try await supabase
            .from("player_buildings")
            .insert(insertDTO)
            .select()
            .execute()
            .value

        guard let buildingDTO = response.first else {
            throw BuildingError.buildingNotFound
        }

        let newBuilding = buildingDTO.toPlayerBuilding()
        playerBuildings.append(newBuilding)

        print("✅ 建造开始：\(template.name)，预计 \(template.buildTimeSeconds) 秒后完成")

        // 6. 启动定时器检查建造完成
        startBuildCheckTimer()

        return newBuilding
    }

    // MARK: - Building Completion

    /// 启动定时器检查建造完成
    private func startBuildCheckTimer() {
        guard buildCheckTimer == nil else { return }

        print("⏰ 启动建造完成检查定时器")

        buildCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndCompleteBuildings()
            }
        }
    }

    /// 停止定时器
    private func stopBuildCheckTimer() {
        buildCheckTimer?.invalidate()
        buildCheckTimer = nil
        print("⏰ 停止建造完成检查定时器")
    }

    /// 检查并完成所有已到期的建筑
    func checkAndCompleteBuildings() async {
        let constructingBuildings = playerBuildings.filter {
            $0.status == .constructing && ($0.buildCompletedAt ?? Date()) <= Date()
        }

        if constructingBuildings.isEmpty {
            // 如果没有建造中的建筑，停止定时器
            if !playerBuildings.contains(where: { $0.isConstructing }) {
                stopBuildCheckTimer()
            }
            return
        }

        print("🔍 检查到 \(constructingBuildings.count) 个待完成的建筑")

        for building in constructingBuildings {
            do {
                try await completeConstruction(buildingId: building.id)
            } catch {
                print("❌ 完成建造失败: \(error.localizedDescription)")
            }
        }
    }

    /// 完成建造
    func completeConstruction(buildingId: String) async throws {
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        guard building.status == .constructing else {
            return
        }

        print("🎉 完成建造: \(buildingId)")

        // 更新数据库
        let updateDTO = PlayerBuildingUpdateDTO(
            status: BuildingStatus.active.rawValue,
            level: nil,
            build_completed_at: Date(),
            updated_at: Date()
        )

        guard let buildingUUID = UUID(uuidString: buildingId) else {
            throw BuildingError.buildingNotFound
        }

        try await supabase
            .from("player_buildings")
            .update(updateDTO)
            .eq("id", value: buildingUUID)
            .execute()

        // 更新本地数据
        if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
            let updatedBuilding = PlayerBuilding(
                id: building.id,
                userId: building.userId,
                territoryId: building.territoryId,
                templateId: building.templateId,
                buildingName: building.buildingName,
                status: .active,
                level: building.level,
                locationLat: building.locationLat,
                locationLon: building.locationLon,
                buildStartedAt: building.buildStartedAt,
                buildCompletedAt: Date(),
                createdAt: building.createdAt,
                updatedAt: Date()
            )

            playerBuildings[index] = updatedBuilding

            print("✅ 建筑完工：\(building.buildingName)")
        }
    }

    // MARK: - Fetch Buildings

    /// 获取领地建筑
    func fetchPlayerBuildings(territoryId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        print("📋 获取领地建筑: \(territoryId)")

        guard let userId = try? await supabase.auth.session.user.id else {
            throw BuildingError.notAuthenticated
        }

        let response: [PlayerBuildingDTO] = try await supabase
            .from("player_buildings")
            .select()
            .eq("user_id", value: userId)
            .eq("territory_id", value: territoryId)
            .order("created_at", ascending: false)
            .execute()
            .value

        playerBuildings = response.map { $0.toPlayerBuilding() }

        print("✅ 获取了 \(playerBuildings.count) 个建筑")

        // 如果有建造中的建筑，启动定时器
        if playerBuildings.contains(where: { $0.status == .constructing }) {
            startBuildCheckTimer()
        }

        // 立即检查一次是否有已完成的建筑
        await checkAndCompleteBuildings()
    }

    // MARK: - Building Upgrade

    /// 升级建筑
    func upgradeBuilding(buildingId: String) async throws {
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        guard building.status == .active else {
            throw BuildingError.buildingNotActive
        }

        guard let template = findTemplate(byId: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        guard building.level < template.maxLevel else {
            throw BuildingError.alreadyMaxLevel
        }

        let nextLevel = building.level + 1

        print("⬆️ 升级建筑: \(building.buildingName) Lv.\(building.level) -> Lv.\(nextLevel)")

        // 检查升级所需资源
        let requiredResources = template.resourcesForLevel(nextLevel)
        let missingResources = checkResourceAvailability(required: requiredResources)

        guard missingResources.isEmpty else {
            throw BuildingError.insufficientResources(missing: missingResources)
        }

        // 扣除资源
        try await consumeResources(requiredResources)

        // 更新数据库
        let updateDTO = PlayerBuildingUpdateDTO(
            status: nil,
            level: nextLevel,
            build_completed_at: nil,
            updated_at: Date()
        )

        guard let buildingUUID = UUID(uuidString: buildingId) else {
            throw BuildingError.buildingNotFound
        }

        try await supabase
            .from("player_buildings")
            .update(updateDTO)
            .eq("id", value: buildingUUID)
            .execute()

        // 更新本地数据
        if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
            let updatedBuilding = PlayerBuilding(
                id: building.id,
                userId: building.userId,
                territoryId: building.territoryId,
                templateId: building.templateId,
                buildingName: building.buildingName,
                status: building.status,
                level: nextLevel,
                locationLat: building.locationLat,
                locationLon: building.locationLon,
                buildStartedAt: building.buildStartedAt,
                buildCompletedAt: building.buildCompletedAt,
                createdAt: building.createdAt,
                updatedAt: Date()
            )

            playerBuildings[index] = updatedBuilding

            print("✅ 升级成功：\(building.buildingName) 现在是 Lv.\(nextLevel)")
        }
    }
}
