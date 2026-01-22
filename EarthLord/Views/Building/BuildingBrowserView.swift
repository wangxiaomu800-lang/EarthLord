//
//  BuildingBrowserView.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI

/// 建筑浏览器（分类筛选 + 网格展示）
struct BuildingBrowserView: View {
    @StateObject private var buildingManager = BuildingManager.shared

    @State private var selectedCategory: BuildingCategory?

    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.buildingTemplates.filter { $0.category == category }
        } else {
            return buildingManager.buildingTemplates
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryFilterBar

                // 建筑网格
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredTemplates) { template in
                            BuildingCard(template: template)
                                .onTapGesture {
                                    onStartConstruction(template)
                                }
                        }
                    }
                    .padding()
                }
                .background(ApocalypseTheme.background)
            }
            .navigationTitle("建筑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
            .task {
                // 加载建筑模板
                if buildingManager.buildingTemplates.isEmpty {
                    do {
                        try await buildingManager.loadTemplates()
                    } catch {
                        print("❌ 加载建筑模板失败: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部
                CategoryButton(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    action: {
                        withAnimation {
                            selectedCategory = nil
                        }
                    }
                )

                // 各分类
                ForEach([BuildingCategory.survival, .storage, .production, .energy], id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: {
                            withAnimation {
                                selectedCategory = category
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .background(ApocalypseTheme.cardBackground)
    }
}

#Preview {
    BuildingBrowserView(
        onDismiss: {},
        onStartConstruction: { template in
            print("开始建造: \(template.name)")
        }
    )
}
