//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 领地建筑列表行组件
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate

    var onUpgrade: (() -> Void)?
    var onDemolish: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            Image(systemName: template.category.icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(12)

            // 中间：名称 + 状态
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(building.buildingName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(4)
                }

                // 状态信息
                if building.status == .constructing {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(building.formattedRemainingTime)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(building.status.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(building.status.color)
                }
            }

            Spacer()

            // 右侧：操作菜单或进度环
            if building.status == .active {
                Menu {
                    // 升级按钮
                    if building.level >= template.maxLevel {
                        Button {
                            // 已达最高等级
                        } label: {
                            Label("已达最高等级", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(true)
                    } else {
                        Button {
                            onUpgrade?()
                        } label: {
                            Label("升级到 Lv.\(building.level + 1)", systemImage: "arrow.up.circle")
                        }
                    }

                    Divider()

                    // 拆除按钮
                    Button(role: .destructive) {
                        onDemolish?()
                    } label: {
                        Label("拆除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            } else if building.status == .constructing {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: building.buildProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: building.buildProgress)
                }
                .frame(width: 40, height: 40)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    let activeBuilding = PlayerBuilding(
        id: "test-1",
        userId: "user-1",
        territoryId: "territory-1",
        templateId: "building_campfire",
        buildingName: "篝火",
        status: .active,
        level: 2,
        locationLat: 39.9042,
        locationLon: 116.4074,
        buildStartedAt: Date(),
        buildCompletedAt: Date(),
        createdAt: Date(),
        updatedAt: Date()
    )

    let constructingBuilding = PlayerBuilding(
        id: "test-2",
        userId: "user-1",
        territoryId: "territory-1",
        templateId: "building_storage_small",
        buildingName: "小型仓库",
        status: .constructing,
        level: 1,
        locationLat: 39.9042,
        locationLon: 116.4074,
        buildStartedAt: Date(),
        buildCompletedAt: Date().addingTimeInterval(300),
        createdAt: Date(),
        updatedAt: Date()
    )

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

    return VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: activeBuilding,
            template: template,
            onUpgrade: { print("升级") },
            onDemolish: { print("拆除") }
        )

        TerritoryBuildingRow(
            building: constructingBuilding,
            template: template
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
