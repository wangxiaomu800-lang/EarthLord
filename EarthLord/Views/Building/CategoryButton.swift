//
//  CategoryButton.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 建筑分类筛选按钮
struct CategoryButton: View {
    let category: BuildingCategory?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text("全部")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ApocalypseTheme.primary, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CategoryButton(category: nil, isSelected: true, action: {})
        CategoryButton(category: .survival, isSelected: false, action: {})
        CategoryButton(category: .storage, isSelected: false, action: {})
    }
    .padding()
    .background(ApocalypseTheme.background)
}
