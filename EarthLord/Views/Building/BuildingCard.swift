//
//  BuildingCard.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 建筑卡片组件
struct BuildingCard: View {
    let template: BuildingTemplate

    var body: some View {
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
                    .frame(width: 60, height: 60)

                Image(systemName: template.category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            // 建筑名称
            Text(template.name)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // 分类徽章
            Text(template.category.displayName)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(8)

            // 资源预览
            HStack(spacing: 4) {
                Image(systemName: "cube.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(template.requiredResources.count) 种资源")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 建造时间
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(formatBuildTime(template.buildTimeSeconds))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

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

    return BuildingCard(template: template)
        .frame(width: 160)
        .padding()
        .background(ApocalypseTheme.background)
}
