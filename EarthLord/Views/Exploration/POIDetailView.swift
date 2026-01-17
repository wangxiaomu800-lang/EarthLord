//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示兴趣点的详细信息，支持搜寻、标记等操作
//

import SwiftUI

// MARK: - 危险等级枚举

/// POI 危险等级
enum DangerLevel: Int, CaseIterable {
    case safe = 0       // 安全
    case low = 1        // 低危
    case medium = 2     // 中危
    case high = 3       // 高危

    var displayName: String {
        switch self {
        case .safe: return "安全"
        case .low: return "低危"
        case .medium: return "中危"
        case .high: return "高危"
        }
    }

    var color: Color {
        switch self {
        case .safe: return ApocalypseTheme.success
        case .low: return ApocalypseTheme.info
        case .medium: return ApocalypseTheme.warning
        case .high: return ApocalypseTheme.danger
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .low: return "shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high: return "xmark.shield.fill"
        }
    }
}

// MARK: - POI 详情视图

struct POIDetailView: View {
    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 关闭回调
    @Environment(\.dismiss) var dismiss

    // MARK: - 状态

    /// 是否正在搜寻
    @State private var isSearching = false

    /// 是否显示搜寻结果
    @State private var showSearchResult = false

    // MARK: - 模拟数据

    /// 模拟距离（米）
    private let mockDistance: Double = 350

    /// 模拟危险等级
    private var dangerLevel: DangerLevel {
        switch poi.type {
        case .hospital: return .medium
        case .factory: return .high
        case .supermarket: return .low
        case .pharmacy: return .safe
        case .gasStation: return .medium
        }
    }

    /// 模拟数据来源
    private let dataSource: String = "地图数据"

    /// 是否可以搜寻
    private var canSearch: Bool {
        return poi.status == .discovered && poi.canLoot
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部大图区域
                        headerSection

                        // 信息区域
                        infoSection
                            .padding(.horizontal)
                            .padding(.top, 20)

                        // 操作按钮区域
                        actionSection
                            .padding(.horizontal)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSearchResult) {
                ExplorationResultView(result: generateMockResult())
            }
        }
    }

    // MARK: - 子视图

    /// 顶部大图区域
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    poi.type.themeColor,
                    poi.type.themeColor.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            // 大图标
            VStack {
                Spacer()

                Image(systemName: poi.type.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }
            .frame(height: 280)

            // 底部遮罩和文字
            VStack(spacing: 8) {
                Spacer()

                // 名称
                Text(poi.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // 类型
                Text(poi.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    /// 信息区域
    private var infoSection: some View {
        VStack(spacing: 12) {
            // 距离
            InfoRow(
                icon: "location.fill",
                title: NSLocalizedString("距离", comment: "Distance"),
                value: formatDistance(mockDistance),
                valueColor: ApocalypseTheme.textPrimary
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物资状态
            InfoRow(
                icon: "cube.box.fill",
                title: "物资状态",
                value: lootStatusText,
                valueColor: lootStatusColor
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 危险等级
            HStack {
                Image(systemName: dangerLevel.icon)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 24)

                Text("poi.danger_level")
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 危险等级标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(dangerLevel.color)
                        .frame(width: 8, height: 8)

                    Text(dangerLevel.displayName)
                        .fontWeight(.medium)
                        .foregroundColor(dangerLevel.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(dangerLevel.color.opacity(0.15))
                .cornerRadius(12)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 数据来源
            InfoRow(
                icon: "info.circle.fill",
                title: "来源",
                value: dataSource,
                valueColor: ApocalypseTheme.textSecondary
            )
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 操作按钮区域
    private var actionSection: some View {
        VStack(spacing: 16) {
            // 主按钮：搜寻此POI
            Button(action: performSearch) {
                HStack(spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("poi.searching")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)

                        Text("poi.search_poi")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    canSearch
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.textMuted,
                                ApocalypseTheme.textMuted
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(12)
            }
            .disabled(!canSearch || isSearching)

            // 不可搜寻时的提示
            if !canSearch {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)

                    Text(cannotSearchReason)
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    action: markAsDiscovered
                )

                // 标记无物资
                SecondaryButton(
                    title: "标记无物资",
                    icon: "xmark.bin.fill",
                    action: markAsEmpty
                )
            }
        }
    }

    // MARK: - 计算属性

    /// 物资状态文字
    private var lootStatusText: String {
        switch poi.status {
        case .undiscovered:
            return "未知"
        case .discovered:
            return poi.canLoot ? "有物资" : "无物资"
        case .looted:
            return "已清空"
        }
    }

    /// 物资状态颜色
    private var lootStatusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return poi.canLoot ? ApocalypseTheme.success : ApocalypseTheme.textSecondary
        case .looted:
            return ApocalypseTheme.textMuted
        }
    }

    /// 不可搜寻的原因
    private var cannotSearchReason: String {
        switch poi.status {
        case .undiscovered:
            return "需要先发现此地点"
        case .discovered:
            return poi.canLoot ? "" : "此地点没有可搜寻的物资"
        case .looted:
            return "此地点已被搜空"
        }
    }

    // MARK: - 方法

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: NSLocalizedString("%.1f 公里", comment: "%.1f km"), meters / 1000)
        } else {
            return String(format: NSLocalizedString("%.0f 米", comment: "%.0f m"), meters)
        }
    }

    /// 执行搜寻
    private func performSearch() {
        guard canSearch else { return }

        isSearching = true
        print("🔍 开始搜寻 POI: \(poi.name)")

        // 模拟 2 秒搜寻
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showSearchResult = true
            print("✅ 搜寻完成，显示结果")
        }
    }

    /// 标记已发现
    private func markAsDiscovered() {
        print("👁️ 标记为已发现: \(poi.name)")
        // TODO: 实现标记逻辑
    }

    /// 标记无物资
    private func markAsEmpty() {
        print("📦 标记为无物资: \(poi.name)")
        // TODO: 实现标记逻辑
    }

    /// 生成模拟的探索结果
    private func generateMockResult() -> ExplorationStats {
        // 获取 POI 的物品作为探索结果
        let items = poi.lootItems?.map { loot -> ObtainedItem in
            // 随机获得数量
            let randomQuantity = Int.random(in: 1...loot.quantity)
            return ObtainedItem(
                id: UUID().uuidString,
                itemId: loot.itemId,
                quantity: randomQuantity,
                quality: ItemQuality.allCases.randomElement()
            )
        } ?? []

        // 创建探索结果
        return ExplorationStats(
            walkingDistance: Double.random(in: 50...200),
            totalDistance: Double.random(in: 1000...5000),
            distanceRank: Int.random(in: 10...100),
            duration: TimeInterval(Int.random(in: 60...300)),
            obtainedItems: items
        )
    }
}

// MARK: - 信息行组件

/// 信息行视图
private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            Text(title)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 次要按钮组件

/// 次要按钮
private struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 预览

#Preview("有物资") {
    POIDetailView(poi: MockExplorationData.poiList[0])
}

#Preview("已搜空") {
    POIDetailView(poi: MockExplorationData.poiList[1])
}

#Preview("未发现") {
    POIDetailView(poi: MockExplorationData.poiList[2])
}
