//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易五个分段
//

import SwiftUI

struct ResourcesTabView: View {
    // MARK: - 分段枚举

    enum ResourceSection: String, CaseIterable, Identifiable {
        case poi
        case backpack
        case purchased
        case territory
        case trade

        var id: String { self.rawValue }

        var displayName: LocalizedStringKey {
            switch self {
            case .poi: return "resources.section.poi"
            case .backpack: return "resources.section.backpack"
            case .purchased: return "resources.section.purchased"
            case .territory: return "resources.section.territory"
            case .trade: return "resources.section.trade"
            }
        }
    }

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSection: ResourceSection = .poi

    /// 交易开关状态
    @State private var isTradingEnabled: Bool = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)

                // 分段选择器
                segmentedPicker
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.background)

                // 内容区域
                contentView
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("tab.resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 子视图

    /// 顶部工具栏
    private var topToolbar: some View {
        HStack {
            // 交易开关
            HStack(spacing: 8) {
                Image(systemName: isTradingEnabled ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                    .font(.title3)

                Text("resources.trading")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Toggle("", isOn: $isTradingEnabled)
                    .labelsHidden()
                    .tint(ApocalypseTheme.success)
            }

            Spacer()

            // 状态指示
            if isTradingEnabled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ApocalypseTheme.success)
                        .frame(width: 8, height: 8)

                    Text("resources.trading_on")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.success.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    /// 分段选择器
    private var segmentedPicker: some View {
        Picker("resources.segments", selection: $selectedSection) {
            ForEach(ResourceSection.allCases) { section in
                Text(section.displayName)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 内容区域
    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .poi:
            POIListView()

        case .backpack:
            BackpackView()

        case .purchased:
            placeholderView(
                icon: "bag.badge.checkmark",
                title: String(localized: "resources.purchased_items"),
                message: String(localized: "resources.under_development")
            )

        case .territory:
            placeholderView(
                icon: "map",
                title: String(localized: "resources.territory_resources"),
                message: String(localized: "resources.under_development")
            )

        case .trade:
            placeholderView(
                icon: "arrow.left.arrow.right",
                title: String(localized: "resources.trading_exchange"),
                message: String(localized: "resources.under_development")
            )
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 标题
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 消息
            Text(message)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
