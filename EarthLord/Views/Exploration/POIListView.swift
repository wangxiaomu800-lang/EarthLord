//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示可探索的 POI 列表，支持分类筛选和搜索
//

import SwiftUI

struct POIListView: View {
    // MARK: - 状态

    /// 当前选中的分类筛选（nil 表示全部）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索中
    @State private var isSearching = false

    /// POI 列表数据
    @State private var poiList: [POI] = MockExplorationData.poiList

    /// 选中的 POI（用于跳转详情页）
    @State private var selectedPOI: POI? = nil

    /// 是否显示详情页
    @State private var showingDetail = false

    /// 模拟的 GPS 坐标
    private let mockLatitude: Double = 22.54
    private let mockLongitude: Double = 114.06

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        return poiList.filter { $0.status != .undiscovered }.count
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 状态栏
                    statusBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 搜索按钮
                    searchButton
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 筛选工具栏
                    filterToolbar
                        .padding(.top, 16)

                    // POI 列表
                    poiListView
                        .padding(.top, 12)
                }
            }
            .navigationTitle("附近地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingDetail) {
                if let poi = selectedPOI {
                    POIDetailView(poi: poi)
                }
            }
        }
    }

    // MARK: - 子视图

    /// 状态栏：显示 GPS 坐标和发现数量
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.2f, %.2f", mockLatitude, mockLongitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSearching
                    ? ApocalypseTheme.textMuted
                    : ApocalypseTheme.primary
            )
            .cornerRadius(12)
        }
        .disabled(isSearching)
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                FilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                ForEach(POIType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName.replacingOccurrences(of: "废墟", with: "").replacingOccurrences(of: "废弃", with: ""),
                        icon: type.iconName,
                        color: type.themeColor,
                        isSelected: selectedCategory == type
                    ) {
                        selectedCategory = type
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// POI 列表
    private var poiListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(filteredPOIs) { poi in
                        POICard(poi: poi)
                            .onTapGesture {
                                handlePOITap(poi)
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
            Image(systemName: "mappin.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到地点")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("尝试搜索或切换筛选条件")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 方法

    /// 执行搜索
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            print("🔍 搜索完成，找到 \(poiList.count) 个 POI")
        }
    }

    /// 处理 POI 点击
    private func handlePOITap(_ poi: POI) {
        print("📍 点击了 POI: \(poi.name) (ID: \(poi.id))")
        selectedPOI = poi
        showingDetail = true
    }
}

// MARK: - POIType 扩展

extension POIType: CaseIterable {
    static var allCases: [POIType] {
        return [.hospital, .supermarket, .factory, .pharmacy, .gasStation]
    }

    /// 主题颜色
    var themeColor: Color {
        switch self {
        case .hospital: return ApocalypseTheme.danger       // 红色
        case .supermarket: return ApocalypseTheme.success   // 绿色
        case .factory: return ApocalypseTheme.textSecondary // 灰色
        case .pharmacy: return Color.purple                  // 紫色
        case .gasStation: return ApocalypseTheme.primary    // 橙色
        }
    }
}

// MARK: - 筛选按钮组件

/// 筛选按钮
private struct FilterChip: View {
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

// MARK: - POI 卡片组件

/// POI 卡片视图
private struct POICard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：类型图标
            ZStack {
                Circle()
                    .fill(poi.type.themeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: poi.type.iconName)
                    .font(.title2)
                    .foregroundColor(poi.type.themeColor)
            }

            // 中间：名称和信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型
                Text(poi.type.displayName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 右侧：状态标签
            VStack(alignment: .trailing, spacing: 6) {
                // 发现状态
                statusBadge

                // 物资状态
                lootBadge
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    poi.status == .discovered && poi.canLoot
                        ? ApocalypseTheme.success.opacity(0.5)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }

    /// 发现状态标签
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(10)
    }

    /// 物资状态标签
    @ViewBuilder
    private var lootBadge: some View {
        switch poi.status {
        case .undiscovered:
            Text("???")
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
        case .discovered:
            if poi.canLoot {
                HStack(spacing: 4) {
                    Image(systemName: "cube.box.fill")
                        .font(.caption2)
                    Text("有物资")
                        .font(.caption2)
                }
                .foregroundColor(ApocalypseTheme.warning)
            } else {
                Text("无物资")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        case .looted:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .font(.caption2)
                Text("已搜空")
                    .font(.caption2)
            }
            .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered: return ApocalypseTheme.textMuted
        case .discovered: return ApocalypseTheme.success
        case .looted: return ApocalypseTheme.textSecondary
        }
    }

    /// 状态文字
    private var statusText: String {
        switch poi.status {
        case .undiscovered: return "未发现"
        case .discovered: return "已发现"
        case .looted: return "已探索"
        }
    }
}

// MARK: - 预览

#Preview {
    POIListView()
}
