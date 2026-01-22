//
//  BuildingPlacementView.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI
import CoreLocation

/// 建筑放置确认页（资源检查 + 位置选择）
struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territoryId: String
    let territoryCoordinates: [CLLocationCoordinate2D]

    let onDismiss: () -> Void
    let onConstructionStarted: (PlayerBuilding) -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isConstructing = false
    @State private var errorMessage: String?

    var resourceAvailability: [(key: String, required: Int, current: Int, sufficient: Bool)] {
        template.requiredResources.map { (key, required) in
            let itemId = key.hasPrefix("item_") ? key : "item_\(key)"
            let current = inventoryManager.inventoryItems.first { $0.itemId == itemId }?.quantity ?? 0
            return (key: key, required: required, current: current, sufficient: current >= required)
        }
    }

    var allResourcesSufficient: Bool {
        resourceAvailability.allSatisfy { $0.sufficient }
    }

    var canConfirmConstruction: Bool {
        allResourcesSufficient && selectedLocation != nil
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑预览
                    buildingPreviewSection

                    // 资源检查
                    resourceCheckSection

                    // 位置选择
                    locationSelectionSection

                    // 确认建造按钮
                    confirmButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建造确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: buildingManager.playerBuildings.filter { $0.territoryId == territoryId },
                    buildingTemplates: Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) }),
                    selectedCoordinate: $selectedLocation,
                    onDismiss: { showLocationPicker = false }
                )
            }
            .alert("建造失败", isPresented: .constant(errorMessage != nil)) {
                Button("确定") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Building Preview Section

    private var buildingPreviewSection: some View {
        VStack(spacing: 12) {
            // 建筑图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: template.category.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            // 建筑名称
            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 分类徽章
            Text(template.category.displayName)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(12)

            // 建造时间
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text(formatBuildTime(template.buildTimeSeconds))
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Resource Check Section

    private var resourceCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("所需资源")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 资源状态标识
                if allResourcesSufficient {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("充足")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text("不足")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            VStack(spacing: 8) {
                ForEach(resourceAvailability, id: \.key) { resource in
                    ResourceRow(
                        resourceKey: resource.key,
                        requiredQuantity: resource.required,
                        currentQuantity: resource.current
                    )
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Location Selection Section

    private var locationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("建筑位置")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已选择位置")
                                .font(.body)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                            Text("纬度: \(String(format: "%.6f", location.latitude))")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Text("经度: \(String(format: "%.6f", location.longitude))")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("点击在地图上选择位置")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding()
                .background(selectedLocation != nil ? Color.green.opacity(0.1) : ApocalypseTheme.background)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isConstructing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                    Text("确认建造")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canConfirmConstruction ? ApocalypseTheme.primary : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canConfirmConstruction || isConstructing)
    }

    // MARK: - Helper Methods

    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)分钟"
        } else {
            let hours = seconds / 3600
            return "\(hours)小时"
        }
    }

    private func startConstruction() async {
        guard let location = selectedLocation else { return }

        isConstructing = true
        defer { isConstructing = false }

        do {
            let building = try await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territoryId,
                location: (lat: location.latitude, lon: location.longitude)
            )

            print("✅ 建造开始: \(template.name)")
            onConstructionStarted(building)
        } catch {
            print("❌ 建造失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let template = BuildingTemplate(
        templateId: "building_campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        requiredResources: ["wood": 5, "stone": 3],
        buildTimeSeconds: 60,
        maxPerTerritory: nil,
        maxLevel: 3
    )

    let coordinates = [
        CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        CLLocationCoordinate2D(latitude: 39.9052, longitude: 116.4074),
        CLLocationCoordinate2D(latitude: 39.9052, longitude: 116.4084),
        CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4084)
    ]

    return BuildingPlacementView(
        template: template,
        territoryId: "test-territory",
        territoryCoordinates: coordinates,
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
