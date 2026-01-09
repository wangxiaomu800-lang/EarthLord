//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示玩家持有的物品，支持搜索、筛选、使用和存储
//

import SwiftUI

struct BackpackView: View {
    // MARK: - 状态

    /// 搜索关键词
    @State private var searchText: String = ""

    /// 当前选中的分类筛选（nil 表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包物品列表
    @State private var backpackItems: [BackpackItem] = MockExplorationData.backpackItems

    // MARK: - 常量

    /// 背包最大容量
    private let maxCapacity: Double = 100.0

    // MARK: - 计算属性

    /// 当前背包使用量（根据物品重量计算）
    private var currentCapacity: Double {
        return MockExplorationData.calculateTotalWeight()
    }

    /// 使用百分比
    private var usagePercentage: Double {
        return currentCapacity / maxCapacity
    }

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var result = backpackItems

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { item in
                if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
                    return definition.category == category
                }
                return false
            }
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        return result
    }

    /// 进度条颜色
    private var progressColor: Color {
        if usagePercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if usagePercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 是否显示警告
    private var showWarning: Bool {
        return usagePercentage > 0.9
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 容量状态卡
                    capacityCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 搜索框
                    searchBar
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表
                    itemListView
                        .padding(.top, 12)
                }
            }
            .navigationTitle("背包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 子视图

    /// 容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 容量数值
                Text(String(format: "%.1f / %.0f kg", currentCapacity, maxCapacity))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(progressColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(usagePercentage, 1.0), height: 12)
                }
            }
            .frame(height: 12)

            // 警告文字
            if showWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)

                    Text("背包快满了！")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    /// 分类筛选
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                CategoryChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.iconName,
                        color: category.themeColor,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// 物品列表
    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredItems) { item in
                        if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
                            ItemCard(item: item, definition: definition)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Text("尝试清除搜索或切换分类")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Text("去探索世界收集物资吧")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - ItemCategory 扩展

extension ItemCategory {
    /// 主题颜色
    var themeColor: Color {
        switch self {
        case .water: return ApocalypseTheme.info        // 蓝色
        case .food: return ApocalypseTheme.warning      // 黄色
        case .medical: return ApocalypseTheme.danger    // 红色
        case .material: return ApocalypseTheme.textSecondary // 灰色
        case .tool: return ApocalypseTheme.primary      // 橙色
        }
    }
}

// MARK: - ItemRarity 扩展

extension ItemRarity {
    /// 主题颜色
    var themeColor: Color {
        switch self {
        case .common: return ApocalypseTheme.textSecondary   // 灰色
        case .uncommon: return ApocalypseTheme.success       // 绿色
        case .rare: return ApocalypseTheme.info              // 蓝色
        case .epic: return Color.purple                       // 紫色
        case .legendary: return ApocalypseTheme.primary      // 橙色
        }
    }
}

// MARK: - 分类按钮组件

/// 分类筛选按钮
private struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? color
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 物品卡片组件

/// 物品卡片视图
private struct ItemCard: View {
    let item: BackpackItem
    let definition: ItemDefinition

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            ZStack {
                Circle()
                    .fill(definition.category.themeColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: definition.category.iconName)
                    .font(.title3)
                    .foregroundColor(definition.category.themeColor)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称 + 稀有度
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    RarityBadge(rarity: definition.rarity)
                }

                // 第二行：数量、重量、品质
                HStack(spacing: 12) {
                    // 数量
                    Label("x\(item.quantity)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 重量
                    Label(String(format: "%.1fkg", definition.weight * Double(item.quantity)), systemImage: "scalemass")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        QualityBadge(quality: quality)
                    }
                }
            }

            Spacer()

            // 右侧：操作按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: { handleUse() }) {
                    Text("使用")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.success)
                        .cornerRadius(6)
                }

                // 存储按钮
                Button(action: { handleStore() }) {
                    Text("存储")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .cornerRadius(6)
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 方法

    /// 使用物品
    private func handleUse() {
        print("🎒 使用物品: \(definition.name) x1")
        print("   剩余数量: \(item.quantity - 1)")
        // TODO: 实现使用物品逻辑
    }

    /// 存储物品
    private func handleStore() {
        print("📦 存储物品: \(definition.name) x\(item.quantity)")
        print("   转移到仓库")
        // TODO: 实现存储物品逻辑
    }
}

// MARK: - 稀有度标签组件

/// 稀有度标签
private struct RarityBadge: View {
    let rarity: ItemRarity

    var body: some View {
        Text(rarity.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(rarity.themeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(rarity.themeColor.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - 品质标签组件

/// 品质标签
private struct QualityBadge: View {
    let quality: ItemQuality

    /// 品质颜色
    private var qualityColor: Color {
        switch quality {
        case .broken: return ApocalypseTheme.danger
        case .worn: return ApocalypseTheme.warning
        case .normal: return ApocalypseTheme.textSecondary
        case .good: return ApocalypseTheme.success
        case .excellent: return ApocalypseTheme.info
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 8))

            Text(quality.displayName)
                .font(.caption2)
        }
        .foregroundColor(qualityColor)
    }
}

// MARK: - 预览

#Preview {
    BackpackView()
}
