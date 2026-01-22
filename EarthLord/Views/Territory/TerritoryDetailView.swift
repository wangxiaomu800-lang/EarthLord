//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情视图（全屏地图布局）
//  显示领地地图、建筑列表、建造功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {
    // MARK: - Properties

    /// 领地数据（mutable for rename）
    @State var territory: Territory

    /// 删除回调
    let onDelete: () -> Void

    // MARK: - Managers

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - State

    /// 是否显示信息面板
    @State private var showInfoPanel = true

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造确认）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 是否显示重命名对话框
    @State private var showRenameDialog = false

    /// 新领地名称
    @State private var newTerritoryName = ""

    /// 是否显示删除确认对话框
    @State private var showingDeleteConfirmation = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 选中的建筑（用于升级）
    @State private var selectedBuildingForUpgrade: PlayerBuilding?

    /// 选中的建筑（用于拆除）
    @State private var selectedBuildingForDemolish: PlayerBuilding?

    /// 关闭视图
    @Environment(\.dismiss) var dismiss

    // MARK: - Computed Properties

    /// 领地坐标
    var territoryCoordinates: [CLLocationCoordinate2D] {
        let coords = territory.toCoordinates()
        // ⚠️ 数据库中已经存储了 GCJ-02 坐标，直接使用
        return CoordinateConverter.wgs84ToGcj02(coords)
    }

    /// 领地建筑列表
    var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 建筑模板字典
    var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 底层：全屏地图
            TerritoryMapView(
                territoryCoordinates: territoryCoordinates,
                buildings: territoryBuildings,
                templates: templateDict
            )
            .ignoresSafeArea()

            // 2. 顶部：悬浮工具栏
            VStack {
                TerritoryToolbarView(
                    onDismiss: { dismiss() },
                    onBuildingBrowser: { showBuildingBrowser = true },
                    showInfoPanel: $showInfoPanel
                )
                Spacer()
            }

            // 3. 底部：可折叠信息面板
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            Task {
                // 加载建筑模板
                if buildingManager.buildingTemplates.isEmpty {
                    try? await buildingManager.loadTemplates()
                }
                // 加载领地建筑
                try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            }
        }
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    // 1. 先关闭浏览器
                    showBuildingBrowser = false

                    // 2. 延迟 0.3 秒等待关闭动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 3. 再打开建造确认页
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territoryCoordinates,
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { building in
                    selectedTemplateForConstruction = nil
                    Task {
                        try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                    }
                }
            )
        }
        .alert("重命名领地", isPresented: $showRenameDialog) {
            TextField("领地名称", text: $newTerritoryName)
            Button("取消", role: .cancel) {}
            Button("确认") {
                Task {
                    await renameTerritory()
                }
            }
        } message: {
            Text("请输入新的领地名称")
        }
        .alert("升级建筑", isPresented: .constant(selectedBuildingForUpgrade != nil)) {
            Button("取消", role: .cancel) {
                selectedBuildingForUpgrade = nil
            }
            Button("确认升级") {
                Task {
                    if let building = selectedBuildingForUpgrade {
                        await upgradeBuilding(buildingId: building.id)
                        selectedBuildingForUpgrade = nil
                    }
                }
            }
        } message: {
            if let building = selectedBuildingForUpgrade,
               let template = templateDict[building.templateId] {
                let nextLevel = building.level + 1
                let resources = template.resourcesForLevel(nextLevel)
                let resourceList = resources.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
                Text("升级到 Lv.\(nextLevel) 需要：\(resourceList)")
            } else {
                Text("")
            }
        }
        .alert("拆除建筑", isPresented: .constant(selectedBuildingForDemolish != nil)) {
            Button("取消", role: .cancel) {
                selectedBuildingForDemolish = nil
            }
            Button("确认拆除", role: .destructive) {
                Task {
                    if let building = selectedBuildingForDemolish {
                        await demolishBuilding(buildingId: building.id)
                        selectedBuildingForDemolish = nil
                    }
                }
            }
        } message: {
            if let building = selectedBuildingForDemolish {
                Text("确定要拆除 \(building.buildingName) 吗？此操作不可撤销。")
            } else {
                Text("")
            }
        }
        .alert("删除领地", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteTerritoryAction()
                }
            }
        } message: {
            Text("确定要删除此领地吗？此操作不可撤销。")
        }
    }

    // MARK: - Info Panel

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名称 + 齿轮按钮
                    HStack {
                        Text(territory.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Spacer()

                        Button {
                            newTerritoryName = territory.name ?? "我的领地"
                            showRenameDialog = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }

                    // 领地信息卡片
                    territoryInfoCard

                    // 建筑列表区域
                    buildingListSection

                    // 删除领地按钮
                    deleteButton
                }
                .padding()
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .background(ApocalypseTheme.background)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
    }

    // MARK: - Territory Info Card

    private var territoryInfoCard: some View {
        VStack(spacing: 12) {
            InfoRow(
                icon: "map.fill",
                title: "面积",
                value: territory.formattedArea,
                color: .orange
            )

            Divider()

            if let pointCount = territory.pointCount {
                InfoRow(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "路径点数",
                    value: "\(pointCount) 点",
                    color: .blue
                )

                Divider()
            }

            if let createdAt = territory.createdAt {
                InfoRow(
                    icon: "calendar",
                    title: "创建时间",
                    value: formatDate(createdAt),
                    color: .green
                )
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Building List Section

    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地建筑")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(territoryBuildings.count)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(8)
            }

            if territoryBuildings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("还没有建筑")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("点击顶部「建造」按钮开始建造")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(territoryBuildings) { building in
                        if let template = templateDict[building.templateId] {
                            TerritoryBuildingRow(
                                building: building,
                                template: template,
                                onUpgrade: {
                                    selectedBuildingForUpgrade = building
                                },
                                onDemolish: {
                                    selectedBuildingForDemolish = building
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                    Text("删除领地")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }

    // MARK: - Methods

    private func formatDate(_ dateString: String) -> String {
        let standardISOString = dateString
            .replacingOccurrences(of: " ", with: "T")
            .replacingOccurrences(of: "+00", with: "+00:00")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: standardISOString) else {
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            guard let fallbackDate = fallbackFormatter.date(from: dateString) else {
                return "未知时间"
            }

            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current

            return displayFormatter.string(from: fallbackDate)
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current

        return displayFormatter.string(from: date)
    }

    private func renameTerritory() async {
        print("🔧 TerritoryDetailView.renameTerritory() 开始")
        print("   旧名称: \(territory.name ?? "nil")")
        print("   新名称: \(newTerritoryName)")
        print("   领地 ID: \(territory.id)")

        guard !newTerritoryName.isEmpty else {
            print("❌ 新名称为空，取消操作")
            return
        }

        do {
            try await TerritoryManager.shared.updateTerritoryName(
                territoryId: territory.id,
                newName: newTerritoryName
            )

            print("✅ TerritoryManager 更新成功，开始更新本地对象")

            // 更新本地对象
            territory = Territory(
                id: territory.id,
                userId: territory.userId,
                name: newTerritoryName,
                path: territory.path,
                area: territory.area,
                pointCount: territory.pointCount,
                isActive: territory.isActive,
                completedAt: territory.completedAt,
                startedAt: territory.startedAt,
                createdAt: territory.createdAt
            )

            print("✅ 本地对象已更新，新名称: \(territory.displayName)")

            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)

            print("✅ 已发送 territoryUpdated 通知")
            print("✅ 领地重命名完成: \(newTerritoryName)")
        } catch {
            print("❌ 重命名失败: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Localized description: \(error.localizedDescription)")
        }
    }

    private func upgradeBuilding(buildingId: String) async {
        do {
            try await buildingManager.upgradeBuilding(buildingId: buildingId)
            try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            print("❌ 升级失败: \(error)")
        }
    }

    private func demolishBuilding(buildingId: String) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: buildingId)
            try? await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        } catch {
            print("❌ 拆除失败: \(error)")
        }
    }

    private func deleteTerritoryAction() async {
        isDeleting = true
        defer { isDeleting = false }

        let success = await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)

        if success {
            print("✅ 领地已删除")
            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
            onDelete()
            dismiss()
        } else {
            print("❌ 删除领地失败")
        }
    }
}

// MARK: - Info Row Component

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

// MARK: - View Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41],
                ["lat": 39.9, "lon": 116.4]
            ],
            area: 1234.5,
            pointCount: 5,
            isActive: true,
            completedAt: "2024-01-01T12:00:00Z",
            startedAt: nil,
            createdAt: "2024-01-01T12:00:00Z"
        ),
        onDelete: {}
    )
}
