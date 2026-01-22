//
//  ResourceRow.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 资源行组件（显示需求量和当前拥有量）
struct ResourceRow: View {
    let resourceKey: String
    let requiredQuantity: Int
    let currentQuantity: Int

    var isSufficient: Bool {
        currentQuantity >= requiredQuantity
    }

    var resourceDisplayName: String {
        // 将 "wood" -> "木材", "stone" -> "石头"
        switch resourceKey.lowercased() {
        case "wood": return "木材"
        case "stone": return "石头"
        case "iron": return "铁"
        case "electronics": return "电子元件"
        default: return resourceKey
        }
    }

    var resourceIcon: String {
        // 根据资源类型返回图标
        switch resourceKey.lowercased() {
        case "wood": return "tree.fill"
        case "stone": return "cube.fill"
        case "iron": return "hammer.fill"
        case "electronics": return "bolt.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.title3)
                .foregroundColor(isSufficient ? .green : .red)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSufficient ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                )

            // 资源名称
            Text(resourceDisplayName)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量显示
            HStack(spacing: 4) {
                Text("\(currentQuantity)")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(isSufficient ? .green : .red)

                Text("/")
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(requiredQuantity)")
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态图标
            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSufficient ? .green : .red)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResourceRow(resourceKey: "wood", requiredQuantity: 5, currentQuantity: 10)
        ResourceRow(resourceKey: "stone", requiredQuantity: 10, currentQuantity: 3)
        ResourceRow(resourceKey: "iron", requiredQuantity: 2, currentQuantity: 2)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
